project(autoauth C)
cmake_minimum_required(VERSION 2.8)

include(FindPkgConfig)
pkg_check_modules(WEBKIT REQUIRED webkit2gtk-3.0)

include_directories(
    ${WEBKIT_INCLUDE_DIRS}
)
link_directories(
    ${WEBKIT_LIBRARY_DIRS}
)

set(LIBS
    ${WEBKIT_LIBRARIES}
)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=gnu99 -Wall")

add_executable(autoauth main.c)
target_link_libraries(autoauth ${LIBS})
