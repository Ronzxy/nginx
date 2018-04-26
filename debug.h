#ifndef DEBUG_LENKY_H
#define DEBUG_LENKY_H
#include <stdio.h>

void enable_debug(void) __attribute__((no_instrument_function));
void disable_debug(void) __attribute__((no_instrument_function));
int get_debug_flag(void) __attribute__((no_instrument_function));
void set_debug_flag(int) __attribute__((no_instrument_function));
void main_constructor(void) __attribute__((no_instrument_function, constructor));
void main_destructor(void) __attribute__((no_instrument_function, destructor));
void __cyg_profile_func_enter(void *, void *) __attribute__((no_instrument_function));
void __cyg_profile_func_exit(void *, void *) __attribute__((no_instrument_function));

#ifndef DEBUG_MAIN
extern FILE *debug_file_fd;
#else
FILE *debug_file_fd;
#endif
#endif
