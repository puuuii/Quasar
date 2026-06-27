recreate-cluster:
    kind delete cluster --name quasar
    kind create cluster --name quasar
    kubectl create namespace quasar

setup-nats:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "=== Adding Helm repository ==="
    helm repo add nats https://nats-io.github.io/k8s/helm/charts/ --force-update
    helm repo update

    # 1. helmの --wait を使ってPodが立ち上がるまで待つ
    echo "=== Installing NATS ==="
    helm install nats nats/nats -n quasar -f charts/nats-values-dev.yaml --create-namespace --wait --timeout 2m

    # 2. nackも同様に --wait で待つ
    echo "=== Installing NACK ==="
    helm install nack nats/nack -n quasar -f charts/nack-values-dev.yaml --wait --timeout 2m

    # 3. Streamの適用
    echo "=== Applying Stream CRD ==="
    kubectl apply -f manifests/nats.yaml

    # Streamが実際にコントローラー（NACK）に認識されて準備完了になるのを待つ
    echo "Waiting for Stream to be ready..."
    kubectl wait -n quasar --for=condition=Ready stream/quasar-stream --timeout=60s

    # 最後にまとめて動作確認
    echo "=== Final Status Check ==="
    kubectl get pods -n quasar
    echo ""
    kubectl get stream quasar-stream -n quasar

setup-seaweedfs:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "=== Adding SeaweedFS Helm repository ==="
    helm repo add seaweedfs https://seaweedfs.github.io/seaweedfs/helm --force-update
    helm repo update

    echo "=== Installing SeaweedFS ==="
    # --wait で全てのコンポーネント（Master, Volume, Filer等）がReadyになるのを待つ
    helm install seaweedfs seaweedfs/seaweedfs -n quasar -f charts/seaweedfs-values-dev.yaml

    # 最後にまとめて動作確認
    echo "=== Final Status Check ==="
    kubectl get pods -n quasar

# RisingWaveの一括構築と動作確認
setup-risingwave:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "=== Adding RisingWave Helm repository ==="
    helm repo add risingwavelabs https://risingwavelabs.github.io/helm-charts/ --force-update
    helm repo update

    echo "=== Installing RisingWave ==="
    # --wait を指定し、RisingWaveの全コンポーネント（Meta, Frontend, Compactor, Compute等）がReadyになるのを待つ
    # RisingWaveは起動するコンポーネントが多いため、タイムアウトを少し長めの 5m に設定しています
    helm install risingwave risingwavelabs/risingwave -n quasar -f charts/risingwave-values-dev.yaml --create-namespace --wait --timeout 5m

    echo "=== Starting Port-Forward in background ==="
    # frontendサービス（デフォルトポート 4567）をバックグラウンドでポートフォワード
    # ログは /tmp/risingwave-pf.log に逃がしています
    kubectl port-forward -n quasar svc/risingwave 4567:4567 &>/dev/null &


    # ポートフォワードが立ち上がるのを少しだけ待つ
    sleep 2

    # 最後にまとめて動作確認
    echo "=== Final Status Check ==="
    echo "--- Pods in quasar namespace ---"
    kubectl get pods -n quasar
    echo ""
    echo "--- Port-Forwarding Process ---"
    ps aux | grep "kubectl port-forward" | grep -v grep

# NATSからRisingWaveへのデータ疎通確認
test-connection-nats-to-risingwave:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "=== 1. Creating RisingWave SOURCE ==="
    psql -h localhost -p 4567 -d dev -U root -f ./sql/create_source.sql

    echo "=== 2. Publishing test message to NATS ==="
    # nats-box の Pod 名を動的に取得
    NATS_BOX_POD=$(kubectl get pods -n quasar -l app.kubernetes.io/component=nats-box -o jsonpath='{.items[0].metadata.name}')

    # テストメッセージの送信
    kubectl exec -i "$NATS_BOX_POD" -n quasar -- nats pub tests.demo '{"id": 1, "message": "Hello RisingWave!", "created_at": "2026-06-17 00:00:00"}'

    # メッセージがRisingWave側に届き、処理されるのを少しだけ待つ
    sleep 3

    echo "=== 3. Creating Materialized View ==="
    psql -h localhost -p 4567 -d dev -U root -c "CREATE MATERIALIZED VIEW mv_nats_tests AS SELECT * FROM nats_tests_source;"

    # MVが作成されて反映されるのを少しだけ待つ
    sleep 2

    echo "=== 4. Querying Data from Materialized View ==="
    psql -h localhost -p 4567 -d dev -U root -c "SELECT * FROM mv_nats_tests LIMIT 10;"

setup-iceberg:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Deploying Iceberg Catalog ==="
    kubectl apply -n quasar -f ./manifests/iceberg-dev.yaml

    echo "=== Waiting for iceberg-catalog-db Pod ==="
    kubectl wait -n quasar --for=condition=Ready pod -l app=iceberg-catalog-db --timeout=2m

    echo "=== Waiting for iceberg-rest-catalog Pod ==="
    kubectl wait -n quasar --for=condition=Ready pod -l app=iceberg-rest-catalog --timeout=2m

# REST Catalogのポートフォワードをバックグラウンドで開始
port-forward-iceberg:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Starting Port-Forward for Iceberg REST Catalog (8181:8181) ==="
    kubectl port-forward -n quasar svc/iceberg-rest-catalog 8181:8181 &>/dev/null &
    sleep 2
    ps aux | grep "kubectl port-forward" | grep "8181:8181" | grep -v grep

# Lakekeeperの初期設定 (Warehouse & Namespace作成)
setup-iceberg-environment:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "=== 0. Bootstrapping Lakekeeper ==="
    BOOTSTRAP_RESP=$(curl -s -w "\n%{http_code}" -X POST http://localhost:8181/management/v1/bootstrap \
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

    echo "=== 1. Creating/Retrieving Warehouse 'demo' in Lakekeeper ==="
    # 既存のウェアハウスをチェック
    WAREHOUSE_ID=$(curl -s http://localhost:8181/management/v1/warehouse | python3 -c "import sys, json; data = json.load(sys.stdin); print(next((w.get('id') or w.get('warehouse-id') for w in data.get('warehouses', []) if w.get('name') == 'demo'), ''))")

    if [ -n "$WAREHOUSE_ID" ]; then
      echo "Warehouse 'demo' already exists (ID: $WAREHOUSE_ID)."
    else
      echo "Creating Warehouse 'demo'..."
      CREATE_RESP=$(curl -s -w "\n%{http_code}" -X POST http://localhost:8181/management/v1/warehouse \
        -H "Content-Type: application/json" \
        -d '{
          "warehouse-name": "demo",
          "storage-profile": {
            "type": "s3",
            "bucket": "iceberg-bucket",
            "region": "us-east-1",
            "endpoint": "http://seaweedfs-s3.quasar.svc.cluster.local:8333",
            "path-style-access": true,
            "flavor": "s3-compat",
            "sts-enabled": false
          },
          "storage-credential": {
            "type": "s3",
            "credential-type": "access-key",
            "aws-access-key-id": "seaweedfs_rw_access",
            "aws-secret-access-key": "seaweedfs_rw_secret"
          }
        }')
      CREATE_STATUS=$(echo "$CREATE_RESP" | tail -n1)
      CREATE_BODY=$(echo "$CREATE_RESP" | sed '$d')

      if [ "$CREATE_STATUS" -eq 200 ] || [ "$CREATE_STATUS" -eq 201 ]; then
        WAREHOUSE_ID=$(echo "$CREATE_BODY" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('id') or data.get('warehouse-id') or '')")
        if [ -z "$WAREHOUSE_ID" ]; then
          echo "Failed to parse Warehouse ID from creation response: $CREATE_BODY"
          exit 1
        fi
        echo "Warehouse 'demo' created successfully (ID: $WAREHOUSE_ID)."
      else
        echo "Failed to create warehouse (Status: $CREATE_STATUS):"
        echo "$CREATE_BODY"
        exit 1
      fi
    fi
    echo ""

    echo "=== 2. Creating Namespace 'demo_db' in 'demo' Warehouse ==="
    # すでにNamespaceが存在するかチェック
    NS_EXISTS=$(curl -s "http://localhost:8181/catalog/v1/$WAREHOUSE_ID/namespaces" | python3 -c "import sys, json; data = json.load(sys.stdin); print('true' if any('demo_db' in ns for ns in data.get('namespaces', [])) else 'false')")

    if [ "$NS_EXISTS" = "true" ]; then
      echo "Namespace 'demo_db' already exists in Warehouse 'demo'."
    else
      echo "Creating Namespace 'demo_db'..."
      NS_RESP=$(curl -s -w "\n%{http_code}" -X POST "http://localhost:8181/catalog/v1/$WAREHOUSE_ID/namespaces" \
        -H "Content-Type: application/json" \
        -d '{"namespace": ["demo_db"]}')
      NS_STATUS=$(echo "$NS_RESP" | tail -n1)
      NS_BODY=$(echo "$NS_RESP" | sed '$d')

      if [ "$NS_STATUS" -eq 200 ] || [ "$NS_STATUS" -eq 201 ]; then
        echo "Namespace 'demo_db' created successfully."
      else
        echo "Failed to create namespace (Status: $NS_STATUS):"
        echo "$NS_BODY"
        exit 1
      fi
    fi
    echo ""

# RisingWaveにIceberg SinkとSourceを作成
setup-iceberg-pipeline:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Creating RisingWave Iceberg Sink ==="
    psql -h localhost -p 4567 -d dev -U root -f ./sql/create_iceberg_sink.sql

    echo "=== Creating RisingWave Iceberg Source ==="
    psql -h localhost -p 4567 -d dev -U root -f ./sql/create_iceberg_source.sql

# NATSへのメッセージ送信ループ起動
publish-nats:
    chmod +x ./scripts/publish_nats.sh
    ./scripts/publish_nats.sh

# Icebergからデータ参照確認
query-iceberg:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Querying Data from Iceberg Source ==="
    psql -h localhost -p 4567 -d dev -U root -c "SELECT * FROM iceberg_demo_source LIMIT 10;"
