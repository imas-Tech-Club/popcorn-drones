# popcorn-drones

Software-first framework for drone camera pipelines: frames go from a drone (or a simulator) over **MQTT**, are bridged into **Kafka**, processed by a **computer vision worker**, and detections are shown in a **CLI**. Self-hosted, no cloud dependencies.

```
frame source ──MQTT──▶ Mosquitto ──bridge──▶ Kafka ──▶ cv-worker ──▶ Kafka ──▶ CLI
 (ESP32 / sim)                              frames.raw              detections
```

The broader architecture and its open decisions live in issue #1.

## Status

| Piece | Issue | State |
|---|---|---|
| Local brokers (Mosquitto + Kafka) | #2 | ✅ `infra/` |
| Kafka topics and consumer groups | #4 | ✅ `infra/kafka/`, `docs/kafka-topics.md` |
| MQTT topic tree and contracts | #3 | open |
| MQTT → Kafka bridge (Go) | #5 | open |
| Frame publisher simulator | #6 | open |
| CV worker (Go + ONNX) | #7 | open |
| Detections CLI | #8 | open |

## Quickstart

Requirements: Docker with Compose v2, `make`, `nc`.

```bash
make up      # start Mosquitto + Kafka and create topics
make smoke   # end-to-end check of both brokers
```

Everything else:

```bash
make help
```

## Local stack

| Service | Host address | Address from other containers | Notes |
|---|---|---|---|
| Mosquitto | `localhost:1883` | `mosquitto:1883` | Anonymous access, no TLS (bench only) |
| Kafka | `localhost:9092` | `kafka:29092` | Single node, KRaft (no ZooKeeper) |

Ports can be changed by copying `infra/.env.example` to `infra/.env`.

**Which Kafka address to use:** code running on your machine (`go run ...`) uses `localhost:9092`. Code running as a service inside `infra/docker-compose.yml` uses `kafka:29092`. Mixing them up is the classic "connects but never receives anything" problem, because Kafka tells clients to reconnect to the address advertised for the listener they came in on.

### Kafka topics

| Topic | Key | Partitions | Retention |
|---|---|---|---|
| `frames.raw` | `drone_id` | 3 | 1 h / 512 MiB per partition |
| `detections` | `drone_id` | 3 | 7 days |
| `telemetry` | `drone_id` | 3 | 24 h |

Topic auto-creation is disabled. Design and rationale: [docs/kafka-topics.md](docs/kafka-topics.md).

### Useful commands

```bash
make ps                           # service status
make logs                         # follow broker logs
make topics                       # describe Kafka topics
make mqtt-sub                     # watch everything under drones/#
make kafka-consume TOPIC=detections
make down                         # stop, keep data
make reset                        # stop and wipe all broker data
```

Publish a test MQTT message without installing anything:

```bash
docker exec popcorn-mosquitto mosquitto_pub -t drones/test/telemetry -m '{"battery":0.9}'
```

## Repository layout

```
infra/
  docker-compose.yml        Mosquitto, Kafka, kafka-init
  mosquitto/mosquitto.conf
  kafka/create-topics.sh    idempotent topic bootstrap
  .env.example
scripts/smoke-test.sh       broker smoke test (also runs in CI)
docs/                       design docs
.github/workflows/          CI
```

Service code (`services/`, `cmd/`, `contracts/`) will be added by the scaffold issue (#10).

## Troubleshooting

- **Kafka container keeps restarting after changing listener settings:** run `make reset`. KRaft metadata is stored in the `kafka-data` volume.
- **Port already in use:** set `MQTT_PORT` / `KAFKA_PORT` in `infra/.env` and run `make up` again.
- **`kafka-init` fails:** `docker logs popcorn-kafka-init`. It only runs after Kafka is healthy, so a failure usually means a bad topic config in `create-topics.sh`.

## Working with AI agents

[AGENTS.md](AGENTS.md) describes the project for coding agents (Codex, Cursor, Copilot, Claude Code, etc.). `CLAUDE.md` imports it. Keep `AGENTS.md` up to date when you change commands, layout or conventions.
