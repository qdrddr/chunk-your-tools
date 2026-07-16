cmake_minimum_required(VERSION 3.16)
project(chunk-your-tools-c VERSION 2.0.1 LANGUAGES C)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CHUNK_YOUR_TOOLS_REPO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../..")
set(CHUNK_YOUR_TOOLS_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/include")
set(CHUNK_YOUR_TOOLS_BUILD_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/scripts/build-c-lib.sh")

option(CHUNK_YOUR_TOOLS_BUILD_SHARED "Expose shared library imported target" ON)
option(CHUNK_YOUR_TOOLS_BUILD_STATIC "Expose static library imported target" OFF)
option(CHUNK_YOUR_TOOLS_BUILD_EXAMPLES "Build examples and register CTest" ON)
option(CHUNK_YOUR_TOOLS_INSTALL "Generate install rules" ON)
option(CHUNK_YOUR_TOOLS_BUILD_ALL_TARGETS "Build all six Rust triplets" OFF)

if(NOT DEFINED CHUNK_YOUR_TOOLS_RUST_TARGET)
    execute_process(
        COMMAND rustc -vV
        OUTPUT_VARIABLE _chunk_your_tools_rustc_vv
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    string(REGEX MATCH "host: ([^\n]+)" _chunk_your_tools_host_match "${_chunk_your_tools_rustc_vv}")
    set(CHUNK_YOUR_TOOLS_RUST_TARGET "${CMAKE_MATCH_1}")
endif()

set(_chunk_your_tools_supported_targets
    x86_64-unknown-linux-gnu
    aarch64-unknown-linux-gnu
    x86_64-apple-darwin
    aarch64-apple-darwin
    x86_64-pc-windows-msvc
    aarch64-pc-windows-msvc
)
list(FIND _chunk_your_tools_supported_targets "${CHUNK_YOUR_TOOLS_RUST_TARGET}" _chunk_your_tools_target_idx)
if(_chunk_your_tools_target_idx EQUAL -1)
    message(FATAL_ERROR "CHUNK_YOUR_TOOLS_RUST_TARGET must be one of the supported triplets, got: ${CHUNK_YOUR_TOOLS_RUST_TARGET}")
endif()

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(CHUNK_YOUR_TOOLS_LIB_PROFILE debug)
else()
    set(CHUNK_YOUR_TOOLS_LIB_PROFILE release)
endif()

if(DEFINED ENV{CARGO_TARGET_DIR} AND NOT "$ENV{CARGO_TARGET_DIR}" STREQUAL "")
    set(CHUNK_YOUR_TOOLS_TARGET_DIR "$ENV{CARGO_TARGET_DIR}")
else()
    set(CHUNK_YOUR_TOOLS_TARGET_DIR "${CHUNK_YOUR_TOOLS_REPO_ROOT}/target")
endif()

set(CHUNK_YOUR_TOOLS_ARTIFACT_DIR "${CHUNK_YOUR_TOOLS_TARGET_DIR}/${CHUNK_YOUR_TOOLS_RUST_TARGET}/${CHUNK_YOUR_TOOLS_LIB_PROFILE}")

if(CHUNK_YOUR_TOOLS_LIB_PROFILE STREQUAL "debug")
    set(_chunk_your_tools_build_profile_flag --debug)
else()
    set(_chunk_your_tools_build_profile_flag --release)
endif()

if(WIN32)
    set(CHUNK_YOUR_TOOLS_SHARED_LIB "${CHUNK_YOUR_TOOLS_ARTIFACT_DIR}/chunk_your_tools.dll")
    set(CHUNK_YOUR_TOOLS_IMPORT_LIB "${CHUNK_YOUR_TOOLS_ARTIFACT_DIR}/chunk_your_tools.dll.lib")
    set(CHUNK_YOUR_TOOLS_STATIC_LIB "${CHUNK_YOUR_TOOLS_ARTIFACT_DIR}/chunk_your_tools.lib")
else()
    if(APPLE)
        set(CHUNK_YOUR_TOOLS_SHARED_LIB "${CHUNK_YOUR_TOOLS_ARTIFACT_DIR}/libchunk_your_tools.dylib")
    else()
        set(CHUNK_YOUR_TOOLS_SHARED_LIB "${CHUNK_YOUR_TOOLS_ARTIFACT_DIR}/libchunk_your_tools.so")
    endif()
    set(CHUNK_YOUR_TOOLS_STATIC_LIB "${CHUNK_YOUR_TOOLS_ARTIFACT_DIR}/libchunk_your_tools.a")
endif()

add_custom_command(
    OUTPUT "${CHUNK_YOUR_TOOLS_SHARED_LIB}"
    COMMAND bash "${CHUNK_YOUR_TOOLS_BUILD_SCRIPT}" --target "${CHUNK_YOUR_TOOLS_RUST_TARGET}" ${_chunk_your_tools_build_profile_flag}
    WORKING_DIRECTORY "${CHUNK_YOUR_TOOLS_REPO_ROOT}"
    COMMENT "Building chunk-your-tools ffi for ${CHUNK_YOUR_TOOLS_RUST_TARGET}"
    VERBATIM
)

add_custom_target(chunk_your_tools_build DEPENDS "${CHUNK_YOUR_TOOLS_SHARED_LIB}")

if(CHUNK_YOUR_TOOLS_BUILD_SHARED)
    add_library(chunk_your_tools SHARED IMPORTED GLOBAL)
    set_target_properties(chunk_your_tools PROPERTIES
        IMPORTED_LOCATION "${CHUNK_YOUR_TOOLS_SHARED_LIB}"
        INTERFACE_INCLUDE_DIRECTORIES "${CHUNK_YOUR_TOOLS_INCLUDE_DIR}"
    )
    if(WIN32)
        set_target_properties(chunk_your_tools PROPERTIES
            IMPORTED_IMPLIB "${CHUNK_YOUR_TOOLS_IMPORT_LIB}"
        )
    endif()
    add_dependencies(chunk_your_tools chunk_your_tools_build)
    add_library(ChunkYourTools::chunk_your_tools ALIAS chunk_your_tools)
endif()

if(CHUNK_YOUR_TOOLS_BUILD_STATIC)
    add_library(chunk_your_tools_static STATIC IMPORTED GLOBAL)
    set_target_properties(chunk_your_tools_static PROPERTIES
        IMPORTED_LOCATION "${CHUNK_YOUR_TOOLS_STATIC_LIB}"
        INTERFACE_INCLUDE_DIRECTORIES "${CHUNK_YOUR_TOOLS_INCLUDE_DIR}"
    )
    add_dependencies(chunk_your_tools_static chunk_your_tools_build)
    add_library(ChunkYourTools::chunk_your_tools_static ALIAS chunk_your_tools_static)
endif()

function(chunk_your_tools_add_example name source)
    add_executable("${name}" "${source}")
    target_include_directories("${name}" PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}"
        "${CHUNK_YOUR_TOOLS_INCLUDE_DIR}"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples")
    target_link_libraries("${name}" PRIVATE ChunkYourTools::chunk_your_tools)
    add_dependencies("${name}" chunk_your_tools_build)
    if(WIN32)
        add_custom_command(TARGET "${name}" POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CHUNK_YOUR_TOOLS_SHARED_LIB}" "$<TARGET_FILE_DIR:${name}>"
            COMMENT "Copy chunk_your_tools.dll beside ${name}"
        )
    endif()
endfunction()

if(CHUNK_YOUR_TOOLS_BUILD_EXAMPLES)
    enable_testing()
    chunk_your_tools_add_example(chunk_your_tools_example_basic examples/basic.c)
    chunk_your_tools_add_example(chunk_your_tools_example_error_handling examples/error_handling.c)
    chunk_your_tools_add_example(chunk_your_tools_example_retrieve examples/retrieve.c)
    chunk_your_tools_add_example(chunk_your_tools_example_policies examples/policies.c)

    add_test(NAME chunk_your_tools_basic COMMAND chunk_your_tools_example_basic)
    add_test(NAME chunk_your_tools_error_handling COMMAND chunk_your_tools_example_error_handling)
    add_test(NAME chunk_your_tools_retrieve COMMAND chunk_your_tools_example_retrieve)
    add_test(NAME chunk_your_tools_policies COMMAND chunk_your_tools_example_policies)
endif()

include(GNUInstallDirs)

if(CHUNK_YOUR_TOOLS_INSTALL)
    install(FILES "${CHUNK_YOUR_TOOLS_INCLUDE_DIR}/chunk_your_tools.h"
        DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/chunk"
    )
    if(CHUNK_YOUR_TOOLS_BUILD_SHARED)
        install(FILES "${CHUNK_YOUR_TOOLS_SHARED_LIB}"
            DESTINATION "${CMAKE_INSTALL_LIBDIR}/${CHUNK_YOUR_TOOLS_RUST_TARGET}"
        )
        if(WIN32)
            install(FILES "${CHUNK_YOUR_TOOLS_IMPORT_LIB}"
                DESTINATION "${CMAKE_INSTALL_LIBDIR}/${CHUNK_YOUR_TOOLS_RUST_TARGET}"
            )
        endif()
    endif()
    if(CHUNK_YOUR_TOOLS_BUILD_STATIC)
        install(FILES "${CHUNK_YOUR_TOOLS_STATIC_LIB}"
            DESTINATION "${CMAKE_INSTALL_LIBDIR}/${CHUNK_YOUR_TOOLS_RUST_TARGET}"
        )
    endif()

    include(CMakePackageConfigHelpers)
    configure_package_config_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/cmake/ChunkYourToolsConfig.cmake.in"
        "${CMAKE_CURRENT_BINARY_DIR}/ChunkYourToolsConfig.cmake"
        INSTALL_DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/ChunkYourTools"
        PATH_VARS CHUNK_YOUR_TOOLS_TARGET_DIR CHUNK_YOUR_TOOLS_INCLUDE_DIR
    )
    write_basic_package_version_file(
        "${CMAKE_CURRENT_BINARY_DIR}/ChunkYourToolsConfigVersion.cmake"
        VERSION "${PROJECT_VERSION}"
        COMPATIBILITY SameMajorVersion
    )
    install(FILES
        "${CMAKE_CURRENT_BINARY_DIR}/ChunkYourToolsConfig.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/ChunkYourToolsConfigVersion.cmake"
        DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/ChunkYourTools"
    )
endif()
