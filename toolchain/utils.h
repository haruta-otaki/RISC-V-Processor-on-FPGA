#ifndef UTILS_H
#define UTILS_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

uint64_t read_cycles();
uint64_t read_instructions_retired();

#ifdef __cplusplus
}
#endif

#endif // UTILS_H