#include <stdio.h>
#include <stdlib.h>

#if !defined(DEBUG_BREAK)
#if !defined(NDEBUG) && defined(ANDROID)
#include <android/log.h>
#define DEBUG_BREAK() { ((void)__android_log_print(ANDROID_LOG_WARN, "objc", "DEBUG_BREAK: Hit breakpoint at %s:%d", __FILE__, __LINE__)); int *debug_break_crash_var = 0; *debug_break_crash_var = 42; }
#else
#define DEBUG_BREAK(...)
#endif
#endif

void objc_enumerationMutation(void *obj)
{
	fprintf(stderr, "Mutation occured during enumeration.");
  DEBUG_BREAK();
	abort();
}

