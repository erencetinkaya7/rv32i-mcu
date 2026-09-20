#ifndef MMIO_H
#define MMIO_H

#include <stdint.h>

// Read or write one 32-bit memory-mapped register.
#define MMIO32(address) (*(volatile uint32_t *)(uintptr_t)(address))

#define GPIO_OUT_ADDR       0x10000000u
#define GPIO_IN_ADDR        0x10000004u

#define UART_TX_ADDR        0x20000000u
#define UART_STATUS_ADDR    0x20000004u
#define UART_RX_DATA_ADDR   0x20000008u
#define UART_RX_STATUS_ADDR 0x2000000Cu
#define UART_RX_CLEAR_ADDR  0x20000010u

#define TIMER_LOAD_ADDR     0x30000000u
#define TIMER_STATUS_ADDR   0x30000004u

#endif
