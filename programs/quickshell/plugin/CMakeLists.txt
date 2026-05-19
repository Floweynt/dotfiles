cmake_minimum_required(VERSION 3.16)
project(floweyshell LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick DBus Network)
find_library(LIBURING_LIB uring REQUIRED)

add_library(floweyshell SHARED
    plugin.cpp
    sysmon.hpp
    sysmon.cpp
    nixgen.hpp
    nixgen.cpp
    polkitagent.hpp
    polkitagent.cpp
    hwprovider.hpp
    hwprovider.cpp
    systemdwatcher.hpp
    systemdwatcher.cpp
)

target_link_libraries(floweyshell PRIVATE
    Qt6::Core Qt6::Qml Qt6::Quick Qt6::DBus Qt6::Network
    ${LIBURING_LIB}
)
target_include_directories(floweyshell PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

install(TARGETS floweyshell LIBRARY DESTINATION lib/qt-6/qml/qs/floweyshell)
install(FILES qmldir        DESTINATION lib/qt-6/qml/qs/floweyshell)
