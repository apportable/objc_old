#include <stdio.h>
#include <stdlib.h>
#include "objc_debug.h"

void objc_enumerationMutation(id obj)
{
	fprintf(stderr, "Mutation occured during enumeration.");
	DEBUG_BREAK();
	abort();
}

