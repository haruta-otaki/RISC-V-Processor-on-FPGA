#include "uart.h"

#ifdef QEMU
    #define QEMU_IO_BASE     0x10000000UL
    #define QEMU_UART_TX     (* (volatile uint8_t *) (QEMU_IO_BASE + 0x00)) // RW goes in the same register
    #define QEMU_UART_RX     (* (volatile uint8_t *) (QEMU_IO_BASE + 0x00)) // RW goes in the same register
    #define QEMU_UART_STATUS (* (volatile uint8_t *) (QEMU_IO_BASE + 0x05)) // Line status

    #define QEMU_STATUS_RX_READY (1 << 0)
    #define QEMU_STATUS_TX_READY (1 << 5)

int _write(int fd, const void *buf, size_t n) {
    if(fd != STDOUT_FILENO && fd != STDERR_FILENO) {
#ifdef LIBC
        errno = EBADF;
#endif // LIBC

        return -1;
    }

    const uint8_t *p = buf;

    for(size_t i = 0; i < n; i++) {
        while((QEMU_UART_STATUS & QEMU_STATUS_TX_READY) == 0) {
            // spin!
        }

        QEMU_UART_TX = p[i];
    }

    return (int) n;
}

int _read(int fd, void *buf, size_t n) {
    if(fd != STDIN_FILENO) {
#ifdef LIBC
        errno = EBADF;
#endif // LIBC

        return -1;
    }

    if(n == 0) {
        return 0;
    }

    uint8_t *p = buf;

    size_t i = 0;

    while(i < n) {
        if((QEMU_UART_STATUS & QEMU_STATUS_RX_READY) == 0) {
            if(i == 0) {
                continue;
            }
            
            // Return partial bytes
            break;
        }

        p[i++] = QEMU_UART_RX;
    }

    return (int) i;
}
#else
    #define IO_BASE 0x300
    #define IO_DEVICE(x) (IO_BASE + (x * 0x40))

    #define UART_RX(x) (* (volatile uint8_t *) (IO_DEVICE(x) + 0x0))
    #define UART_TX(x) (* (volatile uint8_t *) (IO_DEVICE(x) + 0x1))
    #define UART_STATUS(x) (* (volatile uint8_t *) (IO_DEVICE(x) + 0x2))

    #define STATUS_WAIT_TX (1u << 0)
    #define STATUS_WAIT_RX (1u << 1)
    #define STATUS_FIFO_RX_EMPTY (1u << 2)
    #define STATUS_FIFO_RX_FULL (1u << 3)
    #define STATUS_FIFO_TX_EMPTY (1u << 4)
    #define STATUS_FIFO_TX_FULL (1u << 5)
    #define STATUS_INTERRUPT (1u << 7)

    #define DEFAULT_DEVICE 1

int _write(int fd, const void *buf, size_t n) {
    if(fd != STDOUT_FILENO && fd != STDERR_FILENO) {
#ifdef LIBC
        errno = EBADF;
#endif // LIBC

        return -1;
    }

    uint8_t device = DEFAULT_DEVICE;
    const uint8_t *p = buf;

    for(size_t i = 0; i < n; i++) {
        while((UART_STATUS(device) & STATUS_WAIT_TX)) {
            // spin!
        }

        UART_TX(device) = p[i];
    }

    return (int) n;
}

int _read(int fd, void *buf, size_t n) {
    if(fd != STDIN_FILENO) {
#ifdef LIBC
        errno = EBADF;
#endif // LIBC

        return -1;
    }

    if(n == 0) {
        return 0;
    }

    uint8_t device = DEFAULT_DEVICE;

    uint8_t *p = buf;

    size_t i = 0;

    while(i < n) {
        if((UART_STATUS(device) & STATUS_WAIT_RX)) {
            if(i == 0) {
                continue;
            }
            
            // Return partial bytes
            break;
        }

        p[i++] = (uint8_t) UART_RX(device);
    }

    return (int) i;
}
#endif // QEMU