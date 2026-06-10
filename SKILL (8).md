---
name: git-commit-style
description: Write clean, conventional commit messages with clear intent, limited scope, and useful rationale when needed.
---

# Git Commit Style

Write commit messages that help reviewers and future maintainers understand intent quickly.

## Default format

Prefer conventional commits when the repository uses them:

- feat(scope): add X
- fix(scope): handle Y correctly
- refactor(scope): simplify Z
- docs(scope): document W
- chore(scope): update V
- ci(scope): adjust pipeline
- test(scope): cover edge case

## Rules

- Use imperative mood.
- Keep subject concise.
- Do not end the subject with a period.
- Keep the subject focused on what changed.
- Add a body only when the why is not obvious.
- Keep unrelated changes out of the same commit.

## Good body content

- Why the change was necessary
- Risk or compatibility notes
- Migration hints if applicable

## Avoid

- Vague messages like update stuff or fixes
- Multi-purpose commits with no clear theme
- Overly long subject lines
- Bodies that restate the diff without explaining intent

## Output behavior

Generate small, focused, conventional commit messages aligned with the actual change.
