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

function osmpResponse($result, $txn_id="")
{
	$osmp_txn_id = $_REQUEST['txn_id'];
	$sum = floatval($_REQUEST['sum']);

	header("Content-Type: text/xml");
	print("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
	print("<response>");
	print("<osmp_txn_id>{$osmp_txn_id}</osmp_txn_id>");
	if ($txnid != "") print("<prv_txn>{$txn_id}</prv_txn>");
	print("<sum>{$sum}</sum>");
	print("<result>{$result}</result>");
	print("</response>");
	die();
}

function osmpProcess($agentName)
{
	global $config;
	
	$cfg = $config[$agentName];
	
	$command = $_REQUEST['command'];
	$osmp_txn_id = $_REQUEST['txn_id'];
	$account = $_REQUEST['account'];
	$sum = floatval($_REQUEST['sum']);
	
	if ($command == "check") {
		if (dbCheck($cfg['agentId'], $account) == 0) {
			osmpResponse(5);
		}
		
		osmpResponse(0);
	}
	
	if ($command == "pay") {
		$txn_id = dbPay($cfg['agentId'], $account, $sum, $osmp_txn_id, "Платеж через терминал ({$agentName})");
		if ($txn_id == 0) {
			osmpResponse(1);
		}
		
		osmpResponse(0, $txn_id);
	}
}
