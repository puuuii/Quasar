#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-quasar}"
NATS_SUBJECT="${NATS_SUBJECT:-tests.demo}"
PUBLISH_INTERVAL_SECONDS="${PUBLISH_INTERVAL_SECONDS:-5}"
MESSAGE_PREFIX="${MESSAGE_PREFIX:-Hello RisingWave!}"
START_ID="${START_ID:-1}"

echo "Retrieving NATS_BOX_POD..."
NATS_BOX_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=nats-box -o jsonpath='{.items[0].metadata.name}')

echo "NATS Box Pod: $NATS_BOX_POD"
echo "Starting to publish messages every $PUBLISH_INTERVAL_SECONDS seconds. Press Ctrl+C to stop."

counter="$START_ID"
while true; do
  current_time=$(date "+%Y-%m-%d %H:%M:%S")
  message="$MESSAGE_PREFIX Message #$counter"
  payload="{\"id\": $counter, \"message\": \"$message\", \"created_at\": \"$current_time\"}"

  echo "Publishing: $payload"
  kubectl exec -i "$NATS_BOX_POD" -n "$NAMESPACE" -- nats pub "$NATS_SUBJECT" "$payload"

  counter=$((counter + 1))
  sleep "$PUBLISH_INTERVAL_SECONDS"
done
