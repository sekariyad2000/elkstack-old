#!/bin/bash

set -e

POD_NAME=$(kubectl get pod -n default -l app=elasticsearch -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [[ -z "$POD_NAME" ]]; then
  echo "{\"result\": \"ERROR: Elasticsearch pod not found\"}"
  exit 0
fi

RAW_OUTPUT=$(kubectl exec -n default "$POD_NAME" -- bin/elasticsearch-reset-password -u elastic -b 2>&1)

# Als er een fout is zoals "already has a password", vangen we dat op
if echo "$RAW_OUTPUT" | grep -qi "already"; then
  echo "{\"result\": \"PASSWORD_ALREADY_SET\"}"
  exit 0
fi

PASSWORD=$(echo "$RAW_OUTPUT" | grep "New value" | awk '{print $NF}' | tr -d '\r\n')

if [[ -z "$PASSWORD" ]]; then
  echo "{\"result\": \"ERROR: Password not found in output\"}"
  exit 0
fi

echo "{\"result\": \"$PASSWORD\"}"
