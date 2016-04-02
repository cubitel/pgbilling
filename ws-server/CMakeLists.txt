PROTOBUF_GENERATE_CPP(CPPS HS wsproto.proto)

add_executable(ws-server main.cpp ${CPPS})
target_link_libraries(ws-server ${Boost_LIBRARIES})
target_link_libraries(ws-server ${PQXX_LIBRARIES})
target_link_libraries(ws-server ${OPENSSL_LIBRARIES})
target_link_libraries(ws-server ${PROTOBUF_LIBRARIES})

install(TARGETS ws-server DESTINATION bin)
