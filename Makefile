# Convenience entrypoints so the stack runs with one command from the repo root.
# Everything delegates to docker/docker-compose.yml.

COMPOSE := docker compose -f docker/docker-compose.yml --project-directory docker

.PHONY: help up down logs ps rebuild test health clean

help:           ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

up:             ## Build images and start the full stack (frontend+backend+db+nginx)
	@test -f docker/.env || cp .env.example docker/.env
	$(COMPOSE) up --build -d
	@echo "Stack starting. App: http://localhost:8080  Health: http://localhost:8080/actuator/health"

down:           ## Stop the stack (keeps the database volume)
	$(COMPOSE) down

logs:           ## Tail logs from all services
	$(COMPOSE) logs -f

ps:             ## Show service + health status
	$(COMPOSE) ps

rebuild:        ## Force a clean rebuild of all images
	$(COMPOSE) build --no-cache

test:           ## Run backend tests (H2, no DB needed) + frontend lint/build
	cd backend && ./mvnw -B clean verify
	cd frontend && npm ci && npm run lint && npm run build

health:         ## Run the smoke test against the running stack
	BASE_URL=http://localhost:8080 ./scripts/health-check.sh

clean:          ## Stop the stack and DELETE the database volume (destructive)
	$(COMPOSE) down -v
