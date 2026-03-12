# Security & Code Safety

## When to apply this rule
Apply on every code change. These rules are not optional.

---

## 1. Dependency safety

**Always verify before adding a package:**
- Confirm it exists on the official registry (PyPI, npm, crates.io, etc.) and the name is exact — typosquatting is common
- Check for recent maintenance activity and broad adoption
- Pin to an exact version (e.g. `httpx==0.27.0`, not `httpx>=0.27`; `"express": "4.18.2"`, not `"^4.18.2"`)
- Never install packages from GitHub URLs, local paths, or direct downloads unless explicitly discussed and approved
- Before adding a new dependency, ask: can this be done with the stdlib or an existing dependency?

---

## 2. Secrets and credentials

**Never hardcode secrets.** This includes:
- API keys, database credentials, JWT secrets
- Tokens, passwords, or bearer credentials of any kind
- Internal hostnames, IP addresses, or service URLs used for testing

**Always use environment variables.** Load from `.env` via your framework's config system (pydantic-settings, dotenv, etc.):

```python
# correct
import os
api_key = os.getenv("API_KEY")
if not api_key:
    raise EnvironmentError("API_KEY is not set")

# wrong — never do this
api_key = "sk-abc123..."
```

**`.env` must be in `.gitignore`.** Verify before every commit.
Never log, print, or include secrets in exception messages, response bodies, or tracebacks.

---

## 3. External URL fetching (SSRF prevention)

Any code that fetches a user-supplied or externally derived URL must treat it as untrusted input.

**Always enforce timeouts:**
```python
# correct
async with httpx.AsyncClient(timeout=10.0) as client:
    response = await client.get(url)

# wrong — no timeout means a slow server hangs indefinitely
async with httpx.AsyncClient() as client:
    response = await client.get(url)
```

**Validate URLs before fetching — including after redirects.**
String-matching the hostname is not enough. Resolve the hostname and verify the IP is not internal:

```python
import ipaddress, socket
from urllib.parse import urlparse

def _is_safe_ip(ip_str: str) -> bool:
    try:
        addr = ipaddress.ip_address(ip_str)
    except ValueError:
        return False
    return not (
        addr.is_private or addr.is_loopback or addr.is_link_local
        or addr.is_reserved or addr.is_multicast
    )

def is_safe_url(url: str) -> bool:
    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https"):
        return False
    hostname = parsed.hostname or ""
    if not hostname:
        return False
    try:
        results = socket.getaddrinfo(hostname, None)
    except socket.gaierror:
        return False
    return all(_is_safe_ip(r[4][0]) for r in results)
```

**Disable automatic redirect following** so each redirect target is validated individually.

**Cap response sizes using streaming** — never download the full body then truncate:
```python
MAX_BYTES = 5 * 1024 * 1024  # 5 MB
async with client.stream("GET", url) as response:
    chunks, received = [], 0
    async for chunk in response.aiter_bytes(chunk_size=65536):
        chunks.append(chunk)
        received += len(chunk)
        if received >= MAX_BYTES:
            break
    content = b"".join(chunks)
```

---

## 4. Input validation and injection prevention

**All external input must be validated** through your framework's schema/validation layer (Pydantic, Zod, etc.) before reaching business logic.

**Always use parameterised queries** — never interpolate user input into SQL:
```python
# correct
user = db.query(User).filter(User.email == email).first()

# wrong — SQL injection
db.execute(f"SELECT * FROM users WHERE email = '{email}'")
```

**Never use `eval()` or `exec()` on any external content.**

**Never pass external input to shell commands via `shell=True`:**
```python
# wrong
subprocess.run(f"process {user_input}", shell=True)

# correct
subprocess.run(["process", user_input], shell=False)
```

**Sanitise all user-generated content** before rendering it in HTML/DOM to prevent XSS.

---

## 5. Authentication and authorisation

- Validate JWT/session tokens server-side on every protected request — never trust client-supplied claims
- Use timezone-aware UTC datetimes for all token expiry checks
- Authorisation checks belong in the service layer, not just the route handler
- Never expose internal IDs in URLs without verifying the requester owns that resource
- Rate-limit authentication endpoints to prevent brute-force attacks

---

## 6. Frontend security

- Never store JWTs or sensitive tokens in `localStorage` — use `httpOnly` cookies
- Sanitise any user-generated content before rendering in the DOM
- Never use `dangerouslySetInnerHTML` (React) or `v-html` (Vue) without explicit justification and sanitisation
- All API calls from the frontend must go through a typed service layer — no raw `fetch` with unvalidated URLs
- Set appropriate CORS headers — never use `Access-Control-Allow-Origin: *` in production

---

## 7. Output and file writing

**Always write to a designated output directory only.**

Use path resolution and containment checks to prevent traversal:
```python
from pathlib import Path
import re

OUTPUT_DIR = Path("data/output").resolve()

def safe_output_path(filename: str) -> Path:
    safe_name = re.sub(r"[^a-zA-Z0-9\-_.]", "_", filename)
    candidate = (OUTPUT_DIR / safe_name).resolve()
    if not candidate.is_relative_to(OUTPUT_DIR):
        raise ValueError(f"Path traversal attempt blocked: {candidate}")
    return candidate
```

**Validate JSON before writing:**
```python
import json
json_str = json.dumps(data, indent=2)  # raises if not serialisable
path.write_text(json_str, encoding="utf-8")
```

---

## 8. Error handling

**Never expose internal stack traces in API responses or user-facing output.**
Log them server-side and return a structured error:

```python
import logging, traceback

logger = logging.getLogger(__name__)

def safe_call(fn, *args, **kwargs):
    try:
        return fn(*args, **kwargs)
    except Exception:
        logger.error("Unexpected error: %s", traceback.format_exc())
        raise HTTPException(status_code=500, detail="An internal error occurred.")
```

Stack traces can leak file paths, library versions, and internal logic that must not appear in client-facing output.

---

## 9. Pre-commit checklist

Before marking any code task as complete, verify:

- [ ] No secrets, API keys, or tokens appear anywhere in the code
- [ ] `.env` is in `.gitignore` and not tracked
- [ ] All user-supplied URLs are validated with DNS-resolved checks (not string-matched)
- [ ] Redirects are followed manually and each target is re-validated
- [ ] All external fetches have explicit timeouts
- [ ] Response sizes are capped using streaming
- [ ] No raw SQL — all queries use ORM or parameterised statements
- [ ] No `eval()` or `exec()` on external content
- [ ] No `shell=True` with any externally derived content
- [ ] All file writes use path resolution with containment assertion
- [ ] Auth checks are enforced in the service layer
- [ ] No stack traces in API responses or user-facing output
- [ ] No new dependencies added without verification and exact version pinning
- [ ] User-generated content is sanitised before rendering
