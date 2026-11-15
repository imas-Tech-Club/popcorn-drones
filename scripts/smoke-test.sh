#!/usr/bin/env bash
set -euo pipefail

compose=(docker compose -f "$(dirname "$0")/../infra/docker-compose.yml")
kafka_bin=/opt/kafka/bin
bootstrap=kafka:29092
run_id="smoke-$(date +%s)"

echo "MQTT publish/subscribe"
"${compose[@]}" exec -T mosquitto sh -c \
  "mosquitto_sub -t $run_id -C 1 -W 10 & sleep 1; mosquitto_pub -t $run_id -m $run_id; wait" \
  | grep -q "$run_id"

echo "Kafka topics exist"
for topic in frames.raw detections telemetry; do
  "${compose[@]}" exec -T kafka "$kafka_bin/kafka-topics.sh" \
    --bootstrap-server "$bootstrap" --describe --topic "$topic" >/dev/null
done

echo "Kafka produce/consume"
"${compose[@]}" exec -T kafka "$kafka_bin/kafka-topics.sh" \
  --bootstrap-server "$bootstrap" --create --topic "$run_id" >/dev/null
echo "$run_id" | "${compose[@]}" exec -T kafka "$kafka_bin/kafka-console-producer.sh" \
  --bootstrap-server "$bootstrap" --topic "$run_id"
"${compose[@]}" exec -T kafka "$kafka_bin/kafka-console-consumer.sh" \
  --bootstrap-server "$bootstrap" --topic "$run_id" --from-beginning \
  --max-messages 1 --timeout-ms 15000 2>/dev/null \
  | grep -q "$run_id"
"${compose[@]}" exec -T kafka "$kafka_bin/kafka-topics.sh" \
  --bootstrap-server "$bootstrap" --delete --topic "$run_id"

echo "OK"
