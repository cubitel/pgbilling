<?php

@require("common.php");

$action = $_POST['action'];
$invoiceId = $_POST['invoiceId'];
$shopId = $_POST['shopId'];
$time = $_POST['requestDatetime'];
$sum = floatval($_POST['orderSumAmount']);
$account = $_POST['customerNumber'];


$tag = "Response";
$code = 1;


if ($action == "checkOrder") {
	$tag = "checkOrderResponse";
	$res = dbCheck($config["yandex"]["agentId"], $account);
	if ($res == 0) {
		$code = 100;
	} else {
		$code = 0;
	}
}

if ($action == "paymentAviso") {
	$tag = "paymentAvisoResponse";

	if (function_exists('printCheck')) {
		printCheck($account, $sum, "");
	}

	$res = dbPay($config["yandex"]["agentId"], $account, $sum, $invoiceId, "Платеж через Яндекс.Деньги");
	if ($res == 0) {
		$code = 100;
	} else {
		$code = 0;
	}
}


header("Content-Type: application/xml");
print('<?xml version="1.0" encoding="UTF-8"?>');
$resp = "<{$tag} performedDatetime=\"{$time}\" code=\"{$code}\" invoiceId=\"{$invoiceId}\" shopId=\"{$shopId}\" />\n";
print($resp);
