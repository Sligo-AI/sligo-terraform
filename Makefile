.PHONY: create-environment create-environment-aws create-environment-gcp create-environment-azure help

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
