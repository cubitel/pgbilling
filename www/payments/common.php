<?php

@require("config.php");

$dblink = @pg_connect($config["database"]["cstring"]);
if (!$dblink) die();


function dbCheck($agentId, $accountNumber)
{
	global $dblink;

	$res = pg_query_params($dblink, "SELECT payment_check($1, $2)", array($agentId, $accountNumber));
	if (!$res) return false;
	
	$row = pg_fetch_row($res);
	return $row[0];
}

function dbPay($agentId, $accountNumber, $amount, $agentRef, $descr)
{
	global $dblink;

	$res = pg_query_params($dblink, "SELECT payment_pay($1, $2, $3, $4, $5)", array($agentId, $accountNumber, $amount, $agentRef, $descr));
	if (!$res) return false;
	
	$row = pg_fetch_row($res);
	return $row[0];
}
