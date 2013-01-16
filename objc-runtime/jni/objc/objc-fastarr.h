#include <objc/objc-arc.h>

__attribute__((always_inline))
static BOOL callerAcceptsFastAutorelease(const void * const ra0);

#if __x86_64__

static BOOL callerAcceptsFastAutorelease(const void * const ra0)
{
    const uint8_t *ra1 = (const uint8_t *)ra0;
    const uint16_t *ra2;
    const uint32_t *ra4 = (const uint32_t *)ra1;
    const void **sym;

#define PREFER_GOTPCREL 0
#if PREFER_GOTPCREL
    // 48 89 c7    movq  %rax,%rdi
    // ff 15       callq *symbol@GOTPCREL(%rip)
    if (*ra4 != 0xffc78948) {
        return NO;
    }
    if (ra1[4] != 0x15) {
        return NO;
    }
    ra1 += 3;
#else
    // 48 89 c7    movq  %rax,%rdi
    // e8          callq symbol
    if (*ra4 != 0xe8c78948) {
        return NO;
    }
    ra1 += (long)*(const int32_t *)(ra1 + 4) + 8l;
    ra2 = (const uint16_t *)ra1;
    // ff 25       jmpq *symbol@DYLDMAGIC(%rip)
    if (*ra2 != 0x25ff) {
        return NO;
    }
#endif
    ra1 += 6l + (long)*(const int32_t *)(ra1 + 2);
    sym = (const void **)ra1;
    if (*sym != objc_retainAutoreleasedReturnValue)
    {
        return NO;
    }

    return YES;
}

// __x86_64__
#elif __arm__

static BOOL callerAcceptsFastAutorelease(const void *ra)
{
    // if the low bit is set, we're returning to thumb mode
    if ((uintptr_t)ra & 1) {
        // 3f 46          mov r7, r7
        // we mask off the low bit via subtraction
        if (*(uint16_t *)((uint8_t *)ra - 1) == 0x463f) {
            return YES;
        }
    } else {
        // 07 70 a0 e1    mov r7, r7
        if (*(uint32_t *)ra == 0xe1a07007) {
            return YES;
        }
    }
    return NO;
}

// __arm__

#else

#warning unknown architecture

static BOOL callerAcceptsFastAutorelease(const void *ra)
{
    return NO;
}

#endif