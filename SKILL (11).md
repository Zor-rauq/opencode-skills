---
name: refactor-safe
description: Guide low-risk refactoring that improves readability and structure without changing behavior unnecessarily.
---

# Safe Refactoring

Refactor conservatively. Improve structure while preserving behavior.

## Objectives

- Reduce complexity.
- Improve readability.
- Improve testability.
- Keep behavior unchanged unless explicitly requested.
- Minimize regression risk.

## Refactoring rules

- Prefer small, reviewable steps.
- Keep changes localized.
- Do not mix refactoring and feature changes unless required.
- Preserve public interfaces unless the task explicitly allows breaking changes.
- Add or update tests around risky areas before significant changes.
- Stop once the code is clear enough; do not chase theoretical perfection.

## Safe patterns

- Extract long functions into smaller named helpers.
- Replace duplicated blocks with one focused helper when the duplication is real and stable.
- Rename unclear identifiers to reveal intent.
- Flatten nested conditionals with guard clauses.
- Separate pure logic from side effects.
- Isolate infrastructure concerns from business logic.

## Avoid

- Rewrite-from-scratch refactors.
- Moving many files without strong reason.
- Changing APIs and internals together without migration path.
- Introducing new frameworks, patterns, or dependencies during refactor.
- Bundling formatting-only churn with structural changes if it hurts reviewability.

## Output behavior

For any refactor proposal:

1. Identify current pain points.
2. Suggest the smallest safe improvement path.
3. Preserve behavior.
4. Call out risky areas explicitly.
5. Keep the diff easy to review.
