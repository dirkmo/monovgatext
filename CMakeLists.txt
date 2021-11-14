cmake_minimum_required(VERSION 3.8)

project(MonoVgaTextSim)

find_package(verilator HINTS $ENV{VERILATOR_ROOT} ${VERILATOR_ROOT})
if (NOT verilator_FOUND)
  message(FATAL_ERROR "Verilator was not found. Either install it, or set the VERILATOR_ROOT environment variable")
endif()

set(CMAKE_BUILD_TYPE DEBUG)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS}-O0 -g")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O0 -g")

# Create a new executable target that will contain all your sources
add_executable(
  simulation
  sim/sim.cpp
  sim/vga.cpp
  sim/IBM_VGA_8x16.c
  sim/uart.cpp
)

find_package(SDL2 REQUIRED)
include_directories(${SDL2_INCLUDE_DIRS})
target_link_libraries(simulation PRIVATE ${SDL2_LIBRARIES})

# Add the Verilated circuit to the target
verilate(simulation TRACE
  INCLUDE_DIRS "sim/"
  VERILATOR_ARGS -CFLAGS "-g" -trace -O0 -x-assign 0 +define+SIM=1 +librescan +libext+.v -y rtl/ --top-module top
  SOURCES fpga/top.v
          fpga/memory.v
          rtl/MasterShell.v
          rtl/MonoVgaText.v
          rtl/import/UartMasterSlave.v
          rtl/import/uart_rx.v
          rtl/import/uart_tx.v
          rtl/import/UartProtocol.v
          rtl/import/fifo.v
)
