#!/usr/bin/env python3

import time
import spidev
import gpiod
import sys
import os

from gpiod.line import Direction, Value

SPI_BUS = 0
SPI_DEVICE = 0
CRESET_PIN = 17         # GPIO 17 connected to CRESET_B
PR_CS_PIN = 5           # GPIO 5 connected to PR_CS
SPI_SPEED = 500000      # 5 MHz

CHIP_NAME = "/dev/gpiochip0"

def main():
    if len(sys.argv) < 2:
        print("Usage: sudo ./spi_volatile_programmer.py <bitstream.bin>")
        sys.exit(1)

    bitstream_path = sys.argv[1]

    if not os.path.exists(bitstream_path):
        print(f"[!] File not found: {bitstream_path}")
        sys.exit(1)

    with open(bitstream_path, "rb") as f:
        bitstream_data = f.read()

    if len(bitstream_data) == 0:
        print("[!] Bitstream file is empty!")
        sys.exit(1)

    # Setup GPIO
    print("[*] Setting up GPIO")
    chip = gpiod.Chip(CHIP_NAME)

    configuration = {
        PR_CS_PIN: gpiod.LineSettings(direction=Direction.OUTPUT, output_value=Value.ACTIVE),
        CRESET_PIN: gpiod.LineSettings(direction=Direction.OUTPUT, output_value=Value.ACTIVE)
    }

    request = gpiod.request_lines("/dev/gpiochip0",
                         config=configuration,
                         consumer="spi_volatile_programmer"
    )

    # Setup SPI
    print("[*] Setting up SPI")
    spi = spidev.SpiDev()
    spi.open(SPI_BUS, SPI_DEVICE)
    spi.mode = 0b00  # CPOL=0, CPHA=0
    spi.max_speed_hz = SPI_SPEED

    try:
        print("[*] Setting SPI Peripheral mode")
        time.sleep(0.2)
        request.set_value(PR_CS_PIN, Value.INACTIVE)
        request.set_value(CRESET_PIN, Value.INACTIVE)
        time.sleep(0.2)

        request.set_value(CRESET_PIN, Value.ACTIVE)
        time.sleep(0.2)

        print("[*] Sending bitstream (%d bytes)..." % len(bitstream_data))

        # Send 8 dummy bytes
        request.set_value(PR_CS_PIN, Value.ACTIVE)
        spi.xfer2([0x00] * 8)
        request.set_value(PR_CS_PIN, Value.INACTIVE)

        # Send bitstream
        for i in range(0, len(bitstream_data), 512):
            spi.xfer2(bitstream_data[i:i+512])
        request.set_value(PR_CS_PIN, Value.ACTIVE)

        # Wait for CDONE
        spi.xfer2([0x00] * 13)

        # Send some trailing clocks (minimum ~49 required)
        spi.xfer2([0x00] * 7)

        print("done")
    except Exception as e:
        print(f"[!] Error: {e}")
    finally:
        spi.close()
        request.release()
        chip.close()

if __name__ == "__main__":
    main()
