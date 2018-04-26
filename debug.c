#include "debug.h"

#define DEBUG_FILE_PATH "/var/log/nginx/debug.log"

int _flag = 0;

#define open_debug_file() \
    (debug_file_fd = fopen(DEBUG_FILE_PATH, "a"))

#define close_debug_file() \
    do { \
        if (NULL != debug_file_fd) { \
            fclose(debug_file_fd); \
        } \
    } while(0)

#define debug_print(args, fmt...) \
    do { \
        if (0 == _flag) { \
            break; \
        } \
        if (NULL == debug_file_fd && NULL == open_debug_file()) { \
            printf("Error: Can not open debug log file.\n"); \
            break; \
        } \
        fprintf(debug_file_fd, args, ##fmt); \
        fflush(debug_file_fd); \
    } while(0)

void enable_debug(void)
{
    _flag = 1;
}

void disable_debug(void)
{
    _flag = 0;
}

int get_debug_flag(void)
{
    return _flag;
}

void set_debug_flag(int flag)
{
    _flag = flag;
}

void main_constructor(void)
{
    //Do nothing
}

void main_destructor(void)
{
    close_debug_file();
}

void __cyg_profile_func_enter(void *this, void *call)
{
    debug_print("Enter\n%p\n%p\n", call, this);
}

void __cyg_profile_func_exit(void *this, void *call)
{
    debug_print("Exit\n%p\n%p\n", call, this);
}
