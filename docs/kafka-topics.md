# Kafka topics, partitions and consumer groups

Status: proposed for the bench MVP (issue #4). Topics are created by `infra/kafka/create-topics.sh`, which runs as the one-shot `kafka-init` service on every `make up`.

## Topics

| Topic | Producer | Consumers | Partitions | Retention | Notes |
|---|---|---|---|---|---|
| `frames.raw` | mqtt-kafka-bridge (#5) | `cv-worker` (#7) | 3 | 1 h **or** 512 MiB per partition | JPEG frames. Short retention because frames are heavy and only useful while fresh. `max.message.bytes=2 MiB`. |
| `detections` | cv-worker (#7) | `cli-debug` (#8) | 3 | 7 days | Small JSON results. Kept longer so a demo can be replayed. |
| `telemetry` | mqtt-kafka-bridge (#5) | optional | 3 | 24 h | Battery, RSSI, GPS placeholders. |

Auto topic creation is **disabled** on the broker. A typo in a topic name fails fast instead of silently creating a new topic. New topics must be added to `create-topics.sh`.

## Keying strategy

Every record is produced with **key = `drone_id`**.

- All records of a drone land on the same partition, so **per-drone ordering is preserved** (frame N is processed before frame N+1).
- Different drones spread across partitions, so the fleet scales horizontally.
- Producers must not send records without a key. Null-key records are spread round-robin and lose ordering.

`drone_id` format is owned by the MQTT contracts (#3). Kafka only needs it to be a stable string.

## Partitions

3 partitions per topic for the bench:

- Enough to exercise parallelism: up to 3 `cv-worker` instances can share the load.
- Cheap on a laptop.
- Override with `TOPIC_PARTITIONS` in `infra/.env`. Partitions can only be **increased** on an existing topic, and increasing them changes which partition a key maps to. Run `make reset` if you want a lower number.

## Consumer groups

| Group | Reads | Purpose |
|---|---|---|
| `cv-worker` | `frames.raw` | Inference. Instances of the worker share partitions. |
| `cli-debug` | `detections` | Operator CLI tail. |

Each group keeps its own offsets, so the CLI and the worker never steal messages from each other. Debug tools that should not affect anyone else must use their own group name (or no group, like `kafka-console-consumer` does by default).

## Message size

The broker accepts up to 2 MiB per record (`KAFKA_MESSAGE_MAX_BYTES`). A 640 px JPEG is roughly 50–150 KB, so there is plenty of headroom. Producers must also raise their own limit (`max.request.size` / `BatchBytes` in Go clients) if they send anything above the client default of 1 MiB.

## Retention and disk

`frames.raw` uses `segment.bytes=64 MiB` and `segment.ms=10 min` so that retention actually kicks in on a small bench (Kafka only deletes whole closed segments). Worst case on disk for frames is about 3 × 512 MiB.

## Changing topics

1. Edit `ensure_topic` calls in `infra/kafka/create-topics.sh`.
2. Run `make up`. The script is idempotent: it creates missing topics and re-applies configs on existing ones.
3. Update this document and the table in the root `README.md`.
