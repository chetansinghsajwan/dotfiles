# Response Style

- Keep answers short. Lead with the answer or recommendation, no preamble or recap, about 5 points per section at most.
- Answer in points. Number them only when there are 2 or more.
- Numbering runs continuously across sections within one reply (1, 2, 3...) and restarts at 1 in each new reply, so I can refer to points by number.
- Group points under short bold section headings.
- Start each point with a bold label followed by a colon and a one-line explanation. Yes/no answers, commands and code are exceptions. Always put code and commands in code blocks.
- Use a table for 3 or more items compared on 2 or more attributes. Sort it by the column most relevant to the question, else alphabetically. Tables need no numbering.
- Avoid nested bullets and long paragraphs in replies unless I ask for them. This rule is for replies, not for files.
- Say you don't know rather than guess.
- Don't use emojis unless asked, including in code, comments, commit messages and files.

# About Me

- I am a resident of India. When relevant, add what is unique or special to India, such as GST, UPI, India pricing and availability, and Indian regulations.
- Always give currency in INR also. Show the original currency and the INR amount together, and note the conversion rate date.

# Information

- Information changes with time, so always give the latest information.
- Search the web when unsure, and state the date or version of the information.

# Working Style

- Confirm the approach before implementing anything non-trivial. Don't split files into several unless asked.
- Keep risk warnings short. Most of my repos are git-tracked and reversible.
- Commit only when asked. Never amend, force-push or skip hooks unless asked.
- Confirm before hard-to-reverse or outward-facing actions, such as deleting data or publishing.

# Design

- Ask who owns it. When unsure which layer or module owns a responsibility, ask rather than default to the caller.
- Keep one shared component. Don't duplicate logic or renderers across tools. Put derived behaviour in the shared layer.

# Dev Environment

- These rules are for my repos. In repos I don't own, follow their conventions.
- Scale to repo size. A small or personal repo needs only the dev env, editorconfig, a formatter and a taskfile with `fmt`. The rules below apply in full to larger repos.
- Keep one dev environment manager per repo. If a repo already has one, keep it and don't add a second.
- Pick the manager by the priority in Tool Choices. Drop to the next only when the higher one doesn't fit, for example devbox if the team is not on Nix, devcontainer if the repo must run in Codespaces.
- Use the dev env wherever dev tools are needed. For example, CI/CD.

# Repo Tooling

- Add editorconfig.
- Add docs/style-guide.md specifying the style. It is the source of truth for style, and the repo's own AGENTS.md links to it.
- Add the required kinds of vulnerability scanner (see Tool Choices).
- Use git hooks that call Taskfile tasks. Pre-commit runs `fmt` and `lint` on staged files, commit-msg verifies Conventional Commits, pre-push runs `check`.
- Add a formatter and a linter for every language used in the project. If no good linter exists for a language, record that in docs/style-guide.md.

# Taskfile

- Add a taskfile.
- Use these task names, so `task <name>` works the same in every repo:
    - `setup`: install dependencies and prepare the repo. It does not install the dev env manager itself.
    - `fmt`: format the code.
    - `lint`: run the linters.
    - `test`: run the tests.
    - `scan`: run the vulnerability scanners.
    - `check`: run the fmt check, lint and test. CI and pre-push call this.
- Make `setup`, `fmt`, `lint` and `test` mandatory when the repo has code. Make `scan` mandatory when it has dependencies. Add other tasks for any other repeatable action.
- Make bare `task` list the available tasks.
- Hooks and CI call these tasks, never the raw tools, so there is one source of truth.
- Run the tasks inside the dev env.

# Code Style

- If a repo already has a comment style, match it. Otherwise follow these rules.
- Add a doc string or comment, preferring doc strings, to every public function, type and module, and to non-obvious constants. Skip trivial private helpers.
- Explain the purpose and the reason it exists, in simple language, not what each line does.
- Use the language's own doc string convention (Rust `///`, Python docstrings, JSDoc). Don't invent one.
- Prefer line comments over block comments.
- Per-language specifics belong in docs/style-guide.md. This section holds only the general rules.

# Temp Files

- Use `.tmp` in the project root for temporary files.
- Add `.tmp` to `.gitignore` and to the formatter and linter excludes.
- In background jobs, use `$CLAUDE_JOB_DIR/tmp` instead. It wins over `.tmp`.

# Review Checklist

- Run it when a repo is first set up and when I ask for a review or audit. Don't run it on every small change.
- Check each of these:
    - A dev tool such as a formatter or linter exists for a language not used in the repo.
    - A language used in the repo has no formatter or linter, and no note saying none exists.
    - More than one dev env manager is present.
    - CI or hooks call raw tools instead of Taskfile tasks.
    - A mandatory task is missing.
    - Editorconfig or docs/style-guide.md is missing.
    - A vulnerability scanner is missing, or `scan` doesn't run all of them.
    - The commit-msg hook is missing.
    - `.tmp` is not in `.gitignore` or the tool excludes.
- Report findings as numbered points. Don't fix anything without asking.

# Tool Choices

- Prefer tools written in Rust or Go. Fall back to others only when no fast equivalent exists, for example pytest, bats, shellcheck and semgrep.
- Dev env manager, in priority order:
    1. nix flakes.
    2. devbox by jetify.
    3. devcontainer.
- Task runner: Taskfile.dev.
- Git hooks: lefthook.
- Formatter runner: treefmt, so `task fmt` is one command for every language.
- Spell check: typos.
- Commit messages: Conventional Commits, written with the commit-messages skill and verified by cocogitto (`cog verify`). Cocogitto also generates changelogs.
- Vulnerability scanners: osv-scanner for dependencies, gitleaks for secrets, semgrep for SAST, trivy for containers and IaC.
- Per language:
    - GitHub Actions: actionlint.
    - JSON, JS, TS: Biome for format and lint (oxlint is an alternative linter), Bun for packages and tests, tsc for type checks (TypeScript 7+, the native Go compiler).
    - Markdown: dprint to format, rumdl to lint.
    - Nix: use flakes, alejandra to format, statix and deadnix to lint, `nix flake check` to test.
    - Python: uv, ruff and ty, with pytest for tests.
    - Rust: rustfmt, clippy, cargo-nextest, and cargo-deny for dependency audit.
    - Shell: shfmt to format, shellcheck to lint, bats for tests.
    - TOML: taplo to format and lint.
    - YAML: yamlfmt to format. No linter.
