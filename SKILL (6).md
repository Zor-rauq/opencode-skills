---
name: docs-as-code
description: Write concise, structured technical documentation in Markdown with operational clarity and minimal redundancy.
---

# Docs as Code

Write documentation that helps engineers act correctly and quickly.

## Principles

- Be concise.
- Prefer concrete examples over vague guidance.
- Document intent, usage, constraints, and operational caveats.
- Keep docs close to the code or system they describe.
- Avoid repeating what is obvious from code unless it matters operationally.

## Structure

Prefer this order when relevant:

1. Purpose
2. Prerequisites
3. Inputs and outputs
4. Usage examples
5. Failure modes / troubleshooting
6. Security notes
7. Operational notes

## Style

- Use short paragraphs and meaningful headings.
- Prefer bullets and tables for quick scanning.
- Keep examples sanitized.
- Avoid marketing language.
- Avoid filler text.
- Keep terminology consistent with the codebase.

## Good documentation includes

- What the component does
- How to run or use it
- Required variables and configuration
- Safe defaults and constraints
- Common failure cases
- Ownership or review expectations when relevant

## Output behavior

Generate Markdown documentation that is concise, practical, and operationally useful.
