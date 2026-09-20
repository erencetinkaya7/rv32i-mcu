"""Convert a binary file into a padded 32-bit little-endian memory image."""

import argparse
from pathlib import Path


def parse_word(value):
    return int(value, 0)


parser = argparse.ArgumentParser()
parser.add_argument("source", type=Path)
parser.add_argument("destination", type=Path)
parser.add_argument("--words", type=int, required=True)
parser.add_argument("--fill", type=parse_word, default=0)
parser.add_argument("--strict-word-alignment", action="store_true")
args = parser.parse_args()

data = args.source.read_bytes()
capacity = args.words * 4

if len(data) > capacity:
    raise SystemExit(
        f"{args.source} is {len(data)} bytes; memory holds only {capacity} bytes."
    )

if args.strict_word_alignment and len(data) % 4:
    raise SystemExit("Instruction image size must be a multiple of four bytes.")

# Constant data such as strings may not end on a four-byte boundary.
data += bytes((-len(data)) % 4)

words = [
    int.from_bytes(data[index:index + 4], "little")
    for index in range(0, len(data), 4)
]

words += [args.fill] * (args.words - len(words))

image = "".join(f"{word:08x}\n" for word in words)

if not args.destination.exists() or args.destination.read_text() != image:
    args.destination.write_text(image)
