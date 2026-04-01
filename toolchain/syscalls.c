"""
newlib (C standard library) “syscalls layer” for an embedded system
connects printf, malloc, read, write, etc. to custom hardware (UART + heap in RAM)
"""
// Fixed-width integers
#include <stdint.h>
// Defines stat struct (file metadata)
#include <sys/types.h>
#include <sys/stat.h>
// POSIX system calls: _read, _write, _lseek, etc.
#include <unistd.h>
// Defines error codes like: ENOMEM (no memory), EBADF (bad file descriptor), ESPIPE (illegal seek)
#include <errno.h>
// “Reentrant” version of libc (thread-safe variants)
#include <reent.h>
#include "uart.h"

// Provided by linker script
extern char _heap_start;     // where RAM heap begins
extern char _heap_end;       // where RAM heap ends

// memory allocator core, called for malloc(), new, and dynamic memory allocation
caddr_t _sbrk(int incr) {
    // Initial break
    // Static heap pointer at current top of heap or beginning of heap region
    static char *heap = &_heap_start;

    // expand heap to requested memory size
    char *prev = heap;
    char *next = heap + incr;

    // If memory goes outside allowed RAM return error
    if(next < &_heap_start || next > &_heap_end) {
        errno = ENOMEM;

        return (caddr_t) -1;
    }

    // Move heap forward and return previous position (allocated block)
    heap = next;
    return (caddr_t) prev;
}

// as no real files in embedded system, returns “bad file descriptor”
int _close(int) {
    errno = EBADF;
    return -1;
}

// pretends everything is a device
int _fstat(int, struct stat *st) {
    // initialize struct as a character device
    st->st_mode = S_IFCHR;
    return 0;
}

// returns true, making printf() behave like terminal output and ensures line buffering works correctly
int _isatty(int) {
    return 1;
}

// as embedded system has no files rather than returning file positioning, outputs “illegal seek”
off_t _lseek(int, off_t, int) {
    errno = ESPIPE;

    return (off_t) -1;
}

// as no operating system exists, rather than exiting OS, enter an infinite loop 
void _exit(int) {
    while(1) {
        // spin!
    }
}

// Reentrant wrappers for newlib stdio functions
void *_sbrk_r(struct _reent *ptr, ptrdiff_t incr) {
    return _sbrk((int) incr);
}

int _write_r(struct _reent *ptr, int fd, const void *buf, size_t n) {
    return _write(fd, buf, n);
}

int _read_r(struct _reent *ptr, int fd, void *buf, size_t n) {
    return _read(fd, buf, n);
}

int _close_r(struct _reent *ptr, int fd) {
    return _close(fd);
}

int _fstat_r(struct _reent *ptr, int fd, struct stat *st) {
    return _fstat(fd, st);
}

int _isatty_r(struct _reent *ptr, int fd) {
    return _isatty(fd);
}

off_t _lseek_r(struct _reent *ptr, int fd, off_t offset, int whence) {
    return _lseek(fd, offset, whence);
}
