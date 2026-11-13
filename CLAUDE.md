# ai-config

This repo holds global Claude Code configuration, split into modules. It is public. `rules/CLAUDE.md` is the user's global rules module, not the instructions for this repo; edit it only when asked to change those rules.

## Module rules

The full text is in the "Module rules" section of `README.md`. In short:

1. One top-level folder per module; nothing module-specific at the repo root. Folders starting with a dot are not modules.
2. Each module has a `README.md` with what it is, `## Expected benefits` and `## How to use`.
3. Each module is linked from the modules table in the root `README.md`.
4. A module that installs something has an idempotent entry in `install.sh`, named after its folder.
5. No secrets, no `.env`, no absolute user-profile or home paths; each module ignores its own `.env`, virtual environments, logs and caches.
6. No code comments except Arrange/Act/Assert in unit tests; no AI attribution anywhere.

## Before committing

Run `./check.sh` from the repo root (Git Bash on Windows) and fix every `FAIL` line. CI runs the same script on push and pull request to `main`.

Do not run `install.sh` with no argument, `rules` or `shunt` while testing: they change the user's `~/.claude` configuration.
