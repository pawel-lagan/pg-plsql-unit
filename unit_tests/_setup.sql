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
