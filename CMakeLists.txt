cmake_minimum_required(VERSION 2.8)
project(billing)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11 -O3 -Wall")
set(CMAKE_INSTALL_PREFIX /opt/billing)
set(CMAKE_MODULE_PATH "cmake_modules")

install(DIRECTORY www/ DESTINATION www)

install(PROGRAMS api/api-server DESTINATION lib)
install(FILES api/plugin.py DESTINATION lib)
FILE(GLOB files "api/plugins/*.py")
install(FILES ${files} DESTINATION lib/plugins)
