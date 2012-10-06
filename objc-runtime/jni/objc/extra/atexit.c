
extern int __cxa_atexit(void (*)(void *), void *, void *);

int atexit(void (*func)(void))
{
	return __cxa_atexit((void (*)(void *))func, NULL, NULL);
}

extern void __cxa_finalize(void *);
extern void _exit(int);

void __real_exit(int status)
{
	__cxa_finalize(NULL);
	_exit(status);
}