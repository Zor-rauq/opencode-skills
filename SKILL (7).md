---
name: git-branching
description: Apply clear branching and merge practices that support safe collaboration, traceability, and low-friction delivery.
---

# Git Branching

Use branch workflows that reduce confusion and support reliable delivery.

## Principles

- Keep branch names predictable.
- Keep branch lifetime short.
- Prefer small pull or merge requests.
- Reduce divergence from the main integration branch.
- Match the branching model to release and team needs.

## Naming suggestions

- feature/<short-description>
- fix/<short-description>
- hotfix/<short-description>
- chore/<short-description>
- release/<version>

## Workflow guidance

- Prefer trunk-based development when release cadence is high and automation is mature.
- Use release branches only when there is a real release management need.
- Rebase or merge according to repository policy, but keep history understandable.
- Avoid long-lived feature branches that drift heavily.
- Protect main production branches.

## Review checklist

- Is the branch name meaningful?
- Is the branch too large or too old?
- Is there avoidable drift from main?
- Is merge strategy consistent with team policy?

## Output behavior

Recommend simple branch naming and short-lived collaboration patterns that minimize drift and merge pain.
