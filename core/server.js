'use strict'

var config = require('./config.js')

const { Client } = require('pg')
const pgInfo = require('@wmfs/pg-info')
const pgSubscriber = require('pg-listen')

function getCurrentSchema (db, schemas) {
  return new Promise(function (resolve, reject) {
    pgInfo({client: db, schemas: schemas}, function (err, info) {
      if (err) {
        return reject(err)
      } else {
        return resolve(info)
      }
    })
  })
}

async function init () {
	const db = new Client(config.db)
	await db.connect()
	console.log('Ready')

//	let schema = await getCurrentSchema(db, ['system'])
//	console.log(JSON.stringify(schema, null, '\t'))

	const subscriber = pgSubscriber(config.db)
	subscriber.events.on('error', (error) => {
		console.log(error)
	})
	await subscriber.connect()

	const daemon = {
		db: db,
		subscriber: subscriber
	}

	for (var moduleName in config.modules) {
		let module = require('./modules/' + moduleName + '.js')
		module.init(config.modules[moduleName], daemon)
	}
}

init()
