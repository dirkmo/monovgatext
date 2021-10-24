cmake_minimum_required(VERSION 3.8)

project(MonoVgaTextSim)

find_package(verilator HINTS $ENV{VERILATOR_ROOT} ${VERILATOR_ROOT})
if (NOT verilator_FOUND)
  message(FATAL_ERROR "Verilator was not found. Either install it, or set the VERILATOR_ROOT environment variable")
endif()

# Create a new executable target that will contain all your sources
add_executable(simulation sim/sim.cpp sim/vga.cpp sim/IBM_VGA_8x16.c)

find_package(SDL2 REQUIRED)
include_directories(${SDL2_INCLUDE_DIRS})
target_link_libraries(simulation PRIVATE ${SDL2_LIBRARIES})

# Add the Verilated circuit to the target
verilate(simulation COVERAGE TRACE
  INCLUDE_DIRS "sim/"
  VERILATOR_ARGS -O0 -x-assign 0 +librescan +libext+.v -y rtl/
  SOURCES rtl/MonoVgaText.v)
