.PHONY: all clean sim wave iverilog

UNAME := $(shell uname -s)

VERILATOR_OUTPUTDIR = verilator

INCDIR=-I$(VERILATOR_OUTPUTDIR) -I/usr/share/verilator/include

DEFINES=+define+SIM=1

VFLAGS = --cc -CFLAGS "$(CXXFLAGS)" -LDFLAGS "$(LDFLAGS)" -trace --exe $(INCDIR) --Mdir $(VERILATOR_OUTPUTDIR) $(DEFINES) -O0
GTKWAVE := gtkwave
ifeq ($(UNAME),Darwin)
VFLAGS += --compiler clang
GTKWAVE := /Applications/gtkwave.app/Contents/MacOS/gtkwave-bin
endif

CXXFLAGS=-g -Wall
LDFLAGS=-lSDL2

CXXFLAGS += -DTRACE_ON

CPPSRC=sim.cpp IBM_VGA_8x16.c vga.cpp
VERILOGSRC=MonoVgaText.v

all: top

verilator: $(CPPSRC) $(VERILOGSRC)
	verilator $(VFLAGS) $(VERILOGSRC) $(CPPSRC)

top: verilator
	make OPT_FAST="" -C $(VERILATOR_OUTPUTDIR) -j -f VMonoVgaText.mk

sim: top
	$(VERILATOR_OUTPUTDIR)/VMonoVgaText -d -t

wave: sim
	gtkwave sim.gtkw &

iverilog:
	iverilog MonoVgaText.v

clean:
	rm -f trace.vcd a.out
	rm -f $(VERILATOR_OUTPUTDIR)/*
	-rm -r $(VERILATOR_OUTPUTDIR)

