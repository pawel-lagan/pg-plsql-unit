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
