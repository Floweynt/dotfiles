cmake_minimum_required(VERSION 3.16)
project(qspolkit LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick DBus Network)

add_library(qspolkit SHARED
    plugin.cpp
    polkitagent.hpp
    polkitagent.cpp
)

target_link_libraries(qspolkit PRIVATE
    Qt6::Core Qt6::Qml Qt6::Quick Qt6::DBus Qt6::Network
)
target_include_directories(qspolkit PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

install(TARGETS qspolkit LIBRARY DESTINATION lib/qt-6/qml/qs/polkit)
install(FILES qmldir     DESTINATION lib/qt-6/qml/qs/polkit)
