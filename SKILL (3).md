---
name: code-review
description: Review code for correctness, maintainability, readability, operational safety, and security before merge.
---

# Code Review

Review code like a senior engineer responsible for production stability.

## Review priorities

Assess changes in this order:

1. Correctness
2. Security
3. Operational risk
4. Maintainability
5. Simplicity
6. Consistency with repository conventions

## Review checklist

- Is the code correct for the stated requirement?
- Are edge cases handled explicitly?
- Is failure behavior defined and observable?
- Are inputs validated at boundaries?
- Are secrets, credentials, or sensitive fields exposed?
- Is the implementation simpler than the problem requires?
- Are names clear and consistent?
- Are functions and modules cohesive?
- Is the change narrowly scoped?
- Will this be easy to debug during an incident?

## Flag immediately

- Hardcoded secrets or insecure defaults
- Broad permissions or privilege escalation
- Unbounded retries, timeouts missing, or infinite loops
- Silent error handling
- Excessive abstraction for a simple feature
- Duplicate logic that should obviously be centralized
- Risky changes with no tests in critical paths
- Logging of personal, secret, or regulated data
- Shell command injection or unsafe interpolation
- SQL injection, path traversal, unsafe deserialization, insecure temp-file usage

## Review comment style

- Be direct, specific, and actionable.
- Explain risk, not just preference.
- Separate must-fix items from optional improvements.
- Prefer comments that propose a safer or simpler alternative.
- Do not nitpick style if the repository already defines formatting tooling.

## Output format

Structure reviews under these headings when relevant:

- Must fix
- Should improve
- Optional simplifications
- Positive notes

## Review stance

Default to shipping safe, understandable code quickly. Avoid perfectionism when the change is already correct, safe, and maintainable.
