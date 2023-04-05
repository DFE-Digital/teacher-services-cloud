#!/usr/bin/env bash

set -eu

for namespace_resource_file in *.json
do
    namespace=${namespace_resource_file%.json}

    echo "Importing resources into $namespace namespace..."
    kubectl apply -f "$namespace_resource_file"
done
