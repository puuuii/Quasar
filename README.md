# Quasar

## 名前の由来

クェーサーのようなデータ基盤を目指したい
- クェーサーの中心にはブラックホールがいるように、あらゆるデータが集まる場所にしたい
- クェーサーに吸い込まれる物質は渦を巻くときの摩擦でエネルギーを放出するように、あらゆるデータの組み合わせで価値を生みたい
- クェーサーが吸い込み切れなかった物質を宇宙ジェットとして噴出するように、抑えきれないデータという価値を放ちたい
- クェーサーが宇宙の測量のための灯台であるように、組織内のシングル・ソース・オブ・トゥルース（SSOT）でありたい

## k8sクラスタ&namespace作成

1. kind create cluster --name quasar
2. （動作確認）kubectl get nodes
3. kubectl create namespace quasar
4. （動作確認）kubectl get ns

## NATS JetStreamの構築手順

1. (初回のみ）インストール
  1. helm repo add nats https://nats-io.github.io/k8s/helm/charts/
  2. helm repo update
2. natsの起動
  1. helm install nats nats/nats --namespace quasar -f charts/nats-values-dev.yaml
  2. （動作確認）kubectl get pods -n quasar -w
3. nackの起動
  1. helm install nack nats/nack　--namespace quasar　-f charts/nack-values-dev.yaml
  2. （動作確認）kubectl get pods -n quasar
4. Stream（CRD）の適用
  1. kubectl apply -f manifests/nats.yaml
  2. （動作確認）kubectl get stream quasar-stream -n quasar

## RisingWaveの構築手順

1. (初回のみ)インストール
  1. helm repo add risingwavelabs https://risingwavelabs.github.io/helm-charts/ --force-update
  2. helm repo update
2. RisingWaveの起動
  1. helm install risingwave risingwavelabs/risingwave --namespace quasar -f https://raw.githubusercontent.com/risingwavelabs/helm-charts/main/examples/dev/dev.values.yaml
  2. （動作確認）kubectl get pods -l app.kubernetes.io/instance=risingwave
3. バックグラウンドでポートフォワードを開始
  1. $job = Start-Job -ScriptBlock { kubectl port-forward svc/risingwave 4567:4567 -n quasar }

## nats -> risingwaveの接続確認

1. SOURCE作成
  1. psql -h localhost -p 4567 -d dev -U root -f ./sql/create_source.sql
  2. （動作確認）kubectl exec -it (kubectl get pods -n quasar -l app.kubernetes.io/component=nats-box -o jsonpath='{.items[0].metadata.name}') -n quasar -- nats pub tests.demo '{"id": 1, "message": "Hello RisingWave!", "created_at": "2026-06-17 00:00:00"}'
  3. （動作確認）psql -h localhost -p 4567 -d dev -U root -c "CREATE MATERIALIZED VIEW mv_nats_tests AS SELECT * FROM nats_tests_source;"
  4. （動作確認）psql -h localhost -p 4567 -d dev -U root -c "SELECT * FROM mv_nats_tests;"
