#include <boost/property_tree/ini_parser.hpp>
#include <string>
#include <pqxx/pqxx>

#include "wsproto.pb.h"
#include "server_ws.hpp"

#define CONFIG_FILE "/opt/billing/etc/billd.conf"

using namespace std;

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

	// Send response
	sendMessage(server, client.connection, resp);
}

int main()
{
	// Read config file
	boost::property_tree::ptree config;

	boost::property_tree::read_ini(CONFIG_FILE, config);

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
