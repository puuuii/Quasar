# Quasar

## 名前の由来

クェーサーのようなデータ基盤を目指したい
- クェーサーの中心にはブラックホールがいるように、あらゆるデータが集まる場所にしたい
- クェーサーに吸い込まれる物質は渦を巻くときの摩擦でエネルギーを放出するように、あらゆるデータの組み合わせで価値を生みたい
- クェーサーが吸い込み切れなかった物質を宇宙ジェットとして噴出するように、抑えきれないデータという価値を放ちたい
- クェーサーが宇宙の測量のための灯台であるように、組織内のシングル・ソース・オブ・トゥルース（SSOT）でありたい

## クリーンアップ・リセット

```bash
just recreate-cluster
```

## NATS JetStreamの構築

```bash
just setup-nats
```

## SeaweedFSの構築

```bash
just setup-seaweedfs
```

## RisingWaveの構築手順

```bash
just setup-risingwave
```

## nats -> risingwaveの接続確認

```bash
test-connection-nats-to-risingwave
```

## Iceberg Rest Catalog構築手順

1. 構築
```bash
kubectl apply -n quasar  -f ./manifests/iceberg-dev.yaml 
```
