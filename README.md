# popcorn-drones

Framework for drone camera pipelines. Frames are published over MQTT, bridged into Kafka, processed by a computer vision worker, and detections are shown in a CLI. The architecture is defined in issue #1.

## Local brokers

Requirements: Docker with Compose v2 and `make`.

```bash
make up      # start Mosquitto and Kafka, create Kafka topics
make smoke   # check that both brokers work
make down    # stop, keep Kafka data
make reset   # stop and delete Kafka data
```

| Broker | From the host | From a container in the compose network |
|---|---|---|
| Mosquitto (MQTT) | `localhost:1883` | `mosquitto:1883` |
| Kafka | `localhost:9092` | `kafka:29092` |

- Mosquitto accepts anonymous connections without TLS. This is for the local bench only.
- Kafka runs as a single node in KRaft mode, without ZooKeeper.
- Both services have healthchecks. `make up` returns once they are healthy and the topics exist.
- Use `localhost:9092` for programs running on your machine and `kafka:29092` for services running inside the compose network. Kafka tells clients which address to reconnect to, so using the wrong one makes the client fail after it first connects.

## Kafka topics

Created by [infra/kafka/create-topics.sh](infra/kafka/create-topics.sh). Automatic topic creation is disabled, so new topics must be added to that script.

| Topic | Partitions | Retention |
|---|---|---|
| `frames.raw` | 3 | 1 hour |
| `detections` | 3 | 7 days (Kafka default) |
| `telemetry` | 3 | 7 days (Kafka default) |

Keys, consumer groups and the reasons behind each value: [docs/kafka-topics.md](docs/kafka-topics.md).

## Coding agents

[AGENTS.md](AGENTS.md) describes the project for coding agents. [CLAUDE.md](CLAUDE.md) imports it.
