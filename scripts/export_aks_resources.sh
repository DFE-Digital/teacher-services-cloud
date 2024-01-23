#!/usr/bin/env bash

# Requires
# jq: https://stedolan.github.io/jq/
# kubectl-neat: https://github.com/itaysk/kubectl-neat
set -eu
set -o pipefail

NAMESPACE_BLACKLIST="default kube-node-lease kube-public kube-system gatekeeper-system"

echo "Fetching custom namespaces..."
all_namespaces=$(kubectl get namespaces -o name)
echo

for namespace0 in $all_namespaces; do
    namespace=${namespace0#namespace/}
    if (echo "$NAMESPACE_BLACKLIST" | grep -q "$namespace"); then
        continue
    fi

    echo "Exporting $namespace namespace..."
    # Export resources from namespace, remove default kube-root-ca.crt config map, remove inernal information
    kubectl -n "$namespace" get deploy,svc,configmap,secret,ingress,pdb -o json \
        | jq 'del(.items[]|select(.metadata.name == "kube-root-ca.crt"))' \
        | kubectl neat \
        > "$namespace.json"

    number_of_items=$(jq '.items | length' "$namespace.json")
    [[ $number_of_items = "0" ]] \
        && echo Namespace is empty, ignoring \
        && rm "$namespace.json"

    echo
done
