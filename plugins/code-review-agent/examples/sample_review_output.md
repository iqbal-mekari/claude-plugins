# Sample Review Output

This is an example of the markdown file the plugin writes per PR.

**File path:** `~/.pr-review-agent/reviews/acme-corp_payment-service_PR42_20260613.md`

---

# Code Review: PR #42 — "Add rate limiting to login API"

| Field | Value |
|-------|-------|
| **Author** | @jane.developer |
| **Branch** | feature/rate-limit → main |
| **Date** | 2026-06-13 09:30 |
| **Files reviewed** | 6 |
| **Quality Score** | 78/100 |
| **Est. Review Time** | 25min |

## Issues (1 critical / 2 high / 3 medium)

### Critical

- **`src/auth/login_service.py:67`** — SQL injection vulnerability in login query
  > Fix: Use parameterized query `cursor.execute("SELECT * FROM users WHERE email = ?", (email,))` instead of f-string formatting

### High

- **`src/auth/rate_limiter.py:23`** — Race condition in rate limit counter
  > Fix: Use `threading.Lock()` around the counter increment, or use `redis.incr()` for atomic operation

- **`src/config/settings.py:15`** — Hardcoded rate limit values
  > Fix: Extract to environment variables with `envied` or config file

### Medium

- **`src/auth/rate_limiter.py:45`** — No cleanup of expired rate limit entries
  > Fix: Add TTL-based cleanup or use Redis with automatic expiry

- **`src/auth/login_service.py:89`** — Error message leaks user existence
  > Fix: Use generic "Invalid credentials" message for both wrong email and wrong password

- **`tests/test_rate_limiter.py:12`** — Test uses `time.sleep()` instead of mocking
  > Fix: Mock `time.time()` for deterministic tests

## Review Perspectives

| Persona | Score | Issues |
|---------|-------|--------|
| Security Sentinel | 65/100 | 2 |
| Performance Pursuer | 88/100 | 1 |
| Quality Custodian | 82/100 | 3 |

## Risk Factors

- SQL injection risk in auth layer
- Race condition could bypass rate limiting
- Hardcoded config values reduce flexibility

## Positive Observations

- Clean separation of concerns between rate limiter and auth service
- Good test coverage for happy path scenarios
- Consistent error handling patterns

## Raw Findings (JSON)

<details>
<summary>Click to expand structured JSON</summary>

```json
{
  "summary": {
    "files_reviewed": 6,
    "total_issues": 6,
    "by_severity": { "critical": 1, "high": 2, "medium": 3, "low": 0 },
    "quality_score": 78,
    "estimated_review_time": "25min",
    "risk_factors": [
      "SQL injection risk in auth layer",
      "Race condition could bypass rate limiting",
      "Hardcoded config values reduce flexibility"
    ],
    "good_points": [
      "Clean separation of concerns between rate limiter and auth service",
      "Good test coverage for happy path scenarios",
      "Consistent error handling patterns"
    ]
  },
  "line_comments": [
    {
      "file_path": "src/auth/login_service.py",
      "line_number": 67,
      "severity": "critical",
      "message": "SQL injection vulnerability — user input not sanitized",
      "suggestion": "Use parameterized query cursor.execute('SELECT * FROM users WHERE email = ?', (email,))",
      "category": "security",
      "source": "security-sentinel"
    },
    {
      "file_path": "src/auth/rate_limiter.py",
      "line_number": 23,
      "severity": "high",
      "message": "Race condition in rate limit counter",
      "suggestion": "Use threading.Lock() around the counter increment, or use redis.incr() for atomic operation",
      "category": "performance",
      "source": "performance-pursuer"
    },
    {
      "file_path": "src/config/settings.py",
      "line_number": 15,
      "severity": "high",
      "message": "Hardcoded rate limit values",
      "suggestion": "Extract to environment variables or config file",
      "category": "quality",
      "source": "quality-custodian"
    },
    {
      "file_path": "src/auth/rate_limiter.py",
      "line_number": 45,
      "severity": "medium",
      "message": "No cleanup of expired rate limit entries",
      "suggestion": "Add TTL-based cleanup or use Redis with automatic expiry",
      "category": "performance",
      "source": "performance-pursuer"
    },
    {
      "file_path": "src/auth/login_service.py",
      "line_number": 89,
      "severity": "medium",
      "message": "Error message leaks user existence",
      "suggestion": "Use generic 'Invalid credentials' message for both wrong email and wrong password",
      "category": "security",
      "source": "security-sentinel"
    },
    {
      "file_path": "tests/test_rate_limiter.py",
      "line_number": 12,
      "severity": "medium",
      "message": "Test uses time.sleep() instead of mocking",
      "suggestion": "Mock time.time() for deterministic tests",
      "category": "quality",
      "source": "quality-custodian"
    }
  ],
  "persona_scores": {
    "security": { "score": 65, "issues": 2 },
    "performance": { "score": 88, "issues": 1 },
    "quality": { "score": 82, "issues": 3 }
  }
}
```

</details>
