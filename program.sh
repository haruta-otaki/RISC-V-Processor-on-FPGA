# The 2057-ICE40HX4K-TQ144-breakout Rev 3.0 is connected to the Pi like this:
#
# Pi function	Signal
#
# GPIO23		CDONE
# GPIO24		CRESET*
# SPI_MOSI		FPGA_SDI
# SPI_MISO		FPGA_SDO
# SPI_SCK		FPGA_SCK
# GPIO12		FPGA_SS		(special case for booting)
# SPI_CE0		FPGA_CE0	(special case not used for booting)
# GPIO16		FRESET		(used to reset the flash)
#
# NOTE: The sysfs GPIO access system has been depreciated for Raspberry Pi OS Bookworm
#       so using the recommended gpiod system here.

CRESET=24
CDONE=23
SSEL=12
FRESET=16

SPI_DEV=/dev/spidev0.0

######################################

if [ $# -ne 1 ]; then
	echo "usage: $0 output.bin"
	exit 1
fi

######################################

GPIO_CHIP=$(gpiofind GPIO${SSEL} | cut -d ' ' -f1)
if [ -z $GPIO_CHIP ]; then
	echo "Cannot find GPIO${SSEL} interface"
	exit 1
else
	echo "OK: ${GPIO_CHIP} found"
fi

######################################
#
# Float the SSEL pin at this point so that it won't mess 
# with the FPGA's ability to boot from flash!
echo "Changing SSEL to an input so is not driven by the Pi"
gpioget ${GPIO_CHIP} ${SSEL}

######################################
echo "Set FPGA reset low"
gpioset ${GPIO_CHIP} ${CRESET}=0
sleep 1

######################################
echo "Reset the flash, then float the signal"
gpioset ${GPIO_CHIP} ${FRESET}=0
sleep 1
gpioget ${GPIO_CHIP} ${FRESET}

######################################
# Program the FLASH
#
# AT45DB081 1081344 (264-byte page mode)
# AT45DB081 1048576 (256-byte page mode)
# AT45DB161D 2162688 (528-byte page mode)
# AT45DB161D 2097152 (512-byte page mode)
TMPBIN=$$.bin
#dd if=/dev/zero bs=1081344 count=1 of=${TMPBIN}
dd if=/dev/zero bs=1048576 count=1 of=${TMPBIN}
#dd if=/dev/zero bs=2162688 count=1 of=${TMPBIN}
#dd if=/dev/zero bs=2097152 count=1 of=${TMPBIN}
dd if=$1 of=${TMPBIN} conv=notrunc
flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=8000 --write ${TMPBIN}
rm -f ${TMPBIN}

######################################

echo "Disable FPGA reset, float the signal"

gpioset ${GPIO_CHIP} ${CRESET}=1
sleep 1
gpioget ${GPIO_CHIP} ${CRESET}
sleep 1
