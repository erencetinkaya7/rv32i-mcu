#!/usr/bin/env python3
"""Read the board UART with one reader and bounded optional capture."""
import argparse
import time
import sys
import serial

parser = argparse.ArgumentParser()
parser.add_argument('--port', default='/dev/ttyUSB1')
parser.add_argument('--baud', type=int, default=115200)
parser.add_argument('--seconds', type=float, default=0)
args = parser.parse_args()
if args.seconds < 0:
    parser.error("--seconds must be zero or positive")
try:
    with serial.Serial(args.port, args.baud, timeout=0.2, exclusive=True,
                       xonxoff=False, rtscts=False, dsrdtr=False) as port:
        print(f'UART READY: {port.name}, {port.baudrate} baud. Press board reset. Ctrl+C exits.', flush=True)
        started = time.monotonic()
        count = 0
        while not args.seconds or time.monotonic() - started < args.seconds:
            data = port.read(max(1, port.in_waiting))
            if data:
                count += len(data)
                print(data.decode('ascii', errors='backslashreplace'), end='', flush=True)
        print(f'\nCaptured {count} bytes.', flush=True)
except KeyboardInterrupt:
    print('\nUART closed.')

except serial.SerialException as error:
    sys.exit(f"UART error: {error}\nCheck UART_PORT, close other monitors, and check dialout permissions.")
