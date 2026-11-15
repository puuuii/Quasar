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
    - ストレージ
      - SeaweedFS
    - カタログ
      - SeaweedFS 組み込みカタログ
- BI層
  - [Rill](https://github.com/rilldata/rill)

## インフラストラクチャ

Kubernetesで動作する
