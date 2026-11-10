.PHONY: help install lint test build docker-build docker-run clean validate plan deploy-local bootstrap rollback

APP_DIR ?= app
DOCKER_IMAGE ?= ghcr.io/your-org/blueprint-app
DOCKER_TAG ?= dev-latest
ENV ?= dev

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: ## Install Python dependencies
	cd $(APP_DIR) && pip install -r requirements.txt

lint: ## Run linting (ruff) and type checking (mypy)
	cd $(APP_DIR) && ruff check src/
	cd $(APP_DIR) && mypy src/ --ignore-missing-imports

test: ## Run tests with coverage
	cd $(APP_DIR) && python -m pytest

build: lint test ## Build application (lint + test)
	@echo "Build complete"

docker-build: ## Build Docker image
	docker build \
		--build-arg VERSION=$(DOCKER_TAG) \
		--build-arg COMMIT_SHA=$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown") \
		--build-arg BUILD_TIME=$(shell date -u +%Y-%m-%dT%H:%M:%SZ) \
		-t $(DOCKER_IMAGE):$(DOCKER_TAG) \
		-f $(APP_DIR)/Dockerfile \
		$(APP_DIR)

docker-run: ## Run Docker container locally
	docker run -p 8080:8080 -p 9090:9090 \
		-e ENVIRONMENT=development \
		-e LOG_LEVEL=debug \
		-e ENABLE_SWAGGER=true \
		$(DOCKER_IMAGE):$(DOCKER_TAG)

clean: ## Clean build artifacts
	rm -rf $(APP_DIR)/.ruff_cache
	rm -rf $(APP_DIR)/.mypy_cache
	rm -rf $(APP_DIR)/.pytest_cache
	rm -rf $(APP_DIR)/htmlcov
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete

validate: ## Run all validation checks
	@echo "=== Terraform ==="
	cd terraform && terraform fmt -check && terraform init -backend=false && terraform validate
	@echo "=== Helm ==="
	helm lint helm/blueprint-app
	@echo "=== Kustomize ==="
	kustomize build gitops/apps/blueprint-app/overlays/dev
	@echo "=== OPA ==="
	opa test security/opa/tests/ security/opa/policies/ -v
	@echo "=== YAML ==="
	yamllint -c .yamllint .
	@echo "=== Python ==="
	cd app && ruff check src/ && mypy src/ --ignore-missing-imports && python -m pytest
	@echo "=== Dockerfile ==="
	hadolint app/Dockerfile
	@echo "=== All validations passed ==="

plan: ## Run Terraform plan (AWS creds required)
	cd terraform && terraform init && terraform plan

deploy-local: ## Deploy to local k3d cluster
	./scripts/deploy-local.sh $(ENV)

bootstrap: ## Bootstrap local k3d cluster
	./scripts/bootstrap.sh

rollback: ## Rollback deployment
	./scripts/rollback.sh $(ENV) $(IMAGE_TAG)

all: clean lint test docker-build ## Clean, lint, test, and build Docker image
