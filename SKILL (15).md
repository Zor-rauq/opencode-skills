---
name: terraform-iac
description: Generate and review Terraform or OpenTofu infrastructure code using secure, modular, and maintainable IaC practices.
---

# Terraform / OpenTofu IaC

Write infrastructure code that is explicit, predictable, secure, and easy to evolve.

## Principles

- Prefer clarity over DRY when DRY harms readability.
- Keep modules small and purpose-driven.
- Make resource names and tags deterministic.
- Keep environments consistent through composition, not copy-paste drift.
- Design for plan readability.

## Structure

- Separate root modules from reusable modules.
- Keep variables, outputs, versions, providers, and main resources organized clearly.
- Use versions.tf to pin provider and Terraform/OpenTofu versions.
- Use variables with type constraints and validation when useful.
- Expose only necessary outputs.

## Security

- Never hardcode secrets.
- Use secret managers, CI variables, vaults, or runtime injection.
- Mark sensitive outputs when applicable.
- Apply least privilege to IAM roles, policies, and service identities.
- Avoid wildcard permissions unless strictly necessary and justified.

## State management

- Use remote state for shared and production environments.
- Enable locking where supported.
- Never commit state files.
- Keep backend configuration explicit.

## Coding rules

- Prefer explicit resource arguments over implicit defaults when operationally important.
- Use locals for meaningful derived values, not to obscure simple values.
- Avoid excessive dynamic blocks when static blocks are clearer.
- Use for_each over count when identity matters.
- Keep expressions readable; split complex expressions into locals.
- Use consistent tagging and naming conventions.

## Reliability

- Validate assumptions with data sources carefully.
- Avoid unstable dependencies between resources.
- Be cautious with lifecycle ignore_changes; use it only with clear justification.
- Explicitly manage deletion protection and retention where required.

## Review checklist

- Are versions pinned?
- Are modules cohesive?
- Are variable types and defaults safe?
- Is plan output readable?
- Is IAM minimal?
- Are secrets excluded?
- Is state remote and locked?
- Are naming and tagging consistent?

## Output behavior

Generate production-leaning Terraform/OpenTofu that is simple, typed, secure, and reviewable.
