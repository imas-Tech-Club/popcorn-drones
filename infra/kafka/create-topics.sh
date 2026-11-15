#!/usr/bin/env bash
set -euo pipefail

bootstrap="${BOOTSTRAP_SERVER:-kafka:29092}"
partitions="${TOPIC_PARTITIONS:-3}"
bin=/opt/kafka/bin

ensure_topic() {
  local topic="$1"
  local configs="$2"

  "$bin/kafka-topics.sh" --bootstrap-server "$bootstrap" \
    --create --if-not-exists \
    --topic "$topic" \
    --partitions "$partitions" \
    --replication-factor 1

  "$bin/kafka-configs.sh" --bootstrap-server "$bootstrap" \
    --alter --entity-type topics --entity-name "$topic" \
    --add-config "$configs"

  echo "topic ready: $topic ($configs)"
}

ensure_topic frames.raw "retention.ms=3600000,retention.bytes=536870912,segment.bytes=67108864,segment.ms=600000,max.message.bytes=2097152,cleanup.policy=delete"
ensure_topic detections "retention.ms=604800000,cleanup.policy=delete"
ensure_topic telemetry "retention.ms=86400000,cleanup.policy=delete"

"$bin/kafka-topics.sh" --bootstrap-server "$bootstrap" --describe --topic 'frames.raw|detections|telemetry'
