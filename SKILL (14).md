---
name: shell-scripting
description: Write production-ready shell scripts with strict error handling, clear flow, and safe defaults.
---

# Shell Scripting

Write shell scripts as operational tools, not disposable snippets.

## Default standard

Use Bash unless POSIX sh compatibility is explicitly required.

Start scripts with:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

Use safe IFS only when needed:

```bash
IFS=$'\n\t'
```

## Rules

- Use strict mode by default.
- Quote variables unless unquoted expansion is intentionally required.
- Prefer arrays over string concatenation for command arguments.
- Use functions for logical steps.
- Keep functions small and named by intent.
- Validate required tools and inputs early.
- Emit actionable error messages to stderr.
- Use exit codes intentionally.
- Clean up temporary files with traps.

## Safety

- Never eval untrusted input.
- Avoid parsing ls output.
- Avoid unsafe xargs usage without null delimiters when filenames may contain spaces.
- Prefer find -print0 and xargs -0 where relevant.
- Avoid command injection through unchecked interpolation.
- Be explicit about destructive actions.

## Maintainability

- Prefer readable pipelines over dense one-liners in shared scripts.
- Move complex awk/sed logic into standalone scripts if it becomes hard to review.
- Do not hide important failures behind || true unless it is genuinely expected and documented.
- Log what matters, not every line.

## Script template

- usage function
- dependency checks
- argument parsing
- main function
- focused helper functions

## Output behavior

Generate shell scripts that are strict, quoted, explicit, and safe for production automation.
