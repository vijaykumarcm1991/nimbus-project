from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uuid

app = FastAPI()

# Our pretend "database": a dictionary that lives only in memory.
# We'll swap this for a real database later, when we containerize.
url_store = {}

# Describes what someone must send us when shortening: one field, "url".
class URLInput(BaseModel):
    url: str

@app.get("/health")
def health():
    # Proves the app is alive. We'll wire this into monitoring later.
    return {"status": "ok"}

@app.post("/shorten")
def shorten(item: URLInput):
    code = uuid.uuid4().hex[:6]   # make a short random code like "a1b2c3"
    url_store[code] = item.url    # store it: code is the key, URL is the value
    return {"short_code": code}

@app.get("/links/{code}")
def lookup(code: str):
    if code not in url_store:                       # code we've never seen?
        raise HTTPException(status_code=404, detail="Code not found")
    return {"url": url_store[code]}