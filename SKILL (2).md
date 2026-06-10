---
name: ci-cd-gitlab
description: Design GitLab CI/CD pipelines that are secure, readable, reusable, and operationally reliable.
---

# GitLab CI/CD

Write GitLab pipelines for maintainability, fast feedback, and safe delivery.

## Principles

- Keep pipeline logic understandable from the YAML alone.
- Optimize first for reliability, then for speed.
- Fail fast on validation, linting, and security checks.
- Make jobs composable and reusable.
- Keep secret handling out of job logs and repository files.

## Pipeline design

- Use clear stage names and job names.
- Prefer reusable anchors, extends, and templates only when they improve readability.
- Keep inheritance shallow.
- Use rules instead of only/except in modern configurations.
- Avoid deeply nested pipeline indirection that makes behavior hard to trace.
- Scope artifacts carefully.
- Set explicit timeouts where useful.
- Use needs to reduce unnecessary waiting when safe.

## Security

- Use protected variables and masked variables where appropriate.
- Never echo secrets.
- Avoid passing secrets as plain command-line arguments when they may leak to process listings or logs.
- Limit job permissions, tokens, and environments.
- Separate trusted and untrusted pipeline paths, especially for merge requests from forks.

## Reliability

- Make retry policy explicit and narrow.
- Do not retry jobs blindly if failure is likely deterministic.
- Use cache carefully; prefer correctness over accidental stale state.
- Pin images and tools when reproducibility matters.
- Ensure deploy jobs are idempotent where possible.

## Maintainability

- Keep scripts concise; move complex logic to versioned scripts in the repository.
- Prefer shell scripts or Make targets over large inline YAML scripts when logic grows.
- Name variables clearly.
- Add comments only for non-obvious policy or workflow constraints.

## Suggested stages

- validate
- test
- build
- scan
- package
- deploy
- verify

Use only what the project needs.

## Review checklist

- Are jobs named clearly?
- Are rules understandable?
- Are secrets handled safely?
- Are artifacts minimal and scoped?
- Is deployment protected?
- Is the pipeline easy to debug?
- Is complex logic moved out of YAML when needed?

## Output behavior

Generate concise GitLab CI configurations with clear stages, safe secret handling, small scripts, and explicit execution rules.
