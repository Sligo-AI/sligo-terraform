.PHONY: create-environment create-environment-aws create-environment-gcp create-environment-azure help k8s logs-app logs-backend logs-gateway login-aws login-gcp pods restart-pods

SLIGO_NAMESPACE ?= sligo
SLIGO_DEPLOYMENTS = deployment/sligo-app deployment/sligo-backend deployment/mcp-gateway
LOGS_TAIL ?= 100

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-28s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

create-environment: ## Create a new environment (prompts for aws-eks, gcp-gke, or azure-aks)
	@./scripts/create-environment.sh

create-environment-aws: ## Create a new AWS EKS environment
	@./scripts/create-environment.sh aws-eks

create-environment-gcp: ## Create a new GCP GKE environment
	@./scripts/create-environment.sh gcp-gke

create-environment-azure: ## Create a new Azure AKS environment
	@./scripts/create-environment.sh azure-aks

login-aws: ## Log in to AWS CLI (SSO; runs configure sso if not yet set up)
	@aws sso login || aws configure sso

login-gcp: ## Log in to GCP CLI (browser + application default credentials)
	@gcloud auth login && gcloud auth application-default login

k8s: ## Show current K8s context, list all, and switch interactively
	@echo "Current context: $$(kubectl config current-context 2>/dev/null || echo '(none)')"
	@echo ""
	@echo "Available contexts:"
	@kubectl config get-contexts -o name | awk '{print NR". "$$0}'
	@echo ""
	@read -p "Enter number to switch (or Enter to cancel): " num; \
	if [ -n "$$num" ]; then \
	  ctx=$$(kubectl config get-contexts -o name | sed -n "$${num}p"); \
	  if [ -n "$$ctx" ]; then \
	    kubectl config use-context "$$ctx" && echo "Switched to: $$ctx"; \
	  else \
	    echo "Invalid selection"; \
	  fi; \
	fi

logs-app: ## View sligo-app logs
	@kubectl logs -n $(SLIGO_NAMESPACE) deployment/sligo-app --tail=$(LOGS_TAIL)

logs-backend: ## View sligo-backend logs
	@kubectl logs -n $(SLIGO_NAMESPACE) deployment/sligo-backend --tail=$(LOGS_TAIL)

logs-gateway: ## View mcp-gateway logs
	@kubectl logs -n $(SLIGO_NAMESPACE) deployment/mcp-gateway --tail=$(LOGS_TAIL)

pods: ## List pods in the Sligo namespace
	@kubectl get pods -n $(SLIGO_NAMESPACE)

restart-pods: ## Restart all Sligo K8s pods and check rollout status
	@echo "Restarting deployments..."
	@kubectl rollout restart $(SLIGO_DEPLOYMENTS) -n $(SLIGO_NAMESPACE)
	@echo "Waiting for rollouts to complete..."
	@kubectl rollout status $(SLIGO_DEPLOYMENTS) -n $(SLIGO_NAMESPACE) --timeout=5m
