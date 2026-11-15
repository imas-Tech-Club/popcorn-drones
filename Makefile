COMPOSE := docker compose -f infra/docker-compose.yml
KAFKA_BIN := /opt/kafka/bin
BOOTSTRAP := kafka:29092

.PHONY: help up down reset ps logs topics smoke mqtt-sub kafka-consume

help:
	@echo "make up            start Mosquitto + Kafka and create topics"
	@echo "make down          stop the stack (keeps data)"
	@echo "make reset         stop the stack and delete all broker data"
	@echo "make ps            show service status"
	@echo "make logs          follow broker logs"
	@echo "make topics        describe Kafka topics"
	@echo "make smoke         run end-to-end broker smoke test"
	@echo "make mqtt-sub      subscribe to drones/# on MQTT"
	@echo "make kafka-consume TOPIC=detections   tail a Kafka topic"

up:
	$(COMPOSE) up -d --wait mosquitto kafka
	$(COMPOSE) up kafka-init --exit-code-from kafka-init

down:
	$(COMPOSE) down

reset:
	$(COMPOSE) down -v --remove-orphans

ps:
	$(COMPOSE) ps -a

logs:
	$(COMPOSE) logs -f mosquitto kafka

topics:
	$(COMPOSE) exec kafka $(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BOOTSTRAP) --describe

smoke:
	./scripts/smoke-test.sh

mqtt-sub:
	$(COMPOSE) exec mosquitto mosquitto_sub -h localhost -t 'drones/#' -v

TOPIC ?= frames.raw
kafka-consume:
	$(COMPOSE) exec kafka $(KAFKA_BIN)/kafka-console-consumer.sh --bootstrap-server $(BOOTSTRAP) --topic $(TOPIC) --from-beginning --property print.key=true
