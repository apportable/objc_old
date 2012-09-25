
#include <string.h>
#ifdef MOZ_MEMORY_ANDROID
#define wrap(a) __wrap_ ## a
#else
#define wrap(a) je_ ## a
#endif

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
    strncpy(dst, src, len + 1);
  return dst;
}

char *
wrap(strdup)(const char *src)
{
  size_t len = strlen(src);
  return wrap(strndup)(src, len);
}
