COMPOSE := docker compose -f infra/docker-compose.yml

.PHONY: up down reset smoke

up:
	$(COMPOSE) up -d --wait
	$(COMPOSE) wait kafka-init

down:
	$(COMPOSE) down

reset:
	$(COMPOSE) down -v

smoke:
	./scripts/smoke-test.sh
