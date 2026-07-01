INSTALL httpfs;
INSTALL iceberg;
LOAD httpfs;
LOAD iceberg;

CREATE OR REPLACE SECRET seaweedfs_secret (
    TYPE s3,
    PROVIDER config,
    KEY_ID '__S3_ACCESS_KEY__',
    SECRET '__S3_SECRET_KEY__',
    REGION '__S3_REGION__',
    ENDPOINT '__S3_ENDPOINT__',
    URL_STYLE 'path',
    USE_SSL false
);

ATTACH '__ICEBERG_WAREHOUSE__' AS iceberg_catalog (
    TYPE iceberg,
    ENDPOINT '__CATALOG_URL__',
    AUTHORIZATION_TYPE 'none',
    ACCESS_DELEGATION_MODE 'none'
);

SELECT *
FROM iceberg_catalog.__ICEBERG_NAMESPACE__.__ICEBERG_TABLE__
LIMIT __QUERY_LIMIT__;
