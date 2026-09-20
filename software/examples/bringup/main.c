#include <stdint.h>
#include "mmio.h"

#ifndef TIMER_TICKS
#define TIMER_TICKS 1000u
#endif

#define MIN_TIMER_TICKS (TIMER_TICKS >> 2)
#define MAX_TIMER_TICKS (TIMER_TICKS << 2)


// Wait until UART is idle, then transmit one byte.
__attribute__((noinline))
static void uart_putc(uint8_t character)
{
    while ((MMIO32(UART_STATUS_ADDR) & 1u) != 0u) {
    }

    MMIO32(UART_TX_ADDR) = (uint32_t)character;
}

// Send a null-terminated string from data memory.
static void uart_puts(const char *text)
{
    while (*text != '\0') {
        uart_putc((uint8_t)*text);
        text++;
    }
}

// Return received byte, or -1 when no byte is ready.
static int uart_try_getc(void)
{
    uint32_t status = MMIO32(UART_RX_STATUS_ADDR);

    if ((status & 2u) != 0u) {
        MMIO32(UART_RX_CLEAR_ADDR) = 1u;
        return -1;
    }

    if ((status & 1u) == 0u) {
        return -1;
    }

    int character = (int)(MMIO32(UART_RX_DATA_ADDR) & 0xffu);

    MMIO32(UART_RX_CLEAR_ADDR) = 1u;
    return character;
}

static void uart_send_ready(void)
{
    uart_puts("C READY\n");
}

int main(void)
{
    uint32_t pattern = 1u;
    uint32_t paused = 0u;
    uint32_t timer_ticks = TIMER_TICKS;

    uart_send_ready();

    MMIO32(GPIO_OUT_ADDR) = pattern;
    MMIO32(TIMER_LOAD_ADDR) = timer_ticks;

    while (1) {
        int received = uart_try_getc();

        if (received == 'p') {
            if (paused == 0u) {
                paused = 1u;
                uart_puts("PAUSED\n");
            } else {
                paused = 0u;
                uart_puts("RUNNING\n");
            }
        } else if (received == 'r') {
            pattern = 1u;
            MMIO32(GPIO_OUT_ADDR) = pattern;
            uart_puts("RESET\n");
        } else if (received == '+') {
            if (timer_ticks > MIN_TIMER_TICKS) {
                timer_ticks = timer_ticks >> 1;
            }

            uart_puts("FASTER\n");
        } else if (received == '-') {
            if (timer_ticks < MAX_TIMER_TICKS) {
                timer_ticks = timer_ticks << 1;
            }

            uart_puts("SLOWER\n");
        } else if (received >= 0) {
            uart_putc((uint8_t)received);
        }

        if (((MMIO32(TIMER_STATUS_ADDR) & 1u) == 0u) &&
            (paused == 0u)) {
            if (pattern == 32u) {
                pattern = 1u;
            } else {
                pattern = pattern << 1;
            }

            MMIO32(GPIO_OUT_ADDR) = pattern;
            MMIO32(TIMER_LOAD_ADDR) = timer_ticks;
        }
    }
}
