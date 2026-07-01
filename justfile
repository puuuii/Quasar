set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

cluster_name := "quasar"
namespace := "quasar"

risingwave_host := "localhost"
risingwave_port := "4567"
risingwave_db := "dev"
risingwave_user := "root"

catalog_management_url := "http://127.0.0.1:8181"
catalog_url := "http://127.0.0.1:8181/catalog"
s3_endpoint := "http://127.0.0.1:8333"
s3_service_endpoint := "http://seaweedfs-s3.quasar.svc.cluster.local:8333"
s3_region := "us-east-1"
s3_access_key := "seaweedfs_rw_access"
s3_secret_key := "seaweedfs_rw_secret"

warehouse := "demo"
iceberg_namespace := "demo_db"
iceberg_table := "demo_table"

nats_subject := "tests.demo"
nats_message_prefix := "Hello RisingWave!"
nats_interval_seconds := "5"
default_limit := "10"

default:
    @just --list

show-config:
    @echo "cluster_name={{cluster_name}}"
    @echo "namespace={{namespace}}"
    @echo "risingwave={{risingwave_user}}@{{risingwave_host}}:{{risingwave_port}}/{{risingwave_db}}"
    @echo "catalog_url={{catalog_url}}"
    @echo "s3_endpoint={{s3_endpoint}}"
    @echo "warehouse={{warehouse}}"
    @echo "iceberg_table={{iceberg_namespace}}.{{iceberg_table}}"
    @echo "nats_subject={{nats_subject}}"

recreate-cluster:
    kind delete cluster --name {{cluster_name}}
    kind create cluster --name {{cluster_name}}
    kubectl create namespace {{namespace}}

setup-nats:
    helm repo add nats https://nats-io.github.io/k8s/helm/charts/ --force-update
    helm repo update
    helm install nats nats/nats -n {{namespace}} -f charts/nats-values-dev.yaml --create-namespace --wait --timeout 2m
    helm install nack nats/nack -n {{namespace}} -f charts/nack-values-dev.yaml --wait --timeout 2m
    kubectl apply -f manifests/nats.yaml
    kubectl wait -n {{namespace}} --for=condition=Ready stream/quasar-stream --timeout=60s
    kubectl get pods -n {{namespace}}
    kubectl get stream quasar-stream -n {{namespace}}

setup-seaweedfs:
    helm repo add seaweedfs https://seaweedfs.github.io/seaweedfs/helm --force-update
    helm repo update
    helm install seaweedfs seaweedfs/seaweedfs -n {{namespace}} -f charts/seaweedfs-values-dev.yaml
    kubectl get pods -n {{namespace}}

setup-risingwave:
    helm repo add risingwavelabs https://risingwavelabs.github.io/helm-charts/ --force-update
    helm repo update
    helm install risingwave risingwavelabs/risingwave -n {{namespace}} -f charts/risingwave-values-dev.yaml --create-namespace --wait --timeout 5m
    kubectl port-forward -n {{namespace}} svc/risingwave 4567:4567 &>/dev/null &
    sleep 2
    kubectl get pods -n {{namespace}}
    ps aux | grep "kubectl port-forward" | grep -v grep

setup-risingwave-source:
    psql -h {{risingwave_host}} -p {{risingwave_port}} -d {{risingwave_db}} -U {{risingwave_user}} -f ./sql/create_source.sql

test-connection-nats-to-risingwave: setup-risingwave-source
    NAMESPACE={{namespace}} NATS_SUBJECT="tests.demo" MESSAGE_ID=1 MESSAGE_BODY="Hello RisingWave!" CREATED_AT="2026-06-17 00:00:00" bash ./scripts/publish_nats_once.sh
    sleep 3
    psql -h {{risingwave_host}} -p {{risingwave_port}} -d {{risingwave_db}} -U {{risingwave_user}} -f ./sql/create_mv_nats_tests.sql
    sleep 2
    psql -h {{risingwave_host}} -p {{risingwave_port}} -d {{risingwave_db}} -U {{risingwave_user}} -f ./sql/query_mv_nats_tests.sql

setup-iceberg:
    kubectl apply -n {{namespace}} -f ./manifests/iceberg-dev.yaml
    kubectl wait -n {{namespace}} --for=condition=Ready pod -l app=iceberg-catalog-db --timeout=2m
    kubectl wait -n {{namespace}} --for=condition=Ready pod -l app=iceberg-rest-catalog --timeout=2m

port-forward-iceberg:
    kubectl port-forward -n {{namespace}} svc/iceberg-rest-catalog 8181:8181 &>/dev/null &
    sleep 2
    ps aux | grep "kubectl port-forward" | grep "8181:8181" | grep -v grep

port-forward-seaweedfs-s3:
    kubectl port-forward -n {{namespace}} svc/seaweedfs-s3 8333:8333 &>/dev/null &
    sleep 2
    ps aux | grep "kubectl port-forward" | grep "8333:8333" | grep -v grep

expose-iceberg: port-forward-iceberg port-forward-seaweedfs-s3

setup-iceberg-environment:
    CATALOG_MANAGEMENT_URL={{catalog_management_url}} \
    CATALOG_URL={{catalog_url}} \
    WAREHOUSE={{warehouse}} \
    ICEBERG_NAMESPACE={{iceberg_namespace}} \
    S3_SERVICE_ENDPOINT={{s3_service_endpoint}} \
    S3_REGION={{s3_region}} \
    S3_ACCESS_KEY={{s3_access_key}} \
    S3_SECRET_KEY={{s3_secret_key}} \
    bash ./scripts/setup_iceberg_environment.sh

setup-iceberg-pipeline: setup-risingwave-source
    psql -h {{risingwave_host}} -p {{risingwave_port}} -d {{risingwave_db}} -U {{risingwave_user}} -f ./sql/create_iceberg_sink.sql

core-up: setup-nats setup-seaweedfs setup-risingwave

iceberg-up: setup-iceberg expose-iceberg setup-iceberg-environment setup-iceberg-pipeline

platform-up: core-up iceberg-up

publish-nats:
    NAMESPACE={{namespace}} \
    NATS_SUBJECT="{{nats_subject}}" \
    PUBLISH_INTERVAL_SECONDS={{nats_interval_seconds}} \
    MESSAGE_PREFIX="{{nats_message_prefix}}" \
    START_ID=1 \
    bash ./scripts/publish_nats.sh

publish-nats-custom subject=nats_subject interval=nats_interval_seconds prefix=nats_message_prefix start_id="1":
    NAMESPACE={{namespace}} \
    NATS_SUBJECT="{{subject}}" \
    PUBLISH_INTERVAL_SECONDS={{interval}} \
    MESSAGE_PREFIX="{{prefix}}" \
    START_ID={{start_id}} \
    bash ./scripts/publish_nats.sh

ingest-once message=nats_message_prefix:
    NAMESPACE={{namespace}} \
    NATS_SUBJECT="{{nats_subject}}" \
    MESSAGE_ID=1 \
    MESSAGE_BODY="{{message}}" \
    CREATED_AT="" \
    bash ./scripts/publish_nats_once.sh

ingest-once-custom id="1" subject=nats_subject message=nats_message_prefix created_at="":
    NAMESPACE={{namespace}} \
    NATS_SUBJECT="{{subject}}" \
    MESSAGE_ID={{id}} \
    MESSAGE_BODY="{{message}}" \
    CREATED_AT="{{created_at}}" \
    bash ./scripts/publish_nats_once.sh

query-iceberg limit=default_limit:
    echo "=== Querying Data from Iceberg Table via DuckDB ==="
    sed \
        -e 's#__CATALOG_URL__#{{catalog_url}}#g' \
        -e 's#__S3_ENDPOINT__#{{s3_endpoint}}#g' \
        -e 's#__S3_REGION__#{{s3_region}}#g' \
        -e 's#__S3_ACCESS_KEY__#{{s3_access_key}}#g' \
        -e 's#__S3_SECRET_KEY__#{{s3_secret_key}}#g' \
        -e 's#__ICEBERG_WAREHOUSE__#{{warehouse}}#g' \
        -e 's#__ICEBERG_NAMESPACE__#{{iceberg_namespace}}#g' \
        -e 's#__ICEBERG_TABLE__#{{iceberg_table}}#g' \
        -e 's#__QUERY_LIMIT__#{{limit}}#g' \
        ./sql/query_iceberg.duckdb.sql | uv tool run --from duckdb-cli duckdb

query-iceberg-custom namespace_name=iceberg_namespace table=iceberg_table warehouse_name=warehouse limit=default_limit:
    echo "=== Querying Data from Iceberg Table via DuckDB ==="
    sed \
        -e 's#__CATALOG_URL__#{{catalog_url}}#g' \
        -e 's#__S3_ENDPOINT__#{{s3_endpoint}}#g' \
        -e 's#__S3_REGION__#{{s3_region}}#g' \
        -e 's#__S3_ACCESS_KEY__#{{s3_access_key}}#g' \
        -e 's#__S3_SECRET_KEY__#{{s3_secret_key}}#g' \
        -e 's#__ICEBERG_WAREHOUSE__#{{warehouse_name}}#g' \
        -e 's#__ICEBERG_NAMESPACE__#{{namespace_name}}#g' \
        -e 's#__ICEBERG_TABLE__#{{table}}#g' \
        -e 's#__QUERY_LIMIT__#{{limit}}#g' \
        ./sql/query_iceberg.duckdb.sql | uv tool run --from duckdb-cli duckdb

query-iceberg-ready limit=default_limit: expose-iceberg
    just query-iceberg {{limit}}
