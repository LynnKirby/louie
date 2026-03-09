cmake_minimum_required(VERSION 3.30)

project(louie LANGUAGES C)

option(LOUIE_ENABLE_WARNINGS "Enable compiler warnings"  FALSE)
option(LOUIE_ENABLE_ASAN "Enable Address Sanitizer" FALSE)
option(LOUIE_ENABLE_UBSAN "Enable Undefined Behavior Sanitizer" FALSE)

option(LOUIE_BUILD_TESTS "Build tests by default" FALSE)
option(LOUIE_BUILD_FUZZERS "Build fuzzers by default" FALSE)

option(LOUIE_INCLUDE_TESTS "Include tests in the build system" ${PROJECT_IS_TOP_LEVEL})
option(LOUIE_INCLUDE_FUZZERS "Include fuzzers in the build system" ${PROJECT_IS_TOP_LEVEL})

find_program(
    YACC_EXECUTABLE
    NAMES byacc bison
    REQUIRED
)

#
# Options interface library
#

add_library(louie-options INTERFACE)

function(add_louie_options name)
    target_link_libraries("${name}" PRIVATE louie-options)

    set_target_properties(
        "${name}"
        PROPERTIES
            C_EXTENSIONS FALSE
            CXX_EXTENSIONS FALSE
    )
endfunction()

target_compile_options(
    louie-options
    INTERFACE
        "$<$<BOOL:${LOUIE_ENABLE_WARNINGS}>:-Wall;-Wextra;-pedantic>"
        "$<$<BOOL:${LOUIE_ENABLE_ASAN}>:-fsanitize=address>"
        "$<$<BOOL:${LOUIE_ENABLE_UBSAN}>:-fsanitize=undefined>"
)

target_link_options(
    louie-options
    INTERFACE
        "$<$<BOOL:${LOUIE_ENABLE_ASAN}>:-fsanitize=address>"
        "$<$<BOOL:${LOUIE_ENABLE_UBSAN}>:-fsanitize=undefined>"
)

target_compile_features(louie-options INTERFACE c_std_99)
target_include_directories(louie-options INTERFACE .)

#
# Source list
#

set(
    sources
        src/base/arena.c
        src/ast/ast.c
        src/ast/ast_dump.c
        src/ast/ast_construct.c
        src/interpreter/eval.c
        src/parsing/parse.tab.c
)

#
# Parser
#

add_custom_command(
    OUTPUT src/parsing/parse.tab.c
    BYPRODUCTS src/parsing/parse.output
    MAIN_DEPENDENCY src/parsing/parse.y
    COMMAND
        "${YACC_EXECUTABLE}"
        -v
        -b src/parsing/parse
        "${CMAKE_CURRENT_SOURCE_DIR}/src/parsing/parse.y"
)

#
# Main executable
#

add_library(louie-objects OBJECT ${sources})
add_louie_options(louie-objects)

add_executable(louie src/launcher/main.c)
target_link_libraries(louie PRIVATE louie-objects)
add_louie_options(louie)

#
# Tests
#

if(LOUIE_INCLUDE_TESTS)
    include(CTest)

    add_executable(arena_test src/base/arena_test.c)
    add_louie_options(arena_test)
    target_link_libraries(arena_test PRIVATE louie-objects)

    add_test(NAME arena COMMAND arena_test)

    if(NOT LOUIE_BUILD_TESTS)
        set_target_properties(
            arena_test
            PROPERTIES
                EXCLUDE_FROM_ALL TRUE
        )
    endif()
endif()

#
# Fuzzers
#

if(LOUIE_INCLUDE_FUZZERS)
    add_library(louie-fuzzer-objects OBJECT ${sources})
    add_louie_options(louie-fuzzer-objects)
    target_compile_options(louie-fuzzer-objects PUBLIC -fsanitize=fuzzer)
    target_link_options(louie-fuzzer-objects PUBLIC -fsanitize=fuzzer)

    if(NOT LOUIE_BUILD_FUZZERS)
        set_target_properties(
            louie-fuzzer-objects
            PROPERTIES EXCLUDE_FROM_ALL TRUE
        )
    endif()

    function(louie_add_fuzzer name)
        add_executable("${name}" ${ARGN})
        add_louie_options("${name}")
        target_link_libraries("${name}" PRIVATE louie-fuzzer-objects)

        if(NOT LOUIE_BUILD_FUZZERS)
            set_target_properties(
                "${name}"
                PROPERTIES EXCLUDE_FROM_ALL TRUE
            )
        endif()
    endfunction()

    louie_add_fuzzer(parse_fuzz src/parsing/parse_fuzz.c)
endif()
