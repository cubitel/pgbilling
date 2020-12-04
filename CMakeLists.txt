cmake_minimum_required(VERSION 2.8)
project(billing)

set(CMAKE_INSTALL_PREFIX /opt/billing)

install(DIRECTORY www/ DESTINATION www)
install(DIRECTORY ui/ DESTINATION ui)
install(DIRECTORY core/ DESTINATION core)
