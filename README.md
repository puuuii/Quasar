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
just test-connection-nats-to-risingwave
```

## Iceberg Rest Catalog構築手順

1. 構築
```bash
just setup-iceberg
```

2. REST Catalogをローカルに公開
```bash
just port-forward-iceberg
```

3. Warehouse / Namespace を初期化
```bash
just setup-iceberg-environment
```

4. RisingWave から Iceberg Sink を作成
```bash
just setup-iceberg-pipeline
```

5. NATS にデータを流し込む
```bash
just publish-nats
```

6. Iceberg テーブルを直接確認
```bash
just query-iceberg
```
