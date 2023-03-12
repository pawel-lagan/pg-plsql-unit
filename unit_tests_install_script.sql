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

CREATE OR REPLACE FUNCTION unit_test._exec(IN in_sql text)
  RETURNS void AS
$BODY$
DECLARE
	l_con_name		text := 'unit_test_exec';	
	l_int 					integer;
BEGIN
	l_con_name := unit_test._setup();
	
	IF in_sql ilike 'SELECT%' THEN
		l_int := (SELECT 1 FROM dblink(l_con_name, 'SELECT 1 FROM (' || in_sql || ') as _ee LIMIT 1') as x(i integer));
	ELSE 
		PERFORM dblink_exec(l_con_name, in_sql);
	END IF;

	PERFORM dblink_disconnect(l_con_name);

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100 SECURITY DEFINER;

CREATE OR REPLACE FUNCTION unit_test._now()
  RETURNS timestamp AS
$BODY$
DECLARE
	l_cstr		text;
	l_con		text[];
	l_con_name		text := 'unit_test_exec';	
	l_ret 					timestamp;
BEGIN
	l_con_name := unit_test._setup();
	
	l_ret := (SELECT n FROM dblink(l_con_name, 'SELECT now()') as x(n timestamp));
	
	PERFORM dblink_disconnect(l_con_name);

	RETURN l_ret;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100 SECURITY DEFINER;

CREATE OR REPLACE FUNCTION unit_test._setup()
  RETURNS text AS
$BODY$
DECLARE
	l_cstr		text;
	l_con		text[];
	l_con_name		text := 'unit_test_exec';		
BEGIN
	l_cstr := (SELECT config_param_value FROM unit_test.config WHERE config_param_name = 'connection_string' LIMIT 1);
	l_con  := dblink_get_connections();

	IF l_con IS NULL OR NOT (l_con_name =ANY(l_con)) 
	THEN	
		PERFORM dblink_connect(l_con_name, l_cstr);
	END IF;
	
	RETURN l_con_name;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100 SECURITY DEFINER;
  
CREATE OR REPLACE FUNCTION unit_test.assert_equal(in_exp anyelement, in_got anyelement,in_op character varying) 
RETURNS boolean
AS
$body$
BEGIN
	IF in_exp IS DISTINCT FROM in_got THEN 	
		PERFORM unit_test.fail(
			E'Failed assert_equal (' || in_op || E').\n'
			|| E'expected string <' || COALESCE(in_exp::VARCHAR, '<NULL>') || E'>\n'
			|| E'got string      <' || COALESCE(in_got::VARCHAR, '<NULL>') || E'>'			
		);
		RETURN false;
	END IF;
	
	PERFORM unit_test.pass();
	
	RETURN TRUE;
END;
$body$
    LANGUAGE plpgsql;
	
CREATE OR REPLACE FUNCTION unit_test.assert_false(in_exp boolean, in_op character varying) 
RETURNS boolean
AS
$body$
BEGIN
	IF in_exp IS DISTINCT FROM FALSE THEN
		PERFORM unit_test.fail(
			E'Failed assert_false (' || in_op || E').\n'
			|| E'expected false but got <' || COALESCE(in_exp::VARCHAR, '<NULL>') || E'>\n'
		);
		RETURN false;
	END IF;
	
	PERFORM unit_test.pass();
	
	RETURN TRUE;
END;
$body$
    LANGUAGE plpgsql;
	
CREATE OR REPLACE FUNCTION unit_test.assert_not_null(in_exp anyelement, in_op character varying) 
RETURNS boolean
AS
$body$
BEGIN
	IF in_exp IS NULL THEN
		PERFORM unit_test.fail(
			E'Failed assert_not_null (' || in_op || E').\n'
			|| E'expected NOT <NULL> but got <' || COALESCE(in_exp::VARCHAR, '<NULL>') || E'>\n'
		);
		RETURN false;
	END IF;
	
	PERFORM unit_test.pass();
		
	RETURN true;
END;
$body$
    LANGUAGE plpgsql;
	
CREATE OR REPLACE FUNCTION unit_test.assert_null(in_exp anyelement, in_op character varying) 
RETURNS boolean
AS
$body$
BEGIN
	IF in_exp IS NULL THEN
		PERFORM unit_test.fail(
			E'Failed assert_null (' || in_op || E').\n'
			|| E'expected <NULL> but got <' || COALESCE(in_exp::VARCHAR, '<NULL>') || E'>\n'
		);
		RETURN false;
	END IF;
	
	PERFORM unit_test.pass();
		
	RETURN true;
END;
$body$
    LANGUAGE plpgsql;
	
CREATE OR REPLACE FUNCTION unit_test.assert_true(in_exp boolean, in_op character varying) 
RETURNS boolean
AS
$body$
BEGIN
	IF in_exp IS DISTINCT FROM TRUE THEN
		PERFORM unit_test.fail(
			E'Failed assert_true (' || in_op || E').\n'
			|| E'expected true but got <' || COALESCE(in_exp::VARCHAR, '<NULL>') || E'>\n'
		);
		RETURN false;
	END IF;
	
	PERFORM unit_test.pass();
		
	RETURN true;
END;
$body$
    LANGUAGE plpgsql;
	
CREATE OR REPLACE FUNCTION unit_test.begin_test_case(IN in_test_suite character varying,IN in_test_case character varying) RETURNS void
AS
$body$
BEGIN
	UPDATE unit_test.results SET
		done = false
	WHERE test_suite = in_test_suite AND test_case = in_test_case;	
	
	IF NOT FOUND THEN
		INSERT INTO unit_test.results(test_suite,test_case,done) 
		SELECT in_test_suite as test_suite,in_test_case as test_case,false as done;
	END IF;
END;
$body$
    LANGUAGE plpgsql;
	
CREATE OR REPLACE FUNCTION unit_test.end_test_case(IN in_test_suite character varying,IN in_test_case character varying) RETURNS void
AS
$body$
BEGIN
	UPDATE unit_test.results SET
		done = true
	WHERE test_suite = in_test_suite AND test_case = in_test_case;		
END;
$body$
    LANGUAGE plpgsql;
	
	
CREATE OR REPLACE FUNCTION unit_test.fail(in_msg character varying,in_do_not_throw boolean DEFAULT true) RETURNS void
AS
$body$
BEGIN
	PERFORM unit_test._exec('UPDATE unit_test.results SET
		test_count = test_count +1,
		test_failed = test_failed + 1,
		messages = messages || ' || quote_literal(in_msg) || '::text
	WHERE done = false');
	
	IF NOT in_do_not_throw THEN
		RAISE EXCEPTION 'UNIT TEST FAIL WITH %', in_msg;
	END IF;
END;
$body$
    LANGUAGE plpgsql;
	
CREATE OR REPLACE FUNCTION unit_test.pass() RETURNS void
AS
$body$
BEGIN
	PERFORM unit_test._exec('UPDATE unit_test.results SET
		test_count = test_count +1
	WHERE done = false');
END;
$body$
    LANGUAGE plpgsql;
	
CREATE OR REPLACE FUNCTION unit_test.run_test(IN in_test_suite character varying DEFAULT '%',IN in_test_case character varying DEFAULT '%',OUT out_test_suite_name character varying, OUT out_test_case_name character varying, OUT out_total integer,OUT out_passed integer,OUT out_messages text[])
RETURNS SETOF record AS
$BODY$
DECLARE      
	l_rec     	record;
	l_sql       	character varying;
	l_proc_name	character varying;
BEGIN	
	PERFORM unit_test._exec('DELETE FROM unit_test.results');
	
	FOR l_rec IN (
		SELECT
			quote_ident(nspname) || '.' || quote_ident(proname) as test_proc,
			regexp_matches(proname,'test_([^_]+)_(.+)') as test_name
		FROM
			pg_proc
			JOIN pg_namespace ON pg_namespace.oid = pronamespace
			JOIN pg_type ON pg_type.oid = prorettype			
		WHERE
		proname like (E'test_' || in_test_suite || '_' || in_test_case)
	)
	LOOP
		RAISE NOTICE '%,%,%',l_rec.test_name[1],l_rec.test_name[2],l_rec.test_proc;
		
		PERFORM unit_test._exec('SELECT unit_test.begin_test_case(' || quote_literal(l_rec.test_name[1]) || ',' || quote_literal(l_rec.test_name[2]) || ')');
		
		BEGIN						
			l_sql = 'SELECT 1 FROM (SELECT ' || l_rec.test_proc || ' ()) as q LIMIT 1';
			EXECUTE l_sql;			
			
			PERFORM unit_test.pass();
			RAISE EXCEPTION 'ROLLBACK';		
		EXCEPTION
			WHEN raise_exception THEN
				IF SQLERRM<>'ROLLBACK' THEN
					RAISE NOTICE 'EXCEPTION %', SQLERRM;
					PERFORM unit_test.fail(SQLERRM);
				END IF;
			WHEN others THEN
				RAISE NOTICE 'ERR %', SQLERRM;				
				PERFORM unit_test.fail(SQLERRM);
		END;

		PERFORM unit_test._exec('SELECT unit_test.end_test_case(' || quote_literal(l_rec.test_name[1]) || ',' || quote_literal(l_rec.test_name[2]) || ')');		
	END LOOP;
	
	RETURN QUERY (SELECT
			test_suite,
			test_case,
			test_count,
			test_count-test_failed,
			messages
		FROM unit_test.results	
	);
	
   RETURN;
END;$BODY$
 LANGUAGE 'plpgsql' VOLATILE;
 
CREATE OR REPLACE FUNCTION unit_test.test_auto_action1() 
RETURNS void
AS
$body$
DECLARE
	l_t1 timestamp;
	l_t2 timestamp;
BEGIN
	PERFORM unit_test.assert_true(true,'OK');
	PERFORM unit_test.assert_false(false,'FALSE');
	
	l_t1 := unit_test._now();
	
	FOR i IN 1..10
	LOOP	
		l_t2 := unit_test._now();
	END LOOP;
	
	PERFORM unit_test.assert_true(l_t2 > l_t1,'OK');
END;
$body$
    LANGUAGE plpgsql;