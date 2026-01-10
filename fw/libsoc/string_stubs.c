#include <string_asm.h>
#include <stddef.h>
#include <stdio.h>

char *strcpy(char *dst,const char *src)
{
	return(__strcpy(dst,src));
}

char *strncpy(char *dst,const char *src,size_t n)
{
	return(__strncpy(dst,src,n));
}

int strcmp(const char *s1,const char *s2)
{
	return(__strcmp(s1,s2));
}

int strncmp(const char *s1,const char *s2,size_t n)
{
	return(__strncmp(s1,s2,n));
}

int strcasecmp(const char *s1,const char *s2)
{
	return(__strcasecmp(s1,s2));
}

int strncasecmp(const char *s1,const char *s2,size_t n)
{
	return(__strncasecmp(s1,s2,n));
}

void *memset(void *dst,int c,size_t size)
{
	return(__memset(dst,c,size));
}

void *memcpy(void *dst,const void *src,size_t size)
{
	return(__memcpy(dst,src,size));
}

