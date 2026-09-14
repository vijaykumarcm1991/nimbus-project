import os
import time
import uuid
from contextlib import asynccontextmanager

import psycopg
import redis
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# Config comes from the environment — never hardcoded (Task 4 discipline)
DATABASE_URL = os.environ["DATABASE_URL"]
REDIS_URL = os.environ["REDIS_URL"]

# One shared Redis client for the whole app
cache = redis.Redis.from_url(REDIS_URL, decode_responses=True)

def get_db():
    # Open a fresh connection to Postgres
    return psycopg.connect(DATABASE_URL)

def init_db():
    # Create our table if it's not there yet.
    # We retry, because the database may take a few seconds to be ready
    # when the whole stack starts at once.
    for attempt in range(10):
        try:
            with get_db() as conn, conn.cursor() as cur:
                cur.execute("CREATE TABLE IF NOT EXISTS urls ("
                            "code TEXT PRIMARY KEY, url TEXT NOT NULL)")
                conn.commit()
            print("Database ready.")
            return
        except Exception as e:
            print(f"DB not ready (attempt {attempt+1}): {e}")
            time.sleep(2)
    raise RuntimeError("Could not reach the database")

@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()          # runs once, when the app starts
    yield

app = FastAPI(lifespan=lifespan)

class URLInput(BaseModel):
    url: str

@app.get("/health")
def health():
    # Healthy only if we can reach BOTH Postgres and Redis
    try:
        with get_db() as conn, conn.cursor() as cur:
            cur.execute("SELECT 1")
        cache.ping()
        return {"status": "ok"}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"unhealthy: {e}")

@app.post("/shorten")
def shorten(item: URLInput):
    code = uuid.uuid4().hex[:6]
    with get_db() as conn, conn.cursor() as cur:
        cur.execute("INSERT INTO urls (code, url) VALUES (%s, %s)",
                    (code, item.url))
        conn.commit()
    return {"short_code": code}

@app.get("/links/{code}")
def lookup(code: str):
    # 1. Look in the cache first (fast)
    cached = cache.get(code)
    if cached is not None:
        return {"url": cached, "source": "cache"}

    # 2. Cache miss -> ask the database (slower)
    with get_db() as conn, conn.cursor() as cur:
        cur.execute("SELECT url FROM urls WHERE code = %s", (code,))
        row = cur.fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Code not found")

    # 3. Save it in the cache so next time is fast
    url = row[0]
    cache.set(code, url)
    return {"url": url, "source": "database"}