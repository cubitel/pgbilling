#include <boost/property_tree/ini_parser.hpp>
#include <boost/program_options.hpp>
#include <string>
#include <boost/regex.hpp>
#include <pqxx/pqxx>

#include "wsproto.pb.h"
#include "server_ws.hpp"

#define CONFIG_FILE "/opt/billing/etc/billd.conf"

using namespace std;

namespace po = boost::program_options;

typedef SimpleWeb::SocketServer<SimpleWeb::WS> WsServer;

struct Client {
	shared_ptr<WsServer::Connection> connection;
	shared_ptr<pqxx::connection> psql;
};

std::vector<Client> clients;

/*
 * Add new connection to clients table
 */
static Client& newClient(shared_ptr<WsServer::Connection> connection,
        shared_ptr<pqxx::connection> psql)
{
	Client newclient;
	newclient.connection = connection;
	newclient.psql = psql;
	clients.push_back(newclient);

	return clients[clients.size() - 1];
}

/*
 * Find connection in clients table
 */
static Client& findClient(shared_ptr<WsServer::Connection> connection)
{
	for (unsigned i = 0; i < clients.size(); i++) {
		if (clients[i].connection == connection)
			return clients[i];
	}

	throw;
}

/*
 * Delete connection from clients table
 */
static void delClient(shared_ptr<WsServer::Connection> connection)
{
	for (unsigned i = 0; i < clients.size(); i++) {
		if (clients[i].connection == connection) {
			clients.erase(clients.begin() + i);
			break;
		}
	}
}

/*
 * Serialize and send server message to client
 */
static void sendMessage(WsServer& server, shared_ptr<WsServer::Connection> connection,
        WSPROTO::ServerMessage& message)
{
	std::string str;
	message.SerializeToString(&str);

	auto send_stream = make_shared<WsServer::SendStream>();
	*send_stream << str;
	server.send(connection, send_stream, nullptr, 130);
}

/*
 * Check relation (table, view, field, etc) name for valid charachers
 * Throws std::runtime_error if name has invalid characters
 */
static void checkRelationName(std::string& name)
{
	if (boost::regex_match(name, boost::regex("[[^:alnum:_]]"))) {
		throw std::runtime_error("Invalid characters in relation name.");
	}
}

/*
 * Parse client message and dispatch command
 */
static void processMessage(WsServer& server, Client& client,
        shared_ptr<WsServer::Message> message)
{
	// Parse client message
	std::string msgstr = message->string();
	WSPROTO::ClientMessage req;
	req.ParseFromString(msgstr);

	// Prepare response
	WSPROTO::ServerMessage resp;

	if (req.has_sequence()) {
		resp.set_sequence(req.sequence());
	}

	if (req.has_loginrequest()) {
		int status = 0;

		pqxx::work trn(*client.psql);
		auto sqlres = trn.prepared("login")(req.loginrequest().login())(req.loginrequest().password()).exec();
		trn.commit();

		sqlres[0]["login"].to(status);
		resp.mutable_loginresponse()->set_status(status);
	}
	
	if (req.has_selectrequest()) {
		pqxx::work trn(*client.psql);
		
		std::string table = req.selectrequest().table();
		checkRelationName(table);
		std::string sql = "SELECT * FROM " + table;
		
		auto sqlres = trn.exec(sql);
		trn.commit();
		
		auto sqlresp = resp.mutable_selectresponse();
		for (unsigned int i = 0; i < sqlres.size(); i++) {
			const auto row = sqlres[i];
			for (unsigned int c = 0; c < row.size(); c++) {
				if (i == 0) {
					sqlresp->add_columns(row[c].name());
				}
				std::string s;
				row[c].to(s);
				sqlresp->add_data(s);
			}
		}
	}

	if (req.has_functionrequest()) {
		pqxx::work trn(*client.psql);
		
		std::string name = req.functionrequest().name();
		checkRelationName(name);

		std::string sql = "SELECT " + name + "(";
		for (int i = 1; i <= req.functionrequest().params_size(); i++) {
			if (i > 1) sql += ", ";
			sql += "$" + std::to_string(i);
		}
		sql += ")";
		client.psql->prepare("func", sql);
		
		auto stmt = trn.prepared("func");
		
		for (int i = 0; i < req.functionrequest().params_size(); i++) {
			auto param = req.functionrequest().params(i);
			if (param.has_s()) stmt(param.s());
			if (param.has_i()) stmt(param.i());
		}
		
		auto sqlres = stmt.exec();
		trn.commit();
		
		auto sqlresp = resp.mutable_selectresponse();
		for (unsigned int i = 0; i < sqlres.size(); i++) {
			const auto row = sqlres[i];
			for (unsigned int c = 0; c < row.size(); c++) {
				if (i == 0) {
					sqlresp->add_columns(row[c].name());
				}
				std::string s;
				row[c].to(s);
				sqlresp->add_data(s);
			}
		}
	}

	// Send response
	sendMessage(server, client.connection, resp);
}

int main(int ac, char**av)
{
	// Command-line options
	po::options_description desc("Allowed options");
	desc.add_options()
		("conf,c", po::value<std::string>()->default_value(CONFIG_FILE), "Set configuration file")
	;
	
	po::variables_map vm;
	po::store(po::parse_command_line(ac, av, desc), vm);
	po::notify(vm);
	
	// Read config file
	boost::property_tree::ptree config;

	boost::property_tree::read_ini(vm["conf"].as<std::string>(), config);

	const boost::property_tree::ptree& cfgServer = config.get_child("server");

	// Create WebSocket server instance
	WsServer server(cfgServer.get<int>("port", 8081), 4);

	// Create WS endpoint
	auto& wsEp = server.endpoint["^/ws/?$"];

	wsEp.onopen =
	        [&server,&cfgServer](shared_ptr<WsServer::Connection> connection) {
				try {
					auto psql = make_shared<pqxx::connection>(cfgServer.get<std::string>("database", ""));
					psql->prepare("login", "SELECT login($1, $2)");

					newClient(connection, psql);
				} catch (const std::exception &e) {
					WSPROTO::ServerMessage resp;
					auto err = resp.mutable_error();
					err->set_code(WSPROTO::ErrorCode::SERVER_ERROR);
					err->set_fatal(true);
					err->set_message(e.what());
					sendMessage(server, connection, resp);
				}
	        };

	wsEp.onmessage =
	        [&server](shared_ptr<WsServer::Connection> connection, shared_ptr<WsServer::Message> message) {
				try {
		        	auto client = findClient(connection);
		        	processMessage(server, client, message);
				} catch (const std::exception &e) {
					WSPROTO::ServerMessage resp;
					auto err = resp.mutable_error();
					err->set_code(WSPROTO::ErrorCode::SERVER_ERROR);
					err->set_fatal(true);
					err->set_message(e.what());
					sendMessage(server, connection, resp);
				}
	        };

	// Remove connection from connection list if connection is closed or an error occurred
	wsEp.onclose =
	        [](shared_ptr<WsServer::Connection> connection, int status, const string& reason) {
		        // Delete session
		        delClient(connection);
	        };
	wsEp.onerror =
	        [](shared_ptr<WsServer::Connection> connection, const boost::system::error_code& ec) {
		        // Delete session
		        delClient(connection);
	        };

	// Start server
	thread server_thread([&server]() {
		server.start();
	});
	server_thread.join();

	return 0;
}
