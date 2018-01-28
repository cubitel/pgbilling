
var jsonSql = require('json-sql')({dialect: 'postgresql'})

var commands = {}

commands.select = async function (client, request) {
  request.type = 'select'
  var sql = jsonSql.build(request)
  const { rows } = await client.db.query(sql.query)
  return { rows: rows }
}

commands.perform = async function (client, request) {
  var sql = 'SELECT ' + request.proc + '('
  var params = request.params
  var sqlparams = ''
  for (let i in params) {
    if (sqlparams !== '') sqlparams += ', '
    sqlparams += '$' + (i + 1)
  }
  sql += sqlparams + ');'

  const { rows } = await client.db.query(sql, params)
  return { rows: rows }
}

module.exports = commands
