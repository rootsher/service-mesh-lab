MESH ?=
ifeq ($(filter $(MESH),linkerd istio),)
$(error choose a mesh: make <target> MESH=linkerd or MESH=istio)
endif

# One cluster per mesh, so both can run side by side.
CLUSTER := mesh-$(MESH)
CONTEXT := kind-$(CLUSTER)
KUBECTL := kubectl --context $(CONTEXT)
HELM := helm --kube-context $(CONTEXT)

GATEWAY_API_VERSION := v1.6.2
CERT_MANAGER_VERSION := v1.21.2

export KUBE_CONTEXT := $(CONTEXT)
export MESH

.PHONY: up cluster gateway-api cert-manager identity root apps test stats dashboard down

# What differs between the meshes: their install, how a namespace joins,
# where the identity issuer lives, and which Gateway API channel they need.
include $(MESH)/mesh.mk

up: cluster gateway-api cert-manager identity mesh apps

# A fresh control plane can still time out on a burst of CRDs right after
# kind returns, so the next steps wait for every node first.
cluster:
	@kind get clusters 2>/dev/null | grep -qx $(CLUSTER) || kind create cluster --name $(CLUSTER) --config kind.yaml
	$(KUBECTL) wait --for=condition=Ready nodes --all --timeout=3m

# The CRDs come from upstream rather than from a mesh chart, so their version
# is ours to choose and the same for both meshes.
gateway-api:
	$(KUBECTL) apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/$(GATEWAY_API_VERSION)/$(GATEWAY_API_CHANNEL)-install.yaml

cert-manager:
	$(HELM) upgrade --install cert-manager cert-manager \
		--repo https://charts.jetstack.io --version $(CERT_MANAGER_VERSION) \
		--namespace cert-manager --create-namespace \
		--set crds.enabled=true \
		--wait --timeout 5m

# The same root for both meshes; each one gets its own intermediate from it.
identity: issuer

root:
	$(KUBECTL) apply -f identity/mesh-root.yaml
	$(KUBECTL) -n cert-manager wait certificate/mesh-root --for=condition=Ready --timeout=2m

apps: join
	$(KUBECTL) apply -k apps/
	$(KUBECTL) -n demo rollout status deploy --timeout=3m
	$(KUBECTL) -n outside rollout status deploy --timeout=3m

# Every scenario applies its manifests, checks what the mesh does with real
# requests and removes them again. S=03-canary runs one.
test:
	@scripts/test.sh $(S)

down:
	kind delete cluster --name $(CLUSTER)
