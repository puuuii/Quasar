#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-quasar}"
CATALOG_URL="${CATALOG_URL:-http://localhost:8181}"
TABLE_BUCKET="${TABLE_BUCKET:-iceberg-bucket}"
ICEBERG_NAMESPACE="${ICEBERG_NAMESPACE:-demo_db}"
S3_REGION="${S3_REGION:-us-east-1}"
S3_ACCESS_KEY="${S3_ACCESS_KEY:-seaweedfs_rw_access}"
S3_SECRET_KEY="${S3_SECRET_KEY:-seaweedfs_rw_secret}"

echo "=== 1. Creating Table Bucket '$TABLE_BUCKET' in SeaweedFS ==="
MASTER_POD=$(kubectl get pods -n "$NAMESPACE" \
  -l app.kubernetes.io/name=seaweedfs,app.kubernetes.io/component=master \
  -o jsonpath='{.items[0].metadata.name}')

run_weed_shell() {
  echo "$1" | kubectl exec -i -n "$NAMESPACE" "$MASTER_POD" -- weed shell -master=localhost:9333
}

EXISTING_BUCKETS=$(run_weed_shell "s3tables.bucket -list" 2>&1 || true)
if grep -qw -- "$TABLE_BUCKET" <<<"$EXISTING_BUCKETS"; then
  echo "Table Bucket '$TABLE_BUCKET' already exists."
else
  run_weed_shell "s3tables.bucket -create -name $TABLE_BUCKET -account 000000000000"
  echo "Table Bucket '$TABLE_BUCKET' created."
fi
echo ""

echo "=== 2. Creating Namespace '$ICEBERG_NAMESPACE' via Iceberg REST Catalog ==="
RESP_FILE=$(mktemp)
trap 'rm -f "$RESP_FILE"' EXIT

STATUS="000"
for attempt in 1 2 3 4 5; do
  STATUS=$(curl -s -o "$RESP_FILE" -w "%{http_code}" -X POST "$CATALOG_URL/v1/$TABLE_BUCKET/namespaces" \
    --aws-sigv4 "aws:amz:$S3_REGION:s3" \
    --user "$S3_ACCESS_KEY:$S3_SECRET_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"namespace\": [\"$ICEBERG_NAMESPACE\"]}" || true)
  [ "$STATUS" != "000" ] && break
  echo "Catalog not reachable yet (attempt $attempt/5), retrying..."
  sleep 3
done

case "$STATUS" in
  200|201)
    echo "Namespace '$ICEBERG_NAMESPACE' created successfully."
    ;;
  409)
    echo "Namespace '$ICEBERG_NAMESPACE' already exists."
    ;;
  *)
    echo "Failed to create namespace (Status: $STATUS):"
    cat "$RESP_FILE"
    echo ""
    exit 1
    ;;
esac
echo ""
