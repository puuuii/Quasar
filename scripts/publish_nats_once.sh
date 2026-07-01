#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-quasar}"
NATS_SUBJECT="${NATS_SUBJECT:-tests.demo}"
MESSAGE_ID="${MESSAGE_ID:-1}"
MESSAGE_BODY="${MESSAGE_BODY:-Hello RisingWave!}"
CREATED_AT="${CREATED_AT:-$(date "+%Y-%m-%d %H:%M:%S")}"

echo "Retrieving NATS_BOX_POD..."
NATS_BOX_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=nats-box -o jsonpath='{.items[0].metadata.name}')

payload="{\"id\": $MESSAGE_ID, \"message\": \"$MESSAGE_BODY\", \"created_at\": \"$CREATED_AT\"}"

echo "Publishing once: $payload"
kubectl exec -i "$NATS_BOX_POD" -n "$NAMESPACE" -- nats pub "$NATS_SUBJECT" "$payload"
