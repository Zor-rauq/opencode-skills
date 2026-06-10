---
name: container-build
description: Create secure, minimal, reproducible Dockerfile and Podman container builds for production use.
---

# Container Build

Build containers that are small, secure, explicit, and easy to maintain.

## Principles

- Use the smallest practical base image.
- Prefer multi-stage builds.
- Run as non-root unless impossible.
- Pin important versions.
- Keep build context small.
- Make runtime images contain only what is needed to run.

## Security rules

- Never bake secrets into layers.
- Never copy private keys, token files, or local credentials into the image.
- Use .dockerignore carefully.
- Drop unnecessary Linux capabilities at runtime when possible.
- Avoid curl | sh patterns unless integrity and trust are explicit.

## Dockerfile style

- Order layers for readability first, caching second.
- Group related commands.
- Clean package manager caches in the same layer when relevant.
- Use explicit WORKDIR.
- Use exec-form ENTRYPOINT/CMD.
- Prefer COPY over ADD unless ADD behavior is explicitly needed.
- Name build stages clearly.

## Runtime defaults

- Define a non-root USER.
- Expose only required ports.
- Use healthchecks when operationally useful.
- Set sensible environment variables explicitly.
- Do not install debugging tools in production images unless there is a clear operational need.

## Review checklist

- Is the image minimal?
- Are versions pinned where it matters?
- Is the runtime non-root?
- Are secrets excluded?
- Is the entrypoint explicit?
- Is the build reproducible?

## Output behavior

Generate container definitions that are minimal, multi-stage, non-root, and production-safe.
