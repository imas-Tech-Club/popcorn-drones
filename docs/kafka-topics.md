# Kafka topics

Design for issue #4. Topics are created by `infra/kafka/create-topics.sh` on every `make up`. Topics that already exist are left unchanged.

## Topics

| Topic | Producer | Consumer group | Partitions | Retention |
|---|---|---|---|---|
| `frames.raw` | MQTT → Kafka bridge (#5) | `cv-worker` (#7) | 3 | 1 hour |
| `detections` | CV worker (#7) | `cli-debug` (#8) | 3 | 7 days (default) |
| `telemetry` | MQTT → Kafka bridge (#5) | none yet | 3 | 7 days (default) |

## Keys

Producers use `drone_id` as the record key. Records with the same key go to the same partition, so the frames of each drone are processed in order. The format of `drone_id` is defined by the MQTT contracts (#3).

## Partitions

Each topic has 3 partitions, the upper end of the 1–3 range in #4. Up to 3 `cv-worker` instances can share the load. You can add partitions to an existing topic, but you cannot remove them, and adding them changes which partition each key goes to.

## Consumer groups

Each consumer group keeps its own read position (offsets). `cv-worker` and `cli-debug` therefore both receive every record of the topic they read, and do not interfere with each other.

## Retention

Frames are only useful while they are recent and take up most of the disk, so `frames.raw` keeps them for 1 hour. Kafka only deletes data in whole log segments, and by default a segment only closes after 7 days or 1 GB. `frames.raw` sets `segment.ms` to 10 minutes so the 1-hour retention applies on a bench with little traffic.

## Message size

Kafka's default maximum record size is about 1 MB. A 640 px JPEG is roughly 50–150 KB, so the default is enough.

## Changing a topic

The script only creates topics that do not exist yet. To change a topic that already exists, either:

- run `make reset && make up` (this deletes all Kafka data), or
- change it in place with `kafka-configs.sh`.
