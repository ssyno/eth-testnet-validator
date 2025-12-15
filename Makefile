.PHONY: help provision start check clean logs status

NAMESPACE ?= eth-validator

# Default target
help:
	@echo "Ethereum Testnet Validator"
	@echo ""
	@echo "Usage:"
	@echo "  make provision          Deploy infrastructure (local KIND)"
	@echo "  make provision-cloud    Deploy to cloud Kubernetes"
	@echo "  make start KEYS=<dir>   Import validator keys"
	@echo "  make check              Health check"
	@echo ""
	@echo "Helpers:"
	@echo "  make status             Show pod status"
	@echo "  make logs               Follow all logs"
	@echo "  make clean              Remove everything"

# === Main 3 Commands ===

provision:
	./provision.sh

provision-cloud:
	./provision.sh --cloud

start:
ifndef KEYS
	@echo "Usage: make start KEYS=./validator_keys"
	@exit 1
endif
	./start-validator.sh $(KEYS)

check:
	./check-health.sh

# === Helpers ===

status:
	@kubectl get pods -n $(NAMESPACE) -o wide

logs:
	kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/instance=eth-validator -f --max-log-requests=10

clean:
	helm uninstall eth-validator -n $(NAMESPACE) 2>/dev/null || true
	kind delete cluster --name eth-validator 2>/dev/null || true
	@echo "Cleaned up"
