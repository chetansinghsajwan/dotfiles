# Style guide

The source of truth for style in this repo. General rules live in the author's global agent
instructions; this file holds what is specific to this repo.

## Tooling

Run everything through Taskfile tasks inside the dev shell (`nix develop`): `task fmt`,
`task clippy`, `task test`, `task scan`, `task check`. Hooks and CI call these tasks, never the raw
tools.

hk (`.config/hk.pkl`) runs the formatters, the linters and the git hooks: `task fmt` is `hk fix --all`, `task check` is `hk check --all`, and the pre-commit, commit-msg and pre-push hooks run the same steps on the staged files. hk reads `.config/hk.pkl` with `pkl`, so the dev shell provides both. The pre-push hook runs the linters only: `task test` evaluates every host configuration and takes minutes, so CI runs it instead.

| Language       | Format             | Lint               |
| -------------- | ------------------ | ------------------ |
| GitHub Actions | yamlfmt            | actionlint, zizmor |
| Lua            | stylua             | none exists        |
| Markdown       | rumdl fmt + dprint | rumdl              |
| Nix            | alejandra          | statix, deadnix    |
| PowerShell     | none exists        | none exists        |
| Python         | ruff format        | ruff               |
| Rust           | rustfmt            | clippy             |
| Shell          | shfmt              | shellcheck         |
| TOML           | taplo              | taplo              |
| YAML           | yamlfmt            | none exists        |

Shell means `*.sh` and `*.zsh` for shfmt, and `*.sh` only for shellcheck, which does not parse
zsh. Spelling is checked with typos. Rust tests run with cargo-nextest, and the Nix test is the
evaluation of every host configuration. Scans: cargo-deny and osv-scanner for dependencies,
gitleaks for secrets, semgrep for SAST. Trivy is not used: the repo has no containers or IaC.

The submodules (`pkgs/helix-improved`, `pkgs/tuikit`) and the installed skills (`.agents`,
`.claude`) are not ours to format or lint, so every tool excludes them.

## Nix

- **Indent:** 4 spaces, set by `alejandra.toml`; do not hand-format.
- **Repeated keys:** the `statix` lint `repeated_keys` is off. Dotted paths such as
  `programs.git.enable` stay one option per line, which reads and greps better.
- **Standalone Home Manager:** `homeConfigurations` does not evaluate yet (`dotfiles.currentUser`
  is never set), so `task test` does not cover it.

## Rust

- **Tests:** unit tests go in a separate `tests.rs` beside the module (`#[cfg(test)] mod tests;`),
  never inline. A binary's `main.rs` gets `src/tests.rs`.

## Commits

Conventional Commits, verified by `cog verify` in the commit-msg hook.

## Temp files

Use `.tmp/` in the repo root. It is git-ignored and excluded from the formatters and linters.
