# AGENTS.md

Guide for coding agents working on this repository. Humans should start with [README.md](README.md).

## Project

popcorn-drones is a self-hosted framework for drone camera pipelines, meant to be reused by future drone projects.

Bench MVP pipeline:

1. Frame source (ESP32 firmware or simulator) publishes JPEG frames and telemetry to **MQTT** (Mosquitto).
2. **mqtt-kafka-bridge** (Go) mirrors MQTT topics into **Kafka**.
3. **cv-worker** (Go + ONNX Runtime) consumes `frames.raw`, runs object detection, produces to `detections`.
4. **CLI** tails `detections`.

Work is tracked in GitHub issues. Each issue states its goal, tasks and acceptance criteria. Read the issue before changing code for it, and stay inside its scope.

## Current state

Only the local infrastructure exists:

- `infra/docker-compose.yml`: Mosquitto 2, Kafka 3.9 (single node, KRaft), and a one-shot `kafka-init` service.
- `infra/kafka/create-topics.sh`: idempotent topic bootstrap.
- `scripts/smoke-test.sh`: end-to-end broker check, also run by `.github/workflows/infra-smoke.yml`.
- `docs/kafka-topics.md`: topic, keying, partition and consumer group design.

Directories for services (`services/`, `cmd/`, `contracts/`) do not exist yet. Their layout is decided in issue #10. Do not invent a different layout.

## Commands

| Task | Command |
|---|---|
| Start brokers and create topics | `make up` |
| Verify the stack | `make smoke` |
| Describe topics | `make topics` |
| Watch MQTT | `make mqtt-sub` |
| Tail a Kafka topic | `make kafka-consume TOPIC=<name>` |
| Stop (keep data) | `make down` |
| Wipe all broker data | `make reset` |

Run `make up && make smoke` after any change under `infra/`, `scripts/` or the `Makefile`. CI runs the same.

## Connection details

| Broker | From the host | From a container in the compose network |
|---|---|---|
| MQTT | `localhost:1883` | `mosquitto:1883` |
| Kafka | `localhost:9092` | `kafka:29092` |

Never point a host process at `kafka:29092` or a container at `localhost:9092`. Kafka returns the advertised address of the listener the client used, so the wrong one fails after the first metadata request.

No authentication and no TLS. This is a bench setup on a local network by design (issue #1 lists TLS as out of scope).

## Kafka rules

- Topics: `frames.raw`, `detections`, `telemetry`. Auto-creation is disabled.
- To add or change a topic: edit `infra/kafka/create-topics.sh`, update `docs/kafka-topics.md` and the topic table in `README.md`, run `make up && make smoke`.
- Every record must be keyed by `drone_id`. This preserves per-drone ordering.
- Consumer groups: `cv-worker` for `frames.raw`, `cli-debug` for `detections`. New consumers get their own group name.
- Max record size is 2 MiB. Go producers must raise their client-side limit if they need more than 1 MiB.

## MQTT rules

- Topic tree draft (issue #3): `drones/{id}/camera/jpeg`, `drones/{id}/telemetry`, `drones/{id}/cmd/#`, `drones/{id}/events/detections`.
- Until #3 is merged, treat that tree as a draft and do not hardcode payload formats in shared code.

## Conventions

- Language for code, docs, commits and PRs: English.
- No comments in code. Names should explain intent. Rationale goes in the PR description or in `docs/`.
- Use descriptive names. Avoid single-letter variables, including in lambdas and loops.
- Prefer simple, operable solutions. Pin image versions (no `latest`).
- Shell scripts: `bash` with `set -euo pipefail`, idempotent where possible.
- Configuration through environment variables with local defaults. Document new variables in `infra/.env.example`.
- One issue per PR. Reference it with `Closes #N`.
- Update `README.md` and this file when commands, layout or conventions change.

## Boundaries

- Do not add cloud services, managed brokers or external dependencies. The project is self-hosted.
- Do not add a web UI, ROS, mobile apps or TLS for the MVP (out of scope in #1).
- Do not change ports, listener names or topic names without updating every doc that mentions them.
- Do not commit `infra/.env`, model weights or large sample data.
