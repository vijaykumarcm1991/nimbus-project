import os

import httpx

# Where the running app lives. Defaults to localhost; CI can override it.
BASE_URL = os.environ.get("BASE_URL", "http://localhost:8000")

def test_health_is_ok():
    r = httpx.get(f"{BASE_URL}/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"

def test_shorten_then_lookup_returns_original_url():
    # Shorten a URL...
    r = httpx.post(f"{BASE_URL}/shorten", json={"url": "https://example.com"})
    assert r.status_code == 200
    code = r.json()["short_code"]
    # ...then look it up and confirm we get the same URL back
    r2 = httpx.get(f"{BASE_URL}/links/{code}")
    assert r2.status_code == 200
    assert r2.json()["url"] == "https://example.com"

def test_unknown_code_returns_404():
    r = httpx.get(f"{BASE_URL}/links/thiscodedoesnotexist")
    assert r.status_code == 404