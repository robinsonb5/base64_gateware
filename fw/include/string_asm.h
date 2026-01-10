#ifndef STRING_ASM_H
#define STRING_ASM_H
#include <stddef.h>

char *__strcpy(__reg("a0") char *,__reg("a1") const char *);
char *__strncpy(__reg("a0") char *,__reg("a1") const char *,__reg("d0") size_t size);
int __strcmp(__reg("a0") const char *,__reg("a1") const char *);
int __strncmp(__reg("a0") const char *,__reg("a1") const char *,__reg("d0") size_t size);
int __strcasecmp(__reg("a0") const char *,__reg("a1") const char *);
int __strncasecmp(__reg("a0") const char *,__reg("a1") const char *,__reg("d0") size_t size);
void *__memcpy(__reg("a0") void *dst,__reg("a1") const void *src,__reg("d0") size_t size);
void *__memset(__reg("a0") void *dst,__reg("d0") int c,__reg("d1") size_t size);

#endif
