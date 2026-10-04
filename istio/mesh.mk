ISTIO_VERSION := 1.30.5
ISTIO_REPO := https://istio-release.storage.googleapis.com/charts

# The experimental channel, because the retry field of HTTPRoute (scenario
# 06) has not left it yet. Everything else here uses standard fields only.
GATEWAY_API_CHANNEL := experimental

.PHONY: issuer mesh join

issuer: root
	$(KUBECTL) create namespace istio-system --dry-run=client -o yaml | $(KUBECTL) apply -f -
	$(KUBECTL) apply -f istio/ca.yaml
	$(KUBECTL) -n istio-system wait certificate/istio-ca --for=condition=Ready --timeout=2m

# Ambient is four charts: CRDs, istiod, the CNI node agent that hands pod
# traffic to ztunnel, and ztunnel itself. The order matters: ztunnel needs
# istiod to get certificates from. Prometheus and Kiali come as Istio ships
# them for trying things out: no persistence, no authentication.
mesh:
	$(HELM) upgrade --install istio-base base \
		--repo $(ISTIO_REPO) --version $(ISTIO_VERSION) \
		--namespace istio-system \
		--wait
	$(HELM) upgrade --install istiod istiod \
		--repo $(ISTIO_REPO) --version $(ISTIO_VERSION) \
		--namespace istio-system \
		--values istio/ambient.values.yaml \
		--wait --timeout 5m
	$(HELM) upgrade --install istio-cni cni \
		--repo $(ISTIO_REPO) --version $(ISTIO_VERSION) \
		--namespace istio-system \
		--values istio/ambient.values.yaml \
		--wait --timeout 5m
	$(HELM) upgrade --install ztunnel ztunnel \
		--repo $(ISTIO_REPO) --version $(ISTIO_VERSION) \
		--namespace istio-system \
		--wait --timeout 5m
	$(KUBECTL) apply -f https://raw.githubusercontent.com/istio/istio/$(ISTIO_VERSION)/samples/addons/prometheus.yaml
	$(KUBECTL) apply -f https://raw.githubusercontent.com/istio/istio/$(ISTIO_VERSION)/samples/addons/kiali.yaml
	$(KUBECTL) -n istio-system rollout status deploy/prometheus deploy/kiali --timeout=5m

# The waypoint has to be programmed before the workloads start sending
# traffic through it.
join:
	$(KUBECTL) apply -f istio/namespaces.yaml -f istio/waypoint.yaml
	$(KUBECTL) -n demo wait gateway/waypoint --for=condition=Programmed --timeout=3m

stats:
	@istio/stats.sh

dashboard:
	istioctl --context $(CONTEXT) dashboard kiali
