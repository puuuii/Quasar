## システムの目的

俺の考える最強のデータプラットフォームを構築する

## 構成

- 取り込み層
  - NATS JetStream
- ストリーミング層
  - RisingWave
    - ストレージ
      - SeaweedFS
- バッチ層
  - RisingWave（バッチクエリ）
  - dbt（バッチ変換）
  - Iceberg（テーブルフォーマット）
    - カタログ
      - iceberg-catalog（Rust + PostgreSQL）
    - ストレージ
      - SeaweedFS
- BI層
  - Evidence

## インフラストラクチャ

Kubernetesで動作する
