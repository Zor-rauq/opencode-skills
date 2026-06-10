---
name: api-integration
description: Implement reliable REST and GraphQL integrations with timeouts, retries, validation, and safe credential handling.
---

# API Integration

Integrate with external APIs in a way that is resilient, observable, and secure.

## Principles

- Every request should have a timeout.
- Retries must be explicit, bounded, and only for retryable cases.
- Authentication must be externalized.
- Validate responses before trusting them.
- Handle partial and error responses clearly.

## Rules

- Set connect and read timeouts.
- Distinguish 4xx from 5xx behavior.
- Retry transient failures only.
- Respect rate limits and backoff guidance.
- Parse and validate response shape before downstream use.
- Surface actionable errors with endpoint context.
- Avoid leaking tokens in logs and exception messages.

## GraphQL guidance

- Check both HTTP status and GraphQL errors.
- Keep queries explicit and minimal.
- Avoid massive generic queries.
- Validate nullable fields carefully.

## REST guidance

- Use idempotency-aware retry behavior.
- Send only required headers.
- Keep request builders small and explicit.
- Centralize auth, timeout, retry, and response validation logic.

## Output behavior

Generate API clients and scripts that are timeout-bound, retry-safe, minimally privileged, and easy to debug.
