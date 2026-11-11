---
name: commit-messages
description: Write Conventional Commits messages. Use when writing, amending, reviewing or suggesting a commit message, or when asked to commit.
---

# Commit Messages

Follow Conventional Commits 1.0. If a repo has its own commit config (cog.toml, commitlint), read it first and follow it.

## Format

```text
<type>[(scope)][!]: <description>

[body]

[footer(s)]
```

- **Description:** Imperative, lowercase unless a name needs casing, no period, about 72 characters or less. Say the outcome, not "update stuff".
- **Scope:** The area or tool touched, such as `kanata`, `zellij` or `deps`. Omit it for repo-wide changes. Reuse scopes already in the repo's history.
- **Body:** Only for reasoning the diff doesn't show, a breaking change or a migration. Wrap at 72 and explain why, not what.
- **Footers:** `Token: value` or `Token #value`. Use `Fixes #n` to close an issue and `Refs #n` for context only.

## Choosing the type

Choose by impact, not by file path.

- `feat`: new user-facing behavior.
- `fix`: corrected behavior, including dependency updates that change runtime behavior.
- `perf`: faster or lighter, same behavior.
- `refactor`: restructure with the same behavior.
- `docs`, `test`, `ci`: prose, tests, CI only.
- `build`: build system, packaging, dependency or lockfile changes with no behavior change.
- `style`: formatting only.
- `revert`: undo an earlier commit.
- `chore`: last resort, only when nothing above fits.

## Breaking changes

If supported usage stops working, or a public contract gets stricter (config, CLI, exports, minimum versions, defaults), add `!` and a footer:

```text
feat(cli)!: drop the legacy flag

BREAKING CHANGE: `--old` is removed, use `--new`.
```

## Details

- Wrap code identifiers (functions, flags, files) in backticks.
- Wrap `@`-prefixed tokens that are not user mentions in backticks, such as `@types/node`. A bare `@name` pings a GitHub user.
- Flake input or submodule bumps: `build(deps): bump <name> (<what changed>)`. Name the notable change, not the hash.
- One coherent change per commit. If the diff mixes unrelated changes, say so and suggest splitting.

## Workflow

1. Read the staged diff, or the working tree diff if nothing is staged.
2. Pick the type, scope and description.
3. If the repo has a verifier (cocogitto `cog verify`, commitlint), validate the message before presenting it.
4. When asked for a message, output only the message. If the impact is unclear, give two options and the consequence of each.

## Rules

- Commit only when asked.
- Never amend, force-push or skip hooks (`--no-verify`) unless asked.
- Add a `Co-Authored-By` trailer only when the harness's attribution reminder says to, with exactly the line it gives.
- Never put secrets or internal URLs in a message.
