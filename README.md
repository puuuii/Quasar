# Quasar

## 名前の由来

クェーサーのようなデータ基盤を目指したい
- クェーサーの中心にはブラックホールがいるように、あらゆるデータが集まる場所にしたい
- クェーサーに吸い込まれる物質は渦を巻くときの摩擦でエネルギーを放出するように、あらゆるデータの組み合わせで価値を生みたい
- クェーサーが吸い込み切れなかった物質を宇宙ジェットとして噴出するように、抑えきれないデータという価値を放ちたい
- クェーサーが宇宙の測量のための灯台であるように、組織内のシングル・ソース・オブ・トゥルース（SSOT）でありたい

## 設定確認

```bash
just show-config
```

## クリーンアップ・リセット

```bash
just recreate-cluster
```

## コア基盤をまとめて構築

```bash
just core-up
```

個別に実行する場合:

```bash
just setup-nats
just setup-seaweedfs
just setup-risingwave
```

## Iceberg 系をまとめて構築

```bash
just iceberg-up
```

全体をまとめて上げる場合:

```bash
just platform-up
```

個別に実行する場合:

1. 構築
```bash
just setup-iceberg
```

2. REST Catalogをローカルに公開
```bash
just port-forward-iceberg
```

3. SeaweedFS S3をローカルに公開
```bash
just port-forward-seaweedfs-s3
```

4. Warehouse / Namespace を初期化
```bash
just setup-iceberg-environment
```

5. RisingWave Source / Iceberg Sink を作成
```bash
just setup-risingwave-source
just setup-iceberg-pipeline
```

## nats -> risingwave の疎通確認

```bash
just test-connection-nats-to-risingwave
```

## NATS に1件だけ流し込む

```bash
just ingest-once "hello from quasar"
```

## NATS に継続投入する

```bash
just publish-nats
```

## DuckDB で Iceberg テーブルを確認

ポートフォワード込みで実行する場合:

```bash
just query-iceberg-ready 20
```

すでに公開済みなら、件数だけ指定できます:

```bash
just query-iceberg 20
```

対象も変えたい場合は custom recipe を使います:

```bash
just query-iceberg-custom demo_db demo_table demo 20
just publish-nats-custom tests.demo 5 "Hello RisingWave!" 1
just ingest-once-custom 42 tests.demo "hello from quasar" "2026-07-01 00:00:00"
```
