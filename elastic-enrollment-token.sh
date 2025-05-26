#!/bin/bash

set -e

POD_NAME=$(kubectl get pod -n default -l app=elasticsearch -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [[ -z "$POD_NAME" ]]; then
  echo "{\"result\": \"ERROR: Elasticsearch pod not found\"}"
  exit 0
fi

TOKEN=$(kubectl exec -n default "$POD_NAME" -- bin/elasticsearch-create-enrollment-token -s kibana 2>/dev/null | tr -d '\r\n')

echo "{\"result\": \"$TOKEN\"}"
