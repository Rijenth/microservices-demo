CLUSTER_NAME   ?= boutique
KUBE_CONTEXT   ?= kind-$(CLUSTER_NAME)
KUSTOMIZE_DIR  ?= kustomize
TF_AWS_DIR     ?= terraform/aws
TF_GCP_DIR     ?= terraform/gcp

.DEFAULT_GOAL := help

# ──────────────────────────────────────────────────────────────────────────────
# HELP
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: help
help:
	@echo ""
	@echo "Online Boutique – Makefile"
	@echo "══════════════════════════════════════════════════"
	@echo ""
	@echo "  Cluster (kind)"
	@echo "  ──────────────"
	@echo "  make cluster-create    Create a local kind cluster"
	@echo "  make cluster-delete    Delete the kind cluster"
	@echo "  make cluster-status    Show cluster nodes and info"
	@echo ""
	@echo "  Deploy"
	@echo "  ──────"
	@echo "  make deploy            Apply kustomize (with Grafana stack)"
	@echo "  make undeploy          Delete all kustomize resources"
	@echo "  make redeploy          undeploy + deploy"
	@echo "  make restart           Restart all deployments"
	@echo ""
	@echo "  Status"
	@echo "  ──────"
	@echo "  make status            Show all pods status"
	@echo "  make watch             Watch pods in real time"
	@echo "  make logs              Follow all pods logs (stern required)"
	@echo "  make events            Show Kubernetes events"
	@echo ""
	@echo "  Port-forward"
	@echo "  ────────────"
	@echo "  make open-app          Forward frontend  → http://localhost:8080"
	@echo "  make open-grafana      Forward Grafana   → http://localhost:3000"
	@echo "  make open-prometheus   Forward Prometheus→ http://localhost:9090"
	@echo "  make open-tempo        Forward Tempo     → http://localhost:3200"
	@echo "  make open-loki         Forward Loki      → http://localhost:3100"
	@echo "  make open-all          Forward all services (background)"
	@echo ""
	@echo "  Terraform – AWS"
	@echo "  ───────────────"
	@echo "  make tf-aws-init       terraform init (AWS)"
	@echo "  make tf-aws-plan       terraform plan (AWS)"
	@echo "  make tf-aws-apply      terraform apply (AWS)"
	@echo "  make tf-aws-destroy    terraform destroy (AWS)"
	@echo ""
	@echo "  Terraform – GCP"
	@echo "  ───────────────"
	@echo "  make tf-gcp-init       terraform init (GCP)"
	@echo "  make tf-gcp-plan       terraform plan (GCP)"
	@echo "  make tf-gcp-apply      terraform apply (GCP)"
	@echo "  make tf-gcp-destroy    terraform destroy (GCP)"
	@echo ""
	@echo "  Utils"
	@echo "  ─────"
	@echo "  make load-test         Scale loadgenerator to stress the app"
	@echo "  make load-stop         Scale loadgenerator back to 1"
	@echo "  make clean             Delete cluster + all local state"
	@echo ""

# ──────────────────────────────────────────────────────────────────────────────
# CLUSTER
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: cluster-create
cluster-create:
	@echo "→ Creating kind cluster '$(CLUSTER_NAME)'..."
	kind create cluster --name $(CLUSTER_NAME)
	kubectl config use-context $(KUBE_CONTEXT)
	@echo "✓ Cluster ready."

.PHONY: cluster-delete
cluster-delete:
	@echo "→ Deleting kind cluster '$(CLUSTER_NAME)'..."
	kind delete cluster --name $(CLUSTER_NAME)

.PHONY: cluster-status
cluster-status:
	kubectl config use-context $(KUBE_CONTEXT)
	kubectl cluster-info
	kubectl get nodes -o wide

# ──────────────────────────────────────────────────────────────────────────────
# DEPLOY
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: deploy
deploy:
	@echo "→ Deploying Online Boutique + Grafana stack..."
	kubectl apply -k $(KUSTOMIZE_DIR)/ --validate=false
	@echo "✓ Resources applied. Run 'make watch' to follow startup."

.PHONY: undeploy
undeploy:
	@echo "→ Removing all resources..."
	kubectl delete -k $(KUSTOMIZE_DIR)/ --ignore-not-found=true

.PHONY: redeploy
redeploy: undeploy deploy

.PHONY: restart
restart:
	@echo "→ Restarting all deployments..."
	kubectl rollout restart deployment
	kubectl rollout restart daemonset

# ──────────────────────────────────────────────────────────────────────────────
# STATUS / LOGS
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: status
status:
	kubectl get pods,svc,daemonset -o wide

.PHONY: watch
watch:
	kubectl get pods --watch

.PHONY: logs
logs:
	@command -v stern >/dev/null 2>&1 || { echo "stern not found. Install: brew install stern"; exit 1; }
	stern . --all-namespaces

.PHONY: events
events:
	kubectl get events --sort-by='.lastTimestamp'

# ──────────────────────────────────────────────────────────────────────────────
# PORT-FORWARD
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: open-app
open-app:
	@echo "→ Frontend at http://localhost:8080"
	kubectl port-forward svc/frontend 8080:80

.PHONY: open-grafana
open-grafana:
	@echo "→ Grafana at http://localhost:3000  (admin / admin)"
	kubectl port-forward svc/grafana 3000:3000

.PHONY: open-prometheus
open-prometheus:
	@echo "→ Prometheus at http://localhost:9090"
	kubectl port-forward svc/prometheus 9090:9090

.PHONY: open-tempo
open-tempo:
	@echo "→ Tempo at http://localhost:3200"
	kubectl port-forward svc/tempo 3200:3200

.PHONY: open-loki
open-loki:
	@echo "→ Loki at http://localhost:3100"
	kubectl port-forward svc/loki 3100:3100

.PHONY: open-all
open-all:
	@echo "→ Forwarding all observability services in background..."
	kubectl port-forward svc/frontend    8080:80   &
	kubectl port-forward svc/grafana     3000:3000 &
	kubectl port-forward svc/prometheus  9090:9090 &
	kubectl port-forward svc/tempo       3200:3200 &
	kubectl port-forward svc/loki        3100:3100 &
	@echo ""
	@echo "  App        → http://localhost:8080"
	@echo "  Grafana    → http://localhost:3000  (admin / admin)"
	@echo "  Prometheus → http://localhost:9090"
	@echo "  Tempo      → http://localhost:3200"
	@echo "  Loki       → http://localhost:3100"
	@echo ""
	@echo "  Run 'make close-all' to stop all port-forwards."

.PHONY: close-all
close-all:
	@echo "→ Stopping all port-forwards..."
	@pkill -f "kubectl port-forward" || true
	@echo "✓ Done."

# ──────────────────────────────────────────────────────────────────────────────
# TERRAFORM – AWS
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: tf-aws-init
tf-aws-init:
	terraform -chdir=$(TF_AWS_DIR) init

.PHONY: tf-aws-plan
tf-aws-plan:
	terraform -chdir=$(TF_AWS_DIR) plan -var-file=terraform.tfvars

.PHONY: tf-aws-apply
tf-aws-apply:
	terraform -chdir=$(TF_AWS_DIR) apply -var-file=terraform.tfvars

.PHONY: tf-aws-destroy
tf-aws-destroy:
	terraform -chdir=$(TF_AWS_DIR) destroy -var-file=terraform.tfvars

# ──────────────────────────────────────────────────────────────────────────────
# TERRAFORM – GCP
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: tf-gcp-init
tf-gcp-init:
	terraform -chdir=$(TF_GCP_DIR) init

.PHONY: tf-gcp-plan
tf-gcp-plan:
	terraform -chdir=$(TF_GCP_DIR) plan

.PHONY: tf-gcp-apply
tf-gcp-apply:
	terraform -chdir=$(TF_GCP_DIR) apply

.PHONY: tf-gcp-destroy
tf-gcp-destroy:
	terraform -chdir=$(TF_GCP_DIR) destroy

# ──────────────────────────────────────────────────────────────────────────────
# UTILS
# ──────────────────────────────────────────────────────────────────────────────
.PHONY: load-test
load-test:
	@echo "→ Scaling loadgenerator to 5 replicas..."
	kubectl scale deployment loadgenerator --replicas=5

.PHONY: load-stop
load-stop:
	@echo "→ Scaling loadgenerator back to 1 replica..."
	kubectl scale deployment loadgenerator --replicas=1

.PHONY: clean
clean: cluster-delete
	@echo "✓ Clean done."
