var config = {}

config.db = {
	host: "127.0.0.1",
	user: "system",
	password: "<password>",
	database: "billing"
}

config.modules = {}

// NORSITRANS SORM3 export module

//config.modules.norsitrans = {
//	host: '127.0.0.1',
//	user: 'isp',
//	password: 'isp-isp',
//	forcePasv: true,
//	branch: 2
//}

// Smotreshka.tv (lifestream) module

//config.modules.smotreshka = {
//	url: 'https://provider.test.lfstrm.tv/'
//}

module.exports = config
