---
name: senior-code-style
description: Enforce senior engineer coding standards focused on simplicity, clarity, maintainability, and low-risk implementation.
---

# Senior Code Style

Write code as a pragmatic senior engineer would: clear, boring in the best way, easy to review, easy to test, easy to change, and safe to run.

## Core principles

- Prefer simple solutions over clever ones.
- Optimize for readability and maintenance before micro-optimizations.
- Keep the number of moving parts low.
- Make the happy path obvious.
- Make failure modes explicit.
- Avoid hidden behavior, magic defaults, and surprising side effects.
- Write code that another engineer can understand quickly during an incident.

## Style rules

- Use descriptive names for variables, functions, classes, files, and modules.
- Prefer full words over abbreviations unless the abbreviation is industry-standard.
- Use short functions with one clear responsibility.
- Keep nesting shallow; refactor early if indentation grows.
- Prefer guard clauses over deeply nested conditionals.
- Prefer explicit data flow over implicit shared state.
- Limit comments to intent, non-obvious tradeoffs, or critical caveats.
- Do not add comments that simply restate the code.
- Avoid decorative abstractions and unnecessary indirection.
- Do not introduce patterns, frameworks, or generic helpers unless there is a real repeated need.

## Function design

- A function should do one thing.
- A function name should describe what it does, not how it does it.
- Keep parameter lists short.
- Prefer passing structured objects over long positional argument lists.
- Return clear values; avoid overloaded return meanings.
- Raise or propagate explicit errors rather than returning ambiguous sentinel values.
- Separate pure transformation logic from I/O when possible.

## Variable rules

- Use names that reveal business or operational meaning.
- Avoid one-letter variables except for conventional loop indexes in very small scopes.
- Avoid names like data, obj, thing, value, tmp, misc unless scope is trivial.
- Make booleans read like predicates: is_ready, has_access, should_retry.
- Encode units when relevant: timeout_seconds, size_bytes, duration_ms.
- Avoid reusing the same variable name for different meanings.

## Control flow

- Keep control flow linear and unsurprising.
- Prefer early returns for invalid states.
- Use explicit branches instead of dense chained expressions when readability improves.
- Replace duplicated condition blocks with small named helpers only when it reduces complexity.
- Avoid exceptions for normal control flow.

## Error handling

- Validate inputs at boundaries.
- Fail fast on invalid configuration or missing required state.
- Produce precise error messages with actionable context.
- Do not swallow exceptions silently.
- Avoid broad catch-all handlers unless they log context and re-raise or convert intentionally.
- Distinguish retryable and non-retryable failures.

## Maintainability rules

- Prefer standard library and built-in platform capabilities before adding dependencies.
- Add dependencies only when they clearly reduce complexity or risk.
- Minimize global mutable state.
- Keep modules cohesive.
- Do not mix orchestration, parsing, persistence, and presentation in one file without good reason.
- Preserve backward compatibility unless the change explicitly allows breakage.
- Refactor incrementally, not through large rewrites.

## Security baseline

- Never hardcode secrets, tokens, passwords, or private keys.
- Never log sensitive values.
- Sanitize external input at trust boundaries.
- Use least privilege for filesystem, network, IAM, and runtime permissions.
- Prefer explicit allowlists over implicit trust.

## Testing mindset

- Make code easy to test by design.
- Prefer deterministic functions and clear boundaries.
- Cover critical paths, edge cases, and failure handling.
- Avoid test setups that require excessive mocking because that usually indicates poor design.

## What to avoid

- Clever one-liners that reduce clarity.
- Massive utility files with unrelated helpers.
- Premature generalization.
- Over-commenting.
- Deep inheritance for simple behavior.
- Hidden mutation.
- Silent retries without visibility.
- Configuration scattered across multiple unrelated files.

## Output behavior

When generating or editing code:

1. Produce the simplest implementation that satisfies the requirement.
2. Keep the diff as small as possible.
3. Preserve existing conventions when they are reasonable.
4. Prefer explicit names and straightforward flow.
5. Add only essential comments.
6. If the design appears risky or over-complex, propose a simpler alternative first.
