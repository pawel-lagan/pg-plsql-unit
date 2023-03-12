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