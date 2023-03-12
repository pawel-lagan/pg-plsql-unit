CREATE EXTENSION IF NOT EXISTS dblink;

CREATE SCHEMA unit_test;

DROP TABLE IF EXISTS unit_test.results;
CREATE TABLE unit_test.results
(
  test_suite character varying NOT NULL,
  test_case character varying NOT NULL,
  test_count integer DEFAULT 0,
  test_failed integer DEFAULT 0,
  done boolean DEFAULT true,
  messages text[],
  CONSTRAINT results_pkey PRIMARY KEY (test_suite, test_case)
)
WITH (
  OIDS=FALSE
);

DROP TABLE IF EXISTS unit_test.config;
CREATE TABLE unit_test.config
(
  config_param_name character varying NOT NULL,
  config_param_value character varying NOT NULL,
  CONSTRAINT config_pkey PRIMARY KEY (config_param_name)
)
WITH (
  OIDS=FALSE
);

INSERT INTO unit_test.config(config_param_name,config_param_value) VALUES('connection_string','dbname=' ||  current_database());