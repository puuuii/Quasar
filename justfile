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
