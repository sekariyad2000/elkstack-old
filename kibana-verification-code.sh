#!/bin/bash

set -e

POD_NAME=$(kubectl get pod -n default -l app=kibana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [[ -z "$POD_NAME" ]]; then
  echo "{\"result\": \"ERROR: Kibana pod not found\"}"
  exit 0
fi

# Voer de command uit en filter alleen de verificatiecode
RAW_OUTPUT=$(kubectl exec -n default "$POD_NAME" -- bin/kibana-verification-code 2>/dev/null)

# Zoek het laatste stuk van de output met grep + awk of sed
CODE=$(echo "$RAW_OUTPUT" | grep -oE "[0-9]{3} [0-9]{3}" | head -n 1)

echo "{\"result\": \"$CODE\"}"
