#!/bin/bash

set -e

mkdir -p rtl/import

wget -c -P rtl/import https://raw.githubusercontent.com/dirkmo/uartmaster/16bit/rtl/uart_rx.v
wget -c -P rtl/import https://raw.githubusercontent.com/dirkmo/uartmaster/16bit/rtl/uart_tx.v
wget -c -P rtl/import https://raw.githubusercontent.com/dirkmo/uartmaster/16bit/rtl/UartMasterSlave.v
wget -c -P rtl/import https://raw.githubusercontent.com/dirkmo/uartmaster/16bit/rtl/fifo.v
wget -c -P rtl/import https://raw.githubusercontent.com/dirkmo/uartmaster/16bit/rtl/UartProtocol.v
