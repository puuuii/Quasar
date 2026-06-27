DROP SOURCE IF EXISTS iceberg_demo_source;

CREATE SOURCE IF NOT EXISTS iceberg_demo_source
WITH (
    connector = 'iceberg',
    catalog.type = 'rest',
    catalog.uri = 'http://iceberg-rest-catalog.quasar.svc.cluster.local:8181/catalog',
    warehouse.path = 'demo',
    s3.endpoint = 'http://seaweedfs-s3.quasar.svc.cluster.local:8333',
    s3.region = 'us-east-1',
    s3.access.key = 'seaweedfs_rw_access',
    s3.secret.key = 'seaweedfs_rw_secret',
    s3.path.style.access = 'true',
    database.name = 'demo_db',
    table.name = 'demo_table'
);
