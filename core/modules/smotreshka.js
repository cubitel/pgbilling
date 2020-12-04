'use strict'

const http = require('superagent')
const fs = require('fs')

const timerTickInterval = 1000

var iptv = {}
var config
var daemon
var needSync = 0

async function syncAllUsers () {
	try {
		const { rows } = await daemon.db.query(
			'SELECT service_name, service_pass, external_id, ' +
			'array(SELECT external_id FROM service_invoices ' +
				'LEFT JOIN tarif_options ON tarif_options.option_id = service_invoices.option_id ' +
				'WHERE service_invoices.service_id = services.service_id AND invoice_active = 1 AND external_id IS NOT NULL) ' +
				'|| (CASE WHEN external_id IS NOT NULL AND service_state = 1 THEN ARRAY[external_id] ELSE ARRAY[]::text[] END) AS subscriptions ' +
			'FROM services LEFT JOIN tarifs ON tarifs.tarif_id = services.current_tarif ' +
			'WHERE services.service_type = 2'
		)

		var page_size = 100
		var page_num = 0
		while (true) {
			let res = await http.get(config.url + 'v2/accounts?page_size=' + page_size + '&page=' + page_num)
			let accounts = res.body.accounts
			if ( (accounts == undefined) || (accounts.length == 0) ) break
			page_num++

			for (var i in accounts) {
				let account = accounts[i]
				for (var r in rows) {
					let service = rows[r]
					if (service == undefined) continue;
					if (service.service_name == account.username) {
						rows[r] = undefined
						let changes = []
						let accountSubs = []

						// Delete inactive subscriptions
						for (var s in account.subscriptions) {
							let subId = account.subscriptions[s].id
							accountSubs.push(subId)
							if (service.subscriptions.indexOf(subId) < 0) changes.push({id: subId, valid: false})
						}

						// Add new subscriptions
						for (var s in service.subscriptions) {
							let subId = service.subscriptions[s]
							if (accountSubs.indexOf(subId) < 0) changes.push({id: subId, valid: true})
						}

						if (changes.length > 0) {
							console.log('Smotreshka: Changing account ' + service.service_name + ' with ' + JSON.stringify(changes))
							try {
								await http.post(config.url + 'v2/accounts/' + account.id + '/subscriptions').send(changes)
							} catch (e) {
								console.log(e)
							}
						}
					}
				}
			}

			if (accounts.length < page_size) break
		}

		for (var i in rows) {
			let account = rows[i]
			if (account == undefined) continue
			console.log('Smotreshka: Creating account ' + account.service_name + ' with ' + JSON.stringify(account.subscriptions))
			try {
				await http.post(config.url + 'v2/accounts').send({
					username: account.service_name,
					password: account.service_pass,
					email: account.service_name,
					purchases: account.subscriptions
				})
			} catch (e) {
				console.log(e)
			}
		}
	} catch (e) {
		console.log(e)
	}
}

async function getChannelList () {
	try {
		var packetNames = new Map();

		var tarifs = await daemon.db.query(
			'SELECT * FROM tarifs WHERE service_type = 2 AND external_id IS NOT NULL AND active = 1'
		);
		for (var i in tarifs.rows) {
			packetNames.set(tarifs.rows[i].external_id, tarifs.rows[i].tarif_name)
		}

		var options = await daemon.db.query(
			'SELECT * FROM tarif_options WHERE external_id IS NOT NULL AND user_controlled = 1'
		);
		for (var i in options.rows) {
			packetNames.set(options.rows[i].external_id, options.rows[i].option_name)
		}

		var res = await http.get(config.url + 'v2/subscriptions')
		var apiList = res.body
		var ourList = []

		for (var packetIdx in apiList) {
			var apiPacket = apiList[packetIdx]
			if (packetNames.get(apiPacket.id) == undefined) continue;
			var ourPacket = {id: apiPacket.id, name: packetNames.get(apiPacket.id), channels: []}
			if (apiPacket.channels.length == 0) continue
			for (var channelIdx in apiPacket.channels) {
				ourPacket.channels.push({name: apiPacket.channels[channelIdx].name})
			}
			ourList.push(ourPacket)
		}

		fs.writeFile(config.channels, JSON.stringify(ourList), (err) => {})
	} catch (e) {
		console.log(e)
	}
}

async function timerTick () {
	needSync--
	if (needSync <= 0) {
		await syncAllUsers()
		if (config.channels != undefined) {
			await getChannelList()
		}
		needSync = config.syncInterval
	}

	setTimeout(timerTick, timerTickInterval)
}

iptv.init = async function (initConfig, initDaemon) {
	config = initConfig
	daemon = initDaemon

	if (config.syncInterval == undefined) config.syncInterval = 86400
	if (config.waitInterval == undefined) config.waitInterval = 2

	daemon.subscriber.notifications.on('service_invoices_change', (payload) => {
		try {
			if (payload.service_type == 2) {
				needSync = config.waitInterval
			}
		} catch (e) {
			console.log(e)
		}
	})
	daemon.subscriber.listenTo('service_invoices_change')

	setTimeout(timerTick, timerTickInterval)
}

module.exports = iptv
