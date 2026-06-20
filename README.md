# Quasar

## 名前の由来

クェーサーのようなデータ基盤を目指したい
- クェーサーの中心にはブラックホールがいるように、あらゆるデータが集まる場所にしたい
- クェーサーに吸い込まれる物質は渦を巻くときの摩擦でエネルギーを放出するように、あらゆるデータの組み合わせで価値を生みたい
- クェーサーが吸い込み切れなかった物質を宇宙ジェットとして噴出するように、抑えきれないデータという価値を放ちたい
- クェーサーが宇宙の測量のための灯台であるように、組織内のシングル・ソース・オブ・トゥルース（SSOT）でありたい

## クリーンアップ・リセット手順

### パターンA: クラスタごと完全に再作成する（最も確実）
```bash
kind delete cluster --name quasar
kind create cluster --name quasar
kubectl create namespace quasar
```

## NATS JetStreamの構築手順

1. (初回のみ）インストール
```bash
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm repo update
```
2. natsの起動
```bash
helm install nats nats/nats -n quasar -f charts/nats-values-dev.yaml
kubectl get pods -n quasar
```
3. nackの起動
```bash
helm install nack nats/nack -n quasar -f charts/nack-values-dev.yaml
kubectl get pods -n quasar
```
4. Stream（CRD）の適用
```bash
kubectl apply -f manifests/nats.yaml
kubectl get stream quasar-stream -n quasar
```

## SeaweedFSの構築手順

1. (初回のみ)インストール
```bash
helm repo add seaweedfs https://seaweedfs.github.io/seaweedfs/helm
helm repo update
```
2. SeaweedFSの起動
```bash
helm install seaweedfs seaweedfs/seaweedfs -n quasar -f charts/seaweedfs-values-dev.yaml
kubectl get pods -n quasar
```

## RisingWaveの構築手順

1. (初回のみ)インストール
```bash
helm repo add risingwavelabs https://risingwavelabs.github.io/helm-charts/ --force-update
helm repo update
```
2. RisingWaveの起動
```bash
helm install risingwave risingwavelabs/risingwave -n quasar -f charts/risingwave-values-dev.yaml
kubectl get pods -n quasar
```
3. バックグラウンドでポートフォワードを開始
```powershell
$job = Start-Job -ScriptBlock { kubectl port-forward svc/risingwave 4567:4567 -n quasar }
```

## nats -> risingwaveの接続確認

1. SOURCE作成
```bash
psql -h localhost -p 4567 -d dev -U root -f ./sql/create_source.sql
```
2. （動作確認）NATSへのテストメッセージの送信
```bash
kubectl exec -it (kubectl get pods -n quasar -l app.kubernetes.io/component=nats-box -o jsonpath='{.items[0].metadata.name}') -n quasar -- nats pub tests.demo '{"id": 1, "message": "Hello RisingWave!", "created_at": "2026-06-17 00:00:00"}'
```
3. （動作確認）マテリアライズド・ビューの作成
```bash
psql -h localhost -p 4567 -d dev -U root -c "CREATE MATERIALIZED VIEW mv_nats_tests AS SELECT * FROM nats_tests_source;"
```
4. （動作確認）データの問い合わせ
```bash
psql -h localhost -p 4567 -d dev -U root -c "SELECT * FROM mv_nats_tests LIMIT 10;"
```
