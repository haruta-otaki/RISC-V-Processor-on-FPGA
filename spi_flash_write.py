#!/usr/bin/env python3

import spidev
import sys
import time
import os

PAGE_SIZE = 256
TOTAL_SIZE = 1024 * 1024  # 1 MiB

STATUS_REG_CMD = 0xD7
WRITE_PAGE_CMD = 0x82
READ_ID_CMD = 0x9F
DISABLE_PROTECT_CMD = [0x3D, 0x2A, 0x7F, 0xA9]
SET_BINARY_PAGE_CMD = [0x3D, 0x2A, 0x80, 0xA6]

def wait_ready(spi):
    while True:
        status = spi.xfer2([STATUS_REG_CMD])[0]
        if status & 0x80:
            break
        time.sleep(0.01)

def disable_write_protect(spi):
    print("Disabling sector protection...")
    spi.xfer2(DISABLE_PROTECT_CMD)
    wait_ready(spi)

def set_page_size_binary(spi):
    print("Sending Binary Page Size Program command...")
    spi.xfer2(SET_BINARY_PAGE_CMD)
    wait_ready(spi)
    print("Binary page size command sent. You MUST power-cycle the chip now for the change to take effect!")
    input("Press Enter AFTER power-cycling to continue...")

def program_page(spi, page_addr, data):
    assert len(data) == PAGE_SIZE
    addr_bytes = [(page_addr >> 16) & 0xFF, (page_addr >> 8) & 0xFF, page_addr & 0xFF]
    cmd = [WRITE_PAGE_CMD] + addr_bytes + list(data)
    spi.xfer2(cmd)
    wait_ready(spi)

def read_chip_id(spi):
    id_data = spi.xfer2([READ_ID_CMD, 0x00, 0x00, 0x00])
    return id_data

def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <binary_file>")
        sys.exit(1)

    filename = sys.argv[1]
    if not os.path.isfile(filename):
        print(f"File not found: {filename}")
        sys.exit(1)

    # Pad file to full 1MB
    with open(filename, 'rb') as f:
        content = f.read()
    if len(content) > TOTAL_SIZE:
        print("Error: File too large (must be <= 1MB)")
        sys.exit(1)
    content += b'\xFF' * (TOTAL_SIZE - len(content))

    spi = spidev.SpiDev()
    spi.open(0, 0)  # Use SPI0.0 (adjust as needed)
    spi.max_speed_hz = 1000000
    spi.mode = 0

    chip_id = read_chip_id(spi)
    print(f"Chip ID: {chip_id}")

    set_page_size_binary(spi)
    disable_write_protect(spi)

    print("Programming...")
    for page in range(0, TOTAL_SIZE, PAGE_SIZE):
        page_data = content[page:page+PAGE_SIZE]
        program_page(spi, page, page_data)
        print(f"Wrote page {page // PAGE_SIZE:04X}", end='\r')

    print("\nDone.")
    spi.close()

if __name__ == '__main__':
    main()
