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