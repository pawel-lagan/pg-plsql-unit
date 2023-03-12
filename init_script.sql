CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE SCHEMA IF NOT EXISTS event_store;

--- 

CREATE TABLE IF NOT EXISTS event_store.events
(
    id        SERIAL PRIMARY KEY,
    stream_id BIGINT NOT NULL,
    version   BIGINT NOT NULL,
    data      JSONB  NOT NULL,
    UNIQUE (stream_id, version)
);

SELECT * FROM unit_test.run_test('%', '%');

