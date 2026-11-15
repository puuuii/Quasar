DROP SINK IF EXISTS nats_to_iceberg_sink;

CREATE SINK IF NOT EXISTS nats_to_iceberg_sink
FROM nats_tests_source
WITH (
    connector = 'iceberg',
    type = 'append-only',
    force_append_only = 'true',
    catalog.type = 'rest',
    catalog.name = 'default',
    catalog.uri = 'http://seaweedfs-s3.quasar.svc.cluster.local:8181',
    catalog.rest.sigv4_enabled = 'true',
    catalog.rest.signing_region = 'us-east-1',
    catalog.rest.signing_name = 's3',
    warehouse.path = 's3://iceberg-bucket',
    s3.endpoint = 'http://seaweedfs-s3.quasar.svc.cluster.local:8333',
    s3.region = 'us-east-1',
    s3.access.key = 'seaweedfs_rw_access',
    s3.secret.key = 'seaweedfs_rw_secret',
    s3.path.style.access = 'true',
    database.name = 'demo_db',
    table.name = 'demo_table',
    create_table_if_not_exists = 'true'
);
