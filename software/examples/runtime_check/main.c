#include <stdint.h>
#include "mmio.h"

// Initialized writable objects exercise word and byte copies.
static volatile uint32_t initial_value = 0x12345678u;
static volatile uint32_t values[3] = {7u, 0x89abcdefu, 42u};
static volatile uint8_t bytes[5] = {1u, 2u, 0x80u, 0xffu, 5u};

// Startup must clear these objects, including after a button reset.
static volatile uint32_t zero_value;
static volatile uint32_t zero_array[3];

static void fail(uint32_t code)
{
    MMIO32(GPIO_OUT_ADDR) = code;
    while (1) {
    }
}

// The timer is never started; any trap is unexpected in this test.
void machine_trap_handler(void)
{
    fail(0xe3u);
}

int main(void)
{
    if (initial_value != 0x12345678u ||
        values[0] != 7u || values[1] != 0x89abcdefu || values[2] != 42u ||
        bytes[0] != 1u || bytes[1] != 2u || bytes[2] != 0x80u ||
        bytes[3] != 0xffu || bytes[4] != 5u) {
        fail(0xe1u);
    }

    if (zero_value != 0u) {
        fail(0xe2u);
    }
    for (uint32_t i = 0; i < 3u; i++) {
        if (zero_array[i] != 0u) {
            fail(0xe2u);
        }
    }

    // Dirty every object so the next reset must restore it.
    initial_value = 99u;
    zero_value = 99u;
    for (uint32_t i = 0; i < 3u; i++) {
        values[i] = 99u;
        zero_array[i] = 99u;
    }
    for (uint32_t i = 0; i < 5u; i++) {
        bytes[i] = 99u;
    }

    // The testbench resets the CPU after seeing this completion code.
    MMIO32(GPIO_OUT_ADDR) = 1u;
    while (1) {
    }
}
