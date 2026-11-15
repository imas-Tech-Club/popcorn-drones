#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
compose=(docker compose -f "$repo_root/infra/docker-compose.yml")
kafka_bin=/opt/kafka/bin
bootstrap=kafka:29092
mqtt_port="${MQTT_PORT:-1883}"
kafka_port="${KAFKA_PORT:-9092}"
expected_topics=(frames.raw detections telemetry)
run_id="smoke-$(date +%s)-$RANDOM"

pass() { echo "  PASS $1"; }
fail() { echo "  FAIL $1"; exit 1; }

wait_healthy() {
  local service="$1"
  local container
  container="$("${compose[@]}" ps -q "$service")"
  [[ -n "$container" ]] || fail "$service is not running (run: make up)"
  for _ in $(seq 1 60); do
    [[ "$(docker inspect -f '{{.State.Health.Status}}' "$container")" == "healthy" ]] && return 0
    sleep 2
  done
  fail "$service did not become healthy"
}

echo "Brokers"
wait_healthy mosquitto && pass "mosquitto healthy"
wait_healthy kafka && pass "kafka healthy"

echo "Host ports"
nc -z -w 2 localhost "$mqtt_port" >/dev/null 2>&1 && pass "MQTT reachable on localhost:$mqtt_port" || fail "MQTT not reachable on localhost:$mqtt_port"
nc -z -w 2 localhost "$kafka_port" >/dev/null 2>&1 && pass "Kafka reachable on localhost:$kafka_port" || fail "Kafka not reachable on localhost:$kafka_port"

echo "MQTT round trip"
mqtt_topic="drones/smoke/camera/jpeg"
"${compose[@]}" exec -T mosquitto sh -c \
  "mosquitto_sub -h localhost -t '$mqtt_topic' -C 1 -W 10 > /tmp/$run_id & sleep 1; mosquitto_pub -h localhost -t '$mqtt_topic' -m '$run_id'; wait; cat /tmp/$run_id" \
  | grep -q "$run_id" && pass "pub/sub on $mqtt_topic" || fail "MQTT message not received"

echo "Kafka topics"
for _ in $(seq 1 30); do
  init_state="$(docker inspect -f '{{.State.Status}} {{.State.ExitCode}}' popcorn-kafka-init 2>/dev/null || true)"
  [[ "$init_state" == "exited 0" ]] && break
  [[ "$init_state" == exited* ]] && fail "kafka-init exited with error (docker logs popcorn-kafka-init)"
  sleep 2
done
for topic in "${expected_topics[@]}"; do
  description="$("${compose[@]}" exec -T kafka "$kafka_bin/kafka-topics.sh" --bootstrap-server "$bootstrap" --describe --topic "$topic" 2>/dev/null)" \
    || fail "topic $topic missing"
  partitions="$(grep -o 'PartitionCount: [0-9]*' <<<"$description" | awk '{print $2}')"
  pass "topic $topic exists ($partitions partitions)"
done

echo "Kafka round trip"
printf '%s:%s\n' "smoke" "$run_id" | "${compose[@]}" exec -T kafka "$kafka_bin/kafka-console-producer.sh" \
  --bootstrap-server "$bootstrap" --topic frames.raw \
  --property parse.key=true --property key.separator=: >/dev/null
"${compose[@]}" exec -T kafka "$kafka_bin/kafka-console-consumer.sh" \
  --bootstrap-server "$bootstrap" --topic frames.raw --from-beginning \
  --timeout-ms 15000 --property print.key=true 2>/dev/null \
  | grep -q "$run_id" && pass "produce/consume on frames.raw keyed by drone_id" || fail "Kafka message not consumed"

echo "All smoke checks passed."
