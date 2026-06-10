---
name: python-devops
description: Write Python automation for infrastructure and operations using clear structure, type hints, explicit errors, and low operational risk.
---

# Python for DevOps

Write Python that is reliable in automation contexts and understandable during incidents.

## Principles

- Favor readability over cleverness.
- Use the standard library when sufficient.
- Keep scripts small and composable.
- Separate parsing, orchestration, API access, and output formatting.
- Make failure explicit.

## Coding rules

- Use type hints for public functions and important internal helpers.
- Prefer dataclasses or small typed structures when they improve clarity.
- Avoid global mutable state.
- Use pathlib instead of string paths when practical.
- Use logging instead of print for operational scripts, except simple CLI output.
- Keep functions focused and testable.
- Avoid giant main functions.

## Error handling

- Raise explicit exceptions with context.
- Catch exceptions at clear boundaries.
- Return non-zero exit codes for CLI failures.
- Distinguish user errors, configuration errors, and remote-system failures.

## CLI style

- Use argparse unless another CLI framework is clearly justified.
- Provide --help and clear argument names.
- Validate required inputs early.
- Keep output concise and parseable when useful.

## Operational safety

- Set timeouts for network calls.
- Use retries only for retryable failures.
- Avoid broad except Exception unless followed by re-raise or controlled translation.
- Never embed credentials.

## Output behavior

Generate Python automation that is typed, structured, explicit, and easy to maintain.
