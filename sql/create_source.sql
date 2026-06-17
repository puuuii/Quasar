DROP SOURCE IF EXISTS nats_tests_source;

CREATE SOURCE nats_tests_source (
    id INT,
    message VARCHAR,
    created_at TIMESTAMP
)
WITH (
    connector = 'nats',
    server_url = 'nats://nats.quasar.svc.cluster.local:4222',
    subject = 'tests.*',
    stream = 'TEST_STREAM',
    connect_mode = 'plain',
    consumer.durable_name = 'risingwave_quasar_consumer'
)
FORMAT PLAIN ENCODE JSON;
