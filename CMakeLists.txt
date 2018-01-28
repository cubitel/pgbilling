cmake_minimum_required(VERSION 2.8)
project(billing)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11 -O3 -Wall")
set(CMAKE_INSTALL_PREFIX /opt/billing)
set(CMAKE_MODULE_PATH "cmake_modules")

#find_package(Boost 1.54.0 COMPONENTS system regex coroutine context thread program_options REQUIRED)
#include_directories(${Boost_INCLUDE_DIR})

#find_package(OpenSSL REQUIRED)
#include_directories(${OPENSSL_INCLUDE_DIR})

#find_package(PQXX REQUIRED)

#include(FindProtobuf)
#find_package(Protobuf REQUIRED)
#include_directories(${PROTOBUF_INCLUDE_DIR})

#find_package(CURL REQUIRED)
#include_directories(${CURL_INCLUDE_DIR})

#ADD_SUBDIRECTORY(ws-server)

install(DIRECTORY www/ DESTINATION www)
install(FILES ws-server/wsproto.proto DESTINATION www/cabinet)
install(FILES ws-server/wsproto.proto DESTINATION www/admin)

install(PROGRAMS api/api-server DESTINATION lib)
install(FILES api/plugin.py DESTINATION lib)
FILE(GLOB files "api/plugins/*.py")
install(FILES ${files} DESTINATION lib/plugins)
