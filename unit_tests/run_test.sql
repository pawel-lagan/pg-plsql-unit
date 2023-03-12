﻿CREATE OR REPLACE FUNCTION unit_test.run_test(IN in_test_suite character varying DEFAULT '%',IN in_test_case character varying DEFAULT '%',OUT out_test_suite_name character varying, OUT out_test_case_name character varying, OUT out_total integer,OUT out_passed integer,OUT out_messages text[])RETURNS SETOF record AS$BODY$DECLARE      	l_rec     	record;	l_sql       	character varying;	l_proc_name	character varying;BEGIN		PERFORM unit_test._exec('DELETE FROM unit_test.results');		FOR l_rec IN (		SELECT			quote_ident(nspname) || '.' || quote_ident(proname) as test_proc,			regexp_matches(proname,'test_([^_]+)_(.+)') as test_name		FROM			pg_proc			JOIN pg_namespace ON pg_namespace.oid = pronamespace			JOIN pg_type ON pg_type.oid = prorettype					WHERE		nspname = 'unit_test'		AND proname like (E'test_' || in_test_suite || '_' || in_test_case)	)	LOOP		RAISE NOTICE '%,%,%',l_rec.test_name[1],l_rec.test_name[2],l_rec.test_proc;				PERFORM unit_test._exec('SELECT unit_test.begin_test_case(' || quote_literal(l_rec.test_name[1]) || ',' || quote_literal(l_rec.test_name[2]) || ')');				BEGIN									l_sql = 'SELECT 1 FROM (SELECT ' || l_rec.test_proc || ' ()) as q LIMIT 1';			EXECUTE l_sql;									PERFORM unit_test.pass();			RAISE EXCEPTION 'ROLLBACK';				EXCEPTION			WHEN raise_exception THEN				IF SQLERRM<>'ROLLBACK' THEN					RAISE NOTICE 'EXCEPTION %', SQLERRM;					PERFORM unit_test.fail(SQLERRM);				END IF;			WHEN others THEN				RAISE NOTICE 'ERR %', SQLERRM;								PERFORM unit_test.fail(SQLERRM);		END;		PERFORM unit_test._exec('SELECT unit_test.end_test_case(' || quote_literal(l_rec.test_name[1]) || ',' || quote_literal(l_rec.test_name[2]) || ')');			END LOOP;		RETURN QUERY (SELECT			test_suite,			test_case,			test_count,			test_count-test_failed,			messages		FROM unit_test.results		);	   RETURN;END;$BODY$ LANGUAGE 'plpgsql' VOLATILE;