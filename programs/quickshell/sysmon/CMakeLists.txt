cmake_minimum_required(VERSION 3.16)
project(qssysmon LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick)
find_library(LIBURING_LIB uring REQUIRED)

add_library(qssysmon SHARED
    plugin.cpp
    sysmon.hpp
    sysmon.cpp
    nixgen.hpp
    nixgen.cpp
)

target_link_libraries(qssysmon PRIVATE Qt6::Core Qt6::Qml Qt6::Quick ${LIBURING_LIB})
target_include_directories(qssysmon PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

install(TARGETS qssysmon LIBRARY DESTINATION lib/qt-6/qml/qs/sysmon)
install(FILES qmldir    DESTINATION lib/qt-6/qml/qs/sysmon)
