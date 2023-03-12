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
