<?php

function rpsystemAPI($cmd, $req=array())
{
	global $config;

	$frHost = $config['kassa']['host'];
	$url = "http://{$frHost}/fr/api/v2/{$cmd}";

	$req['RequestId'] = "API-".time();
	$req['Password'] = intval($config['kassa']['password']);

	$body = json_encode($req, JSON_UNESCAPED_UNICODE);

	$ctx = stream_context_create(array(
		'http' => array(
			'method' => "POST",
			'header' => "Content-Type: application/json\r\n",
			'content' => $body
		)
	));

	$res = @file_get_contents($url, false, $ctx);
	if ($res === false) return false;

	return json_decode($res);
}

function printCheck($account, $amount, $phone)
{
	$units = $amount * 100;

	$req = array(
		'DocumentType' => 0,
		'Lines' => array(array(
			'Qty' => 1000,
			'Price' => $units,
			'PayAttribute' => 3,
			'TaxId' => 4,
			'Description' => "Аванс за услуги связи л/с {$account}"
		)),
		'NonCash' => array(0, $units, 0),
		'PhoneOrEmail' => $phone,
		'MaxDocumentsInTurn' => 5000,
		'FullResponse' => true
	);

	$res = rpsystemAPI("Complex", $req);

	if (!is_array($res->Responses)) return false;

	foreach ($res->Responses as $response) {
		if (isset($response->Response->QR)) return array(
			'QR' => $response->Response->QR,
			'Text' => $response->Response->Text
		);
	}
	return false;
}

function closeTurn()
{
	return rpsystemAPI("CloseTurn");
}
