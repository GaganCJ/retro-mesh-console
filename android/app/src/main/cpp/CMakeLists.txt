cmake_minimum_required(VERSION 3.10.2)
project(native_render)

add_library(native_render SHARED native-render.cpp)

find_library(log-lib log)
find_library(android-lib android)

target_link_libraries(native_render ${log-lib} ${android-lib})
