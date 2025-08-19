FP_CRESET=17
FP_CDONE=23
PR_CS=8
FL_RESET=6

SPI_DEV=/dev/spidev0.0

# Usage: a bitstream argument is necessary
if [ $# -ne 1 ]; then
	echo "usage: $0 <bitstream.bin>"
	exit 1
fi

# Find the first usable GPIO chip 
GPIO_CHIP=$(gpiofind GPIO${FL_RESET} | cut -d ' ' -f1)
if [ -z $GPIO_CHIP ]; then
	echo "Cannot find line for GPIO${FL_RESET}"
	exit 1
fi

# This is important so that the FPGA knows it's going to operate in SPI-peripheral mode
echo "Stop driving the PR_CS signal (there's a pull-up in the board)"
gpioget ${GPIO_CHIP} ${PR_CS}
sleep 1

# Initiates the flash configuration (FP_CRESET is really the CRESET input in the FPGA)
echo "Set FPGA reset low (active)"
gpioset ${GPIO_CHIP} ${FP_CRESET}=0
sleep 1

# Resets the flash (not used if we are configuring the FPGA rather than the flash)
echo "Set Flash reset low (active), then stop driving the signal (there's a pull-up in the board)"
gpioset ${GPIO_CHIP} ${FL_RESET}=0
sleep 1
gpioget ${GPIO_CHIP} ${FL_RESET}
sleep 1

TMPBIN=filled.bin
dd if=/dev/zero bs=1081344 count=1 of=${TMPBIN}
# dd if=/dev/zero bs=1048576 count=1 of=${TMPBIN}
#dd if=/dev/zero bs=2162688 count=1 of=${TMPBIN}
#dd if=/dev/zero bs=2097152 count=1 of=${TMPBIN}
dd if=$1 of=${TMPBIN} conv=notrunc
~/flashrom/builddir/flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=1000 -c AT45DB081E --write ${TMPBIN}
#python spi_flash_write.py --page-size 264 ${TMPBIN}
rm -f ${TMPBIN}

# Finishes the flash configuration
echo "Set FPGA reset high (inactive), then stop driving the signal (there's a pull-up in the board)"
gpioset ${GPIO_CHIP} ${FP_CRESET}=1
sleep 1
gpioget ${GPIO_CHIP} ${FP_CRESET}
sleep 1
