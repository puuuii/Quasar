#!/usr/bin/env bash
set -euo pipefail

# nats-box の Pod 名を動的に取得
echo "Retrieving NATS_BOX_POD..."
NATS_BOX_POD=$(kubectl get pods -n quasar -l app.kubernetes.io/component=nats-box -o jsonpath='{.items[0].metadata.name}')

echo "NATS Box Pod: $NATS_BOX_POD"
echo "Starting to publish messages every 5 seconds. Press Ctrl+C to stop."

counter=1
while true; do
  # 現在の時刻を "YYYY-MM-DD HH:MM:SS" フォーマットで取得
  current_time=$(date "+%Y-%m-%d %H:%M:%S")
  
  message="Hello RisingWave! Message #$counter"
  
  # JSONメッセージの組み立て
  payload="{\"id\": $counter, \"message\": \"$message\", \"created_at\": \"$current_time\"}"

  echo "Publishing: $payload"
  
  # NATSへパブリッシュ
  kubectl exec -i "$NATS_BOX_POD" -n quasar -- nats pub tests.demo "$payload"
  
  counter=$((counter + 1))
  sleep 5
done
