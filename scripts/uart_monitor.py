#!/usr/bin/env python3
"""Interactive UART terminal with optional bounded capture."""
import argparse
import os
import select
import sys
import termios
import time
import tty

import serial

parser = argparse.ArgumentParser()
parser.add_argument('--port', default='/dev/ttyUSB1')
parser.add_argument('--baud', type=int, default=115200)
parser.add_argument('--seconds', type=float, default=0)
args = parser.parse_args()

if args.seconds < 0:
    parser.error("--seconds must be zero or positive")

terminal_settings = None

try:
    with serial.Serial(args.port, args.baud, timeout=0, exclusive=True,
                       xonxoff=False, rtscts=False, dsrdtr=False) as port:
        interactive = sys.stdin.isatty()

        if interactive:
            terminal_settings = termios.tcgetattr(sys.stdin.fileno())
            tty.setcbreak(sys.stdin.fileno())

        print(
            f'UART READY: {port.name}, {port.baudrate} baud. '
            'Type to send. Press board reset. Ctrl+C exits.',
            flush=True,
        )

        started = time.monotonic()
        count = 0

        try:
            while not args.seconds or time.monotonic() - started < args.seconds:
                inputs = [port]
                if interactive:
                    inputs.append(sys.stdin)

                readable, _, _ = select.select(inputs, [], [], 0.05)

                if port in readable:
                    data = port.read(max(1, port.in_waiting))
                    if data:
                        count += len(data)
                        print(
                            data.decode('ascii', errors='backslashreplace'),
                            end='',
                            flush=True,
                        )

                if interactive and sys.stdin in readable:
                    data = os.read(sys.stdin.fileno(), 1)
                    if data:
                        port.write(data)
        finally:
            if terminal_settings is not None:
                termios.tcsetattr(
                    sys.stdin.fileno(), termios.TCSADRAIN, terminal_settings
                )

        print(f'\nCaptured {count} bytes.', flush=True)

except KeyboardInterrupt:
    print('\nUART closed.')
except serial.SerialException as error:
    sys.exit(
        f"UART error: {error}\n"
        "Check UART_PORT, close other monitors, and check dialout permissions."
    )
