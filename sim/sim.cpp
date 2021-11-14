#include <stdint.h>
#include <string.h>
#include <verilated_vcd_c.h>
#include "verilated.h"
#include "Vtop.h"
#include "Vtop_top.h"
#include "Vtop_MasterShell.h"
#include "Vtop_MonoVgaText.h"

#include "IBM_VGA_8x16.h"
#include "vga.h"
#include "uart.h"


using namespace std;

VerilatedVcdC *pTrace = NULL;
Vtop *pCore;

uint64_t tickcount = 0;
uint64_t ts = 1000;

void opentrace(const char *vcdname) {
    if (!pTrace) {
        pTrace = new VerilatedVcdC;
        pCore->trace(pTrace, 99);
        pTrace->open(vcdname);
    }
}

void tick() {
    tickcount += ts;
    if ((tickcount % (ts)) == 0) {
        pCore->clk100mhz = !pCore->clk100mhz;
    }
    pCore->eval();
    if(pTrace) pTrace->dump(static_cast<vluint64_t>(tickcount));
}

void fasttick() {
    pCore->eval();
    tickcount += ts;
    pCore->clk100mhz = 0;
    pCore->eval();
    tickcount += ts;
    pCore->clk100mhz = 1;
    pCore->eval();
    pCore->clk100mhz = 0;
    pCore->eval();
    if(pTrace) pTrace->dump(static_cast<vluint64_t>(tickcount));
}

void reset() {
    pCore->reset_n = 0;
    for ( int i = 0; i < 20; i++) {
        tick();
    }
    pCore->reset_n = 1;
}

void handle(Vtop *pCore) {
    int rxbyte;
    if (uart_handle(&rxbyte)) {
        printf("UART: %c\n",rxbyte);
    }
}

int main(int argc, char *argv[]) {
    Verilated::traceEverOn(true);
    pCore = new Vtop();

    if (argc > 1) {
        if( string(argv[1]) == "-t" ) {
            printf("Trace enabled\n");
            opentrace("trace.vcd");
        }
    }    

    vga_init(
        pCore->top->master0->vga0->HSIZE, pCore->top->master0->vga0->HFP, pCore->top->master0->vga0->HSYNC, pCore->top->master0->vga0->HBP,
        pCore->top->master0->vga0->VSIZE, pCore->top->master0->vga0->VFP, pCore->top->master0->vga0->VSYNC, pCore->top->master0->vga0->VBP
    );

    uart_init(
        &pCore->uart_rx, &pCore->uart_tx, &pCore->top->clk25mhz,
        25000000/115200
    );

    reset();

    // uart_send("L0001W1424344454RR");

    while(1) {
        static int old_clk = -1;
        tick();
        handle(pCore);

        if (pCore->top->clk25mhz != old_clk) {
            if (pCore->top->clk25mhz) {
                int ret = vga_handle(pCore->red&1, !pCore->hsync, !pCore->vsync);
                if (ret == -1) {
                    break;
                }
            }
        }
        old_clk = pCore->top->clk25mhz;

        // if (pCore->MasterShell->y == 32) {
        //     printf("Ende\n");
        //     vga_wait_keypress();
        //     break;
        // }
    }

    vga_close();

    if (pTrace) {
        pTrace->close();
        delete pTrace;
    }

    return 0;
}
