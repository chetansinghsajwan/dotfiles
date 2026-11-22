---
name: naming
description: Choose and review names in code. Use when naming or renaming variables, functions, types, modules, files, CLI flags, config keys or Taskfile tasks, or when reviewing names in a diff.
---

# Naming

A repo's own conventions and `docs/style-guide.md` win over this skill. Read them first and match the existing vocabulary.

## Principles

- **Intent first:** The name says what the thing is or does, not how it works. Avoid vague words such as `data`, `info`, `util`, `helper`, `manager`, `handle`, `process` and `thing`.
- **Length follows scope:** A loop index or a three-line closure can be `i` or `x`. A public item or a wide-scope item gets a full descriptive name.
- **Parts of speech:** Nouns for values and types, verbs for functions and commands, `is_`, `has_`, `can_` or `should_` for booleans. Name booleans positively (`is_enabled`, not `is_not_disabled`).
- **Say the quantity:** A count ends in `_count`, a size in `_size`, a length in `_len`, a position in `_index` or `_offset`. `page_row_count`, not `page`. `step_size`, not `step`. A bare noun leaves the reader to guess whether it is a count, a size or a thing.
- **Actions are verb phrases with the target:** A function that moves, changes or runs something names the action and where it goes: `move_to_top`, `scroll_down`, `select_tab`, not `top`, `down` or `goto`. A bare noun or adjective (`top`, `next`, `up`) reads as a value, not as something that does anything.
- **Don't name a value with a word that is also a verb:** `step`, `page`, `list`, `set`, `open` and `close` can mean the thing or the act of doing it. Add the noun that fixes the meaning (`step_size`, `page_row_count`, `tab_open`).
- **Symmetric names:** Name the members of a family the same way: `move_to_top` and `move_to_bottom`, `tab_open` and `tab_close`, `with_suspended` and `with_overlay`.
- **Callbacks start with `on_`:** A method the framework calls when something happens (`on_event`, `on_tick`, `on_keypress`) is named for the event. Methods you call yourself are verbs (`run_action`).
- **Names don't shadow the language:** Don't call a variant, constant or type `None`, `Some`, `Ok`, `Err`, `Result` or `Error` unless it is that one.
- **One word per concept:** Pick one of `get`, `fetch` or `load` and use it everywhere. Keep the same pair for opposites: `add`/`remove`, `start`/`stop`, `open`/`close`. The reverse holds too: one meaning per word, so don't use `Open` for both "keep the popup open" and "open this file", and don't give one concept four type names across crates.
- **Units and types in the name when the type can't carry them:** `timeout_ms`, `size_bytes`, `path` vs `name`. Prefer a newtype when the language supports it.
- **No abbreviations** unless universal (`id`, `url`, `http`, `ctx`, `err`) or already used across the repo.
- **No noise:** Don't repeat the type or the module in the name (`user.user_name`, `config::ConfigStruct`, `IFoo`, `strName`).
- **Don't encode the implementation:** `users` not `user_list`, `cache` not `hash_map_cache`.
- **Honest names:** If a function does two things or has a side effect, the name says so, or the function gets split.
- **Searchable:** Avoid names that are one letter or a common word in a wide scope, since they are hard to grep.

## Case by language

| Language | Values, functions | Types        | Constants                                   | Files            |
| -------- | ----------------- | ------------ | ------------------------------------------- | ---------------- |
| Python   | `snake_case`      | `PascalCase` | `UPPER_SNAKE`                               | `snake_case.py`  |
| Rust     | `snake_case`      | `PascalCase` | `UPPER_SNAKE`                               | `snake_case.rs`  |
| Shell    | `snake_case`      | n/a          | `UPPER_SNAKE` (exported env: `UPPER_SNAKE`) | `kebab-case.sh`  |
| JS, TS   | `camelCase`       | `PascalCase` | `UPPER_SNAKE` or `camelCase`                | `kebab-case.ts`  |
| Nix      | `camelCase`       | n/a          | `camelCase`                                 | `kebab-case.nix` |

- **CLI flags:** `--kebab-case`, long form first, short form only for the most common flags.
- **Config keys:** match the format's own convention (TOML and YAML `snake_case` or `kebab-case`, JSON `camelCase`), and stay consistent within one file.
- **Taskfile tasks:** use the standard names (`setup`, `fmt`, `lint`, `test`, `scan`, `check`), then `kebab-case` verbs for the rest.
- **Git branches:** `type/short-kebab-description`, with the same types as Conventional Commits.

## Choosing a name

1. State what the thing is or does in one plain sentence.
2. Take the key noun or verb from it. That is the name.
3. Search the repo for the same concept under another name and reuse it.
4. If it needs "and" or "or", split the thing.
5. If no good name comes, the design is unclear. Fix that first.

## Renaming

1. Find every usage: code, docs, tests, config, scripts, generated files, and strings that build the name dynamically.
2. Use the language server or a structural tool where one exists, not a blind find-and-replace.
3. Rename in its own commit, with no behavior change, so the diff is easy to review.
4. For public APIs or user-facing flags and keys, keep the old name as a deprecated alias and say so in the changelog, or mark the commit as breaking.
5. Run `task check` afterward.

## Reviewing names

Flag a name when it:

- is vague, misleading or longer than its scope needs;
- is a bare noun for a count, size or position (`page`, `step`, `limit`) instead of saying which;
- is a bare noun or adjective for something that acts (`top`, `next`, `goto`);
- is a noun that is also a verb, so its meaning is ambiguous (`step`, `page`, `list`);
- breaks the symmetry of its family (`new`/`close`, `suspend`/`suspended`);
- is a callback without an `on_` prefix, or a type that clashes with another of the same name in the repo;
- uses a different word than the repo's existing word for the same concept;
- repeats its type or module;
- hides a side effect;
- breaks the case convention for its language.
