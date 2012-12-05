
#include <string.h>
#include <pthread.h>
#include <android/log.h>

#ifdef MOZ_MEMORY_ANDROID
#define wrap(a) __wrap_ ## a
#define real(a) __real_ ## a
#else
#define wrap(a) je_ ## a
#define real(a) a
#endif

extern void *wrap(malloc)(size_t sz);
extern void wrap(free)(void *ptr);

/* operator new(unsigned int) */
void *
wrap(_Znwj)(unsigned int size)
{
  return wrap(malloc)(size);
}

/* operator new[](unsigned int) */
void *
wrap(_Znaj)(unsigned int size)
{
  return wrap(malloc)(size);
}

/* operator delete(void*) */
void
wrap(_ZdlPv)(void *ptr)
{
  wrap(free)(ptr);
}

/* operator delete[](void*) */
void
wrap(_ZdaPv)(void *ptr)
{
  wrap(free)(ptr);
}

char *
wrap(strndup)(const char *src, size_t len)
{
  char* dst = (char*)wrap(malloc)(len + 1);
  if (dst)
  {
    strncpy(dst, src, len);
    dst[len] = 0;
  }
  return dst;
}

char *
wrap(strdup)(const char *src)
{
  size_t len = strlen(src);
  return wrap(strndup)(src, len);
}

// this probably doesnt belong here, but oh well...
extern void real(exit)(int value);
void wrap(exit)(int value) __attribute__((weak));
void wrap(exit)(int value)
{
    real(exit)(value);
}

extern int real(pthread_create)(pthread_t *restrict thread, const pthread_attr_t *restrict attr, void *(*start_routine)(void *), void *restrict arg);
int wrap(pthread_create)(pthread_t *restrict thread, const pthread_attr_t *restrict attr, void *(*start_routine)(void *), void *restrict arg) __attribute__((weak));
int wrap(pthread_create)(pthread_t *restrict thread, const pthread_attr_t *restrict attr, void *(*start_routine)(void *), void *restrict arg)
{
    return real(pthread_create)(thread, attr, start_routine, arg);
}

extern void real(pthread_exit)(void *value_ptr);
void wrap(pthread_exit)(void *value_ptr) __attribute__((weak));
void wrap(pthread_exit)(void *value_ptr)
{
    real(pthread_exit)(value_ptr);
}

char *__printf_tag = "printf";

void __wrap_printf(const char *format, ...)
{
#ifndef NDEBUG
    va_list args;
    va_start(args, format);
    __android_log_vprint(ANDROID_LOG_INFO, __printf_tag, format, args);
    va_end(args);
#endif
}