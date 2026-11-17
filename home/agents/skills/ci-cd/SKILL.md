---
name: ci-cd
description: Write, change or review CI/CD pipelines (GitHub Actions workflows) and their security settings. Use when adding or editing a workflow, setting up branch protection, or auditing a pipeline.
---

# CI/CD

For GitHub Actions. If a repo already has its own pipeline conventions, read them first and follow them. Hooks and CI call Taskfile tasks, never the raw tools, and run them inside the dev env.

## Triggers and jobs

- Run on pushes to main and on pull requests to main.
- Put the checks that give the same result on every platform in one Linux job (`task check`, `task test`).
- Run platform-specific checks on that platform only, for example clippy and tests for OS-specific code on macOS.
- Run a separate scan job (`task scan`). Scanners that read history need `fetch-depth: 0`.
- Do not split one job per tool: each job reinstalls the dev env, and `task check` stays the single source of truth.

## Security

- Pin every third-party action to a full commit SHA, with the version in a trailing comment.
- Set `permissions: contents: read` at the top of the workflow. Widen it per job, only where needed.
- Set `persist-credentials: false` on checkout unless the job pushes.
- Set `timeout-minutes` on every job, and `concurrency` with cancel-in-progress except on main, where a run may be pushing to a cache.
- Never use `pull_request_target` with code from the PR.
- Run jobs that use secrets (for example a binary cache push) on main only, so the token never meets code from a PR.
- Commit lockfiles, including `flake.lock`, so CI builds pinned inputs.

## Repo settings

- Protect main: required status checks, no force-push, no deletion. A solo repo may keep admin direct push (`enforce_admins: false`) while it moves fast, and may skip required reviews.
- Restrict the allowed actions to GitHub-owned ones plus the third-party ones in use, and require SHA pinning.
- Confirm before changing settings. They apply at once and are outward-facing.

```sh
# Resolve the SHA of an action tag (a tag may be annotated: then follow it with git/tags/<sha>).
gh api repos/<owner>/<repo>/git/ref/tags/<tag> --jq '.object.type, .object.sha'

# Protect main.
gh api -X PUT repos/<owner>/<repo>/branches/main/protection --input protection.json

# Allow selected actions and require SHA pinning.
gh api -X PUT repos/<owner>/<repo>/actions/permissions -F enabled=true -f allowed_actions=selected -F sha_pinning_required=true
gh api -X PUT repos/<owner>/<repo>/actions/permissions/selected-actions -F github_owned_allowed=true -f 'patterns_allowed[]=<owner>/*'
```

`protection.json` holds `required_status_checks` (`strict`, and `contexts` as the job `name:` values), `enforce_admins`, `required_pull_request_reviews: null`, `restrictions: null`, `allow_force_pushes: false` and `allow_deletions: false`.

## Audit checklist

- actionlint and zizmor (`--offline`) pass.
- No action is pinned to a tag or branch.
- The workflow has `permissions`, and every job has `timeout-minutes`.
- No secret is reachable from a job that runs PR code.
- Main is protected and the lockfiles are committed.
- Report findings as numbered points. Don't fix settings without asking.
