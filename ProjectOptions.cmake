include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(sample_cmake_project_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(sample_cmake_project_setup_options)
  option(sample_cmake_project_ENABLE_HARDENING "Enable hardening" ON)
  option(sample_cmake_project_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    sample_cmake_project_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    sample_cmake_project_ENABLE_HARDENING
    OFF)

  sample_cmake_project_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR sample_cmake_project_PACKAGING_MAINTAINER_MODE)
    option(sample_cmake_project_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(sample_cmake_project_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(sample_cmake_project_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(sample_cmake_project_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(sample_cmake_project_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(sample_cmake_project_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(sample_cmake_project_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(sample_cmake_project_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(sample_cmake_project_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(sample_cmake_project_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(sample_cmake_project_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(sample_cmake_project_ENABLE_PCH "Enable precompiled headers" OFF)
    option(sample_cmake_project_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(sample_cmake_project_ENABLE_IPO "Enable IPO/LTO" ON)
    option(sample_cmake_project_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(sample_cmake_project_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(sample_cmake_project_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(sample_cmake_project_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(sample_cmake_project_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(sample_cmake_project_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(sample_cmake_project_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(sample_cmake_project_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(sample_cmake_project_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(sample_cmake_project_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(sample_cmake_project_ENABLE_PCH "Enable precompiled headers" OFF)
    option(sample_cmake_project_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      sample_cmake_project_ENABLE_IPO
      sample_cmake_project_WARNINGS_AS_ERRORS
      sample_cmake_project_ENABLE_USER_LINKER
      sample_cmake_project_ENABLE_SANITIZER_ADDRESS
      sample_cmake_project_ENABLE_SANITIZER_LEAK
      sample_cmake_project_ENABLE_SANITIZER_UNDEFINED
      sample_cmake_project_ENABLE_SANITIZER_THREAD
      sample_cmake_project_ENABLE_SANITIZER_MEMORY
      sample_cmake_project_ENABLE_UNITY_BUILD
      sample_cmake_project_ENABLE_CLANG_TIDY
      sample_cmake_project_ENABLE_CPPCHECK
      sample_cmake_project_ENABLE_COVERAGE
      sample_cmake_project_ENABLE_PCH
      sample_cmake_project_ENABLE_CACHE)
  endif()

  sample_cmake_project_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (sample_cmake_project_ENABLE_SANITIZER_ADDRESS OR sample_cmake_project_ENABLE_SANITIZER_THREAD OR sample_cmake_project_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(sample_cmake_project_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(sample_cmake_project_global_options)
  if(sample_cmake_project_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    sample_cmake_project_enable_ipo()
  endif()

  sample_cmake_project_supports_sanitizers()

  if(sample_cmake_project_ENABLE_HARDENING AND sample_cmake_project_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR sample_cmake_project_ENABLE_SANITIZER_UNDEFINED
       OR sample_cmake_project_ENABLE_SANITIZER_ADDRESS
       OR sample_cmake_project_ENABLE_SANITIZER_THREAD
       OR sample_cmake_project_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${sample_cmake_project_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${sample_cmake_project_ENABLE_SANITIZER_UNDEFINED}")
    sample_cmake_project_enable_hardening(sample_cmake_project_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(sample_cmake_project_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(sample_cmake_project_warnings INTERFACE)
  add_library(sample_cmake_project_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  sample_cmake_project_set_project_warnings(
    sample_cmake_project_warnings
    ${sample_cmake_project_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(sample_cmake_project_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    sample_cmake_project_configure_linker(sample_cmake_project_options)
  endif()

  include(cmake/Sanitizers.cmake)
  sample_cmake_project_enable_sanitizers(
    sample_cmake_project_options
    ${sample_cmake_project_ENABLE_SANITIZER_ADDRESS}
    ${sample_cmake_project_ENABLE_SANITIZER_LEAK}
    ${sample_cmake_project_ENABLE_SANITIZER_UNDEFINED}
    ${sample_cmake_project_ENABLE_SANITIZER_THREAD}
    ${sample_cmake_project_ENABLE_SANITIZER_MEMORY})

  set_target_properties(sample_cmake_project_options PROPERTIES UNITY_BUILD ${sample_cmake_project_ENABLE_UNITY_BUILD})

  if(sample_cmake_project_ENABLE_PCH)
    target_precompile_headers(
      sample_cmake_project_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(sample_cmake_project_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    sample_cmake_project_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(sample_cmake_project_ENABLE_CLANG_TIDY)
    sample_cmake_project_enable_clang_tidy(sample_cmake_project_options ${sample_cmake_project_WARNINGS_AS_ERRORS})
  endif()

  if(sample_cmake_project_ENABLE_CPPCHECK)
    sample_cmake_project_enable_cppcheck(${sample_cmake_project_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(sample_cmake_project_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    sample_cmake_project_enable_coverage(sample_cmake_project_options)
  endif()

  if(sample_cmake_project_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(sample_cmake_project_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(sample_cmake_project_ENABLE_HARDENING AND NOT sample_cmake_project_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR sample_cmake_project_ENABLE_SANITIZER_UNDEFINED
       OR sample_cmake_project_ENABLE_SANITIZER_ADDRESS
       OR sample_cmake_project_ENABLE_SANITIZER_THREAD
       OR sample_cmake_project_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    sample_cmake_project_enable_hardening(sample_cmake_project_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
