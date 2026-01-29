#!/usr/bin/env bash
set -euo pipefail

kubectl wait --for=condition=Established crd/gateways.networking.istio.io --timeout=600s
kubectl wait --for=condition=Established crd/virtualservices.networking.istio.io --timeout=600s
kubectl wait --for=condition=Established crd/authorizationpolicies.security.istio.io --timeout=600s
