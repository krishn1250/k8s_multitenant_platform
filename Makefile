# One-command workflow for the local platform.
# Requirements: docker, kind, kubectl, terraform, flux, helm (see README).

CLUSTER      ?= platform-dev
ENV          ?= dev
GH_USER      ?= $(shell git config --get remote.origin.url | sed -E 's#.*[:/]([^/]+)/[^/]+(\.git)?$$#\1#' | tr 'A-Z' 'a-z')
IMAGE        ?= ghcr.io/$(GH_USER)/orders-api
TAG          ?= 0.1.0

.PHONY: init help up down image vault-setup status grafana gateway load chaos-errors chaos-heal chaos-pods chaos-route test lint validate

help: ## Show targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk -F':.*?## ' '{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

init: ## Replace YOUR_GITHUB_USER placeholders (run once after cloning)
	./scripts/init.sh $(GH_USER)

up: ## Create kind cluster + bootstrap Flux (needs GITHUB_TOKEN)
	cd terraform && terraform init -upgrade && terraform apply -auto-approve \
	  -var "github_owner=$(GH_USER)" -var "environment=$(ENV)" -var "cluster_name=$(CLUSTER)"
	@echo "Waiting for Flux to reconcile infrastructure..."
	flux get kustomizations --watch --timeout 10m || true

down: ## Destroy the cluster
	cd terraform && terraform destroy -auto-approve -var "github_owner=$(GH_USER)" -var "environment=$(ENV)" -var "cluster_name=$(CLUSTER)"

image: ## Build the app image and load it into kind (no registry needed)
	docker build -t $(IMAGE):$(TAG) apps/orders-api
	kind load docker-image $(IMAGE):$(TAG) --name $(CLUSTER)

vault-setup: ## Configure Vault: k8s auth, per-tenant policies, seed secrets
	./scripts/vault-setup.sh

status: ## Show the state of everything Flux manages
	flux get all -A --status-selector ready=false || true
	kubectl get gateway,httproute -A
	kubectl get externalsecret,secretstore -A

grafana: ## Port-forward Grafana on http://localhost:3000 (admin / see README)
	kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80

gateway: ## Port-forward the shared Gateway on http://localhost:8080
	./scripts/gateway-port-forward.sh

load: ## Run k6 load test against team-a (Gateway must be port-forwarded)
	docker run --rm -i --network host -e TENANT=team-a grafana/k6 run - < loadtest/orders.js

chaos-errors: ## Make team-a return 20% HTTP 500s (burns the error budget)
	./scripts/chaos/inject-errors.sh team-a 0.2

chaos-heal: ## Turn fault injection off for team-a
	./scripts/chaos/inject-errors.sh team-a 0

chaos-pods: ## Kill random team-a pods every 20s for 2 minutes
	./scripts/chaos/kill-pods.sh team-a

chaos-route: ## Break team-a HTTPRoute backend ref (fix it with git, not kubectl)
	./scripts/chaos/break-route.sh team-a

test: ## Run app unit tests
	cd apps/orders-api && python -m pytest -q

validate: ## Render every overlay and validate manifests locally
	./scripts/validate.sh
