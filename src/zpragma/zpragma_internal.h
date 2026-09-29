#pragma once
#include <stdint.h>

typedef struct convspec_s {
    char fmt;
    char complex;
    uint32_t val;
    uint32_t lval;
    uint32_t llval;
} CONVSPEC;

extern CONVSPEC printf_formats[];
extern CONVSPEC scanf_formats[];

uint64_t parse_format_string(char *arg, CONVSPEC *specifiers);
uint32_t scan_format_literal(const char *arg, CONVSPEC *specifiers);
