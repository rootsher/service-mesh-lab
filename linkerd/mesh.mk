LINKERD_VERSION := 2026.9.3
LINKERD_REPO := https://helm.linkerd.io/edge

# Linkerd reads HTTPRoute for traffic splitting and timeouts, and takes
# retries from annotations, so the standard channel is enough.
GATEWAY_API_CHANNEL := standard

.PHONY: issuer mesh join

issuer: root
	$(KUBECTL) create namespace linkerd --dry-run=client -o yaml | $(KUBECTL) apply -f -
	$(KUBECTL) apply -f linkerd/identity-issuer.yaml
	$(KUBECTL) -n linkerd wait certificate/linkerd-identity-issuer --for=condition=Ready --timeout=2m

# The trust anchor is the public half of mesh-root. Every proxy validates its
# peers against it, so it is read from the cluster rather than kept in git.
mesh:
	$(HELM) upgrade --install linkerd-crds linkerd-crds \
		--repo $(LINKERD_REPO) --version $(LINKERD_VERSION) \
		--namespace linkerd \
		--wait
	$(HELM) upgrade --install linkerd-cni linkerd2-cni \
		--repo $(LINKERD_REPO) --version $(LINKERD_VERSION) \
		--namespace linkerd-cni --create-namespace \
		--wait
	$(KUBECTL) -n cert-manager get secret mesh-root -o jsonpath='{.data.ca\.crt}' | base64 -d > .trust-anchor.crt
	$(HELM) upgrade --install linkerd-control-plane linkerd-control-plane \
		--repo $(LINKERD_REPO) --version $(LINKERD_VERSION) \
		--namespace linkerd \
		--values linkerd/control-plane.values.yaml \
		--set-file identityTrustAnchorsPEM=.trust-anchor.crt \
		--wait --timeout 5m
	@rm -f .trust-anchor.crt
	$(HELM) upgrade --install linkerd-viz linkerd-viz \
		--repo $(LINKERD_REPO) --version $(LINKERD_VERSION) \
		--namespace linkerd-viz --create-namespace \
		--wait --timeout 5m

join:
	$(KUBECTL) apply -f linkerd/namespaces.yaml

stats:
	@linkerd --context $(CONTEXT) viz stat deploy -n demo
	@linkerd --context $(CONTEXT) viz edges deploy -n demo

dashboard:
	linkerd --context $(CONTEXT) viz dashboard
