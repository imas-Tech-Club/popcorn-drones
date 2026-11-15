# AGENTS.md

## Project

popcorn-drones is a framework for drone camera pipelines:

1. A frame source (ESP32 or a simulator) publishes JPEG frames to MQTT.
2. A bridge copies MQTT messages into Kafka.
3. A CV worker reads frames from Kafka and writes detections back to Kafka.
4. A CLI prints the detections.

The architecture is in issue #1. Work is tracked in GitHub issues, and each one has its tasks and acceptance criteria. Read the issue before you change code for it.

## What exists today

- `infra/docker-compose.yml`: Mosquitto, Kafka (single node, KRaft) and `kafka-init`, a one-shot service that creates the topics.
- `infra/kafka/create-topics.sh`: the list of Kafka topics.
- `scripts/smoke-test.sh`: checks that both brokers work.
- `docs/kafka-topics.md`: topic design.

Where service code goes is not decided yet. That is issue #10.

## Commands

```bash
make up      # start brokers and create topics
make smoke   # check that both brokers work
make down    # stop, keep data
make reset   # stop and delete Kafka data
```

Run `make up && make smoke` after changing anything in `infra/` or `scripts/`.

## Connection details

| Broker | From the host | From a container in the compose network |
|---|---|---|
| MQTT | `localhost:1883` | `mosquitto:1883` |
| Kafka | `localhost:9092` | `kafka:29092` |

There is no authentication and no TLS.

## Kafka

- Topics: `frames.raw`, `detections`, `telemetry`. Automatic topic creation is disabled, so add new topics to `infra/kafka/create-topics.sh`.
- Use `drone_id` as the record key.
- Consumer groups: `cv-worker` reads `frames.raw` and `cli-debug` reads `detections`.
- Details are in `docs/kafka-topics.md`. Update it when you change topics.

## Out of scope for the MVP (issue #1)

Mobile apps, ROS, web dashboard, TLS, fleet routing.
