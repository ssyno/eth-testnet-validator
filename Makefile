.PHONY: provision start-validator check-health up down status logs clean

NAMESPACE ?= eth-validator
RELEASE ?= eth-validator

# Main 3 commands
provision:
	./provision.sh

start-validator:
	@echo "Usage: ./start-validator.sh <keys_directory>"

check-health:
	./check-health.sh

# Helpers
up:
	./scripts/kind-setup.sh

down:
	./scripts/kind-teardown.sh

status:
	@kubectl get pods -n $(NAMESPACE)

logs:
	kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/instance=$(RELEASE) -f --max-log-requests=10

clean:
	helm uninstall $(RELEASE) -n $(NAMESPACE) || true
