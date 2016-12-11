<?php

@require("config.php");

function result($res)
{
	header("Content-Type: text/json");
	print(json_encode($res, JSON_UNESCAPED_UNICODE));
	die();
}

function getDeviceInfo($ip, $port)
{
	global $config;
	
	$cols = explode("/", $ip);
	$ip = $cols[0];
	$comm = $config['snmp_community'];

	$cols = explode("-", $port);
	if ( (sizeof($cols) == 4) && ($cols[3] > 500) ) $cols[3] = $cols[3] % 100;
	$port = implode("-", $cols);

	snmp_set_valueretrieval(SNMP_VALUE_PLAIN);
	snmp_set_oid_output_format(SNMP_OID_OUTPUT_NUMERIC);

	$res = @snmpwalkoid($ip, $comm, ".1.3.6.1.4.1.5504.5.14.1.2.1.3");
	foreach ($res as $oid => $row) {
		if (strlen($row) < 3) continue;
		$row = sprintf("%08X", $row);
		$oidcols = explode(".", $oid);
		$ifindex = $oidcols[sizeof($oidcols)-1];
		$ifname = trim(@snmp2_get($ip, $comm, "ifName.{$ifindex}"));
		if ($ifname == $port) {
			return array(
				'serial' => "ZNTS{$row}",
				'rssiUP' => snmp2_get($ip, $comm, ".1.3.6.1.4.1.5504.5.14.1.7.1.3.{$ifindex}") / 10,
				'rssiDN' => snmp2_get($ip, $comm, ".1.3.6.1.4.1.5504.5.14.1.7.1.4.{$ifindex}") / 10
			);
		}
	}
	
	return false;
}

$dblink = @pg_connect($config["database"]);
if (!$dblink) die();

$cmd = $_REQUEST['cmd'];
$ip = $_SERVER['REMOTE_ADDR'];

if ($cmd == "regGetInfo") {
	$info = array();
	$res = pg_query_params($dblink, "SELECT * FROM reg_get_info($1);", array($ip));
	while ($row = pg_fetch_object($res)) {
		$info[$row->name] = $row->value;
	}
	
	if (isset($info['test'])) {
		result($info);
	}
	
	if (!isset($info['device'])) {
		result(array('error' => "Не удалось найти ваше подключение в БД."));
	}
	
	$dev = getDeviceInfo($info['device'], $info['port']);
	if (!$dev) {
//		result(array('error' => "Не удалось найти ваше устройство в сети. Повторите попытку."));
		$dev = array('serial' => '');
	}
	
	$cols = explode("-", $info['port']);
	$user_port = 1;
	if (sizeof($cols) == 4) {
		$user_port = floor($cols[3] / 100) - 4;
	}
	
	pg_query_params($dblink, "SELECT reg_set_serial($1, $2, $3);", array($info['service_id'], $dev['serial'], $user_port));

	result(array(
		'device' => $dev
	));
}

if ($cmd == "regRegisterService") {
	$birthdate = date("Y-m-d", strtotime($_POST['birthdate']));

	$info = array();
	$res = pg_query_params($dblink, "SELECT * FROM reg_register_service($1, $2, $3, $4, $5, $6, $7);",
		array($ip, intval($_POST['ticket_id']), intval($_POST['tarif']), $_POST['namef'], $_POST['namei'], $_POST['nameo'], $birthdate));
	
	if (!$res) {
		result(array('error' => pg_last_error($dblink)));
	}
	
	while ($row = pg_fetch_object($res)) {
		$info[$row->name] = $row->value;
	}

	result($info);
}

if ($cmd == "regRegisterTestService") {
	$info = array();
	$res = pg_query_params($dblink, "SELECT * FROM reg_register_test_service($1, $2);",
		array($ip, intval($_POST['tarif']) ));
	
	if (!$res) {
		result(array('error' => pg_last_error($dblink)));
	}
	
	while ($row = pg_fetch_object($res)) {
		$info[$row->name] = $row->value;
	}

	result($info);
}
