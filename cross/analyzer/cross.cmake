set(CMAKE_SYSTEM_NAME Linux)

if(NOT ("$ENV{CC}" STREQUAL ""))
    set(CMAKE_C_COMPILER "$ENV{CC}")
endif()
if(NOT ("$ENV{CXX}" STREQUAL ""))
    set(CMAKE_CXX_COMPILER "$ENV{CXX}")
endif()

if(NOT ("$ENV{CFLAGS}" STREQUAL ""))
    set(CMAKE_C_FLAGS "$ENV{CFLAGS}")
endif()
if(NOT ("$ENV{CXXFLAGS}" STREQUAL ""))
    set(CMAKE_CXX_FLAGS "$ENV{CXXFLAGS}")
endif()
if(NOT ("$ENV{LDFLAGS}" STREQUAL ""))
    set(CMAKE_EXE_LINKER_FLAGS "$ENV{LDFLAGS}")
    set(CMAKE_MODULE_LINKER_FLAGS "$ENV{LDFLAGS}")
    set(CMAKE_SHARED_LINKER_FLAGS "$ENV{LDFLAGS}")
endif()
set(CMAKE_INSTALL_SO_NO_EXE 0)

if(NOT ("$ENV{SYSROOT}" STREQUAL ""))
    set(CMAKE_FIND_ROOT_PATH "$ENV{SYSROOT}")
endif()
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
if(NOT ("$ENV{SYSROOT}" STREQUAL ""))
    set(ENV{PKG_CONFIG_SYSROOT_DIR} "$ENV{SYSROOT}")
endif()
