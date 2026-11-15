#!/usr/bin/env bash
set -euo pipefail

create_topic() {
  /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:29092 \
    --create --if-not-exists --partitions 3 --replication-factor 1 \
    --topic "$@"
}

create_topic frames.raw --config retention.ms=3600000 --config segment.ms=600000
create_topic detections
create_topic telemetry
