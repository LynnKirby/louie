cmake_minimum_required(VERSION 3.30)

project(louie LANGUAGES C)

option(LOUIE_ENABLE_WARNINGS ""  TRUE)
option(LOUIE_ENABLE_ASAN "" FALSE)
option(LOUIE_ENABLE_UBSAN "" FALSE)

include(CTest)

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

add_executable(
    louie
        src/main.c
        src/arena.c
)

add_louie_options(louie)

#
# Tests
#

add_executable(
    arena_test
        src/arena_test.c
        src/arena.c
)

add_louie_options(arena_test)
add_test(NAME arena COMMAND arena_test)
