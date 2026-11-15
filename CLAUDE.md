# CLAUDE.md

@AGENTS.md

## Claude Code notes

- `AGENTS.md` is the source of truth. Put project-wide guidance there, not here, so every agent sees it.
- Use this file only for Claude Code specifics.
- Before finishing a change under `infra/`, run `make up && make smoke` and report the result.
- Docker must be running. On macOS, start Docker Desktop first if `docker info` fails.
