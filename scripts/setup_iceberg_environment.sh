#!/usr/bin/env bash
set -euo pipefail

CATALOG_MANAGEMENT_URL="${CATALOG_MANAGEMENT_URL:-http://localhost:8181}"
CATALOG_URL="${CATALOG_URL:-http://localhost:8181/catalog}"
WAREHOUSE="${WAREHOUSE:-demo}"
ICEBERG_NAMESPACE="${ICEBERG_NAMESPACE:-demo_db}"
S3_SERVICE_ENDPOINT="${S3_SERVICE_ENDPOINT:-http://seaweedfs-s3.quasar.svc.cluster.local:8333}"
S3_REGION="${S3_REGION:-us-east-1}"
S3_ACCESS_KEY="${S3_ACCESS_KEY:-seaweedfs_rw_access}"
S3_SECRET_KEY="${S3_SECRET_KEY:-seaweedfs_rw_secret}"

echo "=== 0. Bootstrapping Lakekeeper ==="
BOOTSTRAP_RESP=$(curl -s -w "\n%{http_code}" -X POST "$CATALOG_MANAGEMENT_URL/management/v1/bootstrap" \
  -H "Content-Type: application/json" \
  -d '{"accept-terms-of-use": true}')

BOOTSTRAP_STATUS=$(echo "$BOOTSTRAP_RESP" | tail -n1)
BOOTSTRAP_BODY=$(echo "$BOOTSTRAP_RESP" | sed '$d')

if [ "$BOOTSTRAP_STATUS" -eq 200 ] || [ "$BOOTSTRAP_STATUS" -eq 204 ]; then
  echo "Lakekeeper bootstrapped successfully."
elif echo "$BOOTSTRAP_BODY" | grep -q "CatalogAlreadyBootstrapped"; then
  echo "Lakekeeper is already bootstrapped."
else
  echo "Failed to bootstrap Lakekeeper (Status: $BOOTSTRAP_STATUS):"
  echo "$BOOTSTRAP_BODY"
  exit 1
fi
echo ""

echo "=== 1. Creating/Retrieving Warehouse '$WAREHOUSE' in Lakekeeper ==="
WAREHOUSE_ID=$(curl -s "$CATALOG_MANAGEMENT_URL/management/v1/warehouse" | WAREHOUSE="$WAREHOUSE" python3 -c "import os, sys, json; target = os.environ['WAREHOUSE']; data = json.load(sys.stdin); print(next((w.get('id') or w.get('warehouse-id') for w in data.get('warehouses', []) if w.get('name') == target), ''))")

if [ -n "$WAREHOUSE_ID" ]; then
  echo "Warehouse '$WAREHOUSE' already exists (ID: $WAREHOUSE_ID)."
else
  echo "Creating Warehouse '$WAREHOUSE'..."
  CREATE_RESP=$(curl -s -w "\n%{http_code}" -X POST "$CATALOG_MANAGEMENT_URL/management/v1/warehouse" \
    -H "Content-Type: application/json" \
    -d "{
      \"warehouse-name\": \"$WAREHOUSE\",
      \"storage-profile\": {
        \"type\": \"s3\",
        \"bucket\": \"iceberg-bucket\",
        \"region\": \"$S3_REGION\",
        \"endpoint\": \"$S3_SERVICE_ENDPOINT\",
        \"path-style-access\": true,
        \"flavor\": \"s3-compat\",
        \"sts-enabled\": false
      },
      \"storage-credential\": {
        \"type\": \"s3\",
        \"credential-type\": \"access-key\",
        \"aws-access-key-id\": \"$S3_ACCESS_KEY\",
        \"aws-secret-access-key\": \"$S3_SECRET_KEY\"
      }
    }")
  CREATE_STATUS=$(echo "$CREATE_RESP" | tail -n1)
  CREATE_BODY=$(echo "$CREATE_RESP" | sed '$d')

  if [ "$CREATE_STATUS" -eq 200 ] || [ "$CREATE_STATUS" -eq 201 ]; then
    WAREHOUSE_ID=$(echo "$CREATE_BODY" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('id') or data.get('warehouse-id') or '')")
    if [ -z "$WAREHOUSE_ID" ]; then
      echo "Failed to parse Warehouse ID from creation response: $CREATE_BODY"
      exit 1
    fi
    echo "Warehouse '$WAREHOUSE' created successfully (ID: $WAREHOUSE_ID)."
  else
    echo "Failed to create warehouse (Status: $CREATE_STATUS):"
    echo "$CREATE_BODY"
    exit 1
  fi
fi
echo ""

echo "=== 2. Creating Namespace '$ICEBERG_NAMESPACE' in '$WAREHOUSE' Warehouse ==="
NS_EXISTS=$(curl -s "$CATALOG_URL/v1/$WAREHOUSE_ID/namespaces" | ICEBERG_NAMESPACE="$ICEBERG_NAMESPACE" python3 -c "import os, sys, json; target = os.environ['ICEBERG_NAMESPACE']; data = json.load(sys.stdin); print('true' if any(target in ns for ns in data.get('namespaces', [])) else 'false')")

if [ "$NS_EXISTS" = "true" ]; then
  echo "Namespace '$ICEBERG_NAMESPACE' already exists in Warehouse '$WAREHOUSE'."
else
  echo "Creating Namespace '$ICEBERG_NAMESPACE'..."
  NS_RESP=$(curl -s -w "\n%{http_code}" -X POST "$CATALOG_URL/v1/$WAREHOUSE_ID/namespaces" \
    -H "Content-Type: application/json" \
    -d "{\"namespace\": [\"$ICEBERG_NAMESPACE\"]}")
  NS_STATUS=$(echo "$NS_RESP" | tail -n1)
  NS_BODY=$(echo "$NS_RESP" | sed '$d')

  if [ "$NS_STATUS" -eq 200 ] || [ "$NS_STATUS" -eq 201 ]; then
    echo "Namespace '$ICEBERG_NAMESPACE' created successfully."
  else
    echo "Failed to create namespace (Status: $NS_STATUS):"
    echo "$NS_BODY"
    exit 1
  fi
fi
echo ""
