INSTALL httpfs;
INSTALL iceberg;
LOAD httpfs;
LOAD iceberg;

CREATE OR REPLACE SECRET seaweedfs_catalog_secret (
    TYPE iceberg,
    CLIENT_ID '__S3_ACCESS_KEY__',
    CLIENT_SECRET '__S3_SECRET_KEY__',
    OAUTH2_SERVER_URI '__CATALOG_URL__/v1/oauth/tokens'
);

CREATE OR REPLACE SECRET seaweedfs_storage (
    TYPE s3,
    KEY_ID '__S3_ACCESS_KEY__',
    SECRET '__S3_SECRET_KEY__',
    REGION '__S3_REGION__',
    ENDPOINT '__S3_ENDPOINT__',
    URL_STYLE 'path',
    USE_SSL false
);

ATTACH '__TABLE_BUCKET__' AS iceberg_catalog (
    TYPE iceberg,
    URI '__CATALOG_URL__',
    SECRET seaweedfs_catalog_secret
);

SELECT *
FROM iceberg_catalog.__ICEBERG_NAMESPACE__.__ICEBERG_TABLE__
LIMIT __QUERY_LIMIT__;
