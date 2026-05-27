.PHONY: up up-keycloak down clean

COMPOSE_KEYCLOAK = -f docker-compose.yml -f docker-compose.keycloak.yml

# Simple console auth (default)
up:
	@./scripts/bootstrap-env.sh
	@docker compose up -d --build
	@./scripts/open-app.sh

# Bundled Keycloak OIDC
up-keycloak:
	@./scripts/bootstrap-env.sh
	@docker compose $(COMPOSE_KEYCLOAK) up -d --build
	@./scripts/open-app.sh keycloak

# Both -f files so it tears down whichever mode is running
down:
	@docker compose $(COMPOSE_KEYCLOAK) down

clean:
	@docker compose $(COMPOSE_KEYCLOAK) down -v
	@rm -rf generated/
