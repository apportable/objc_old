#include <stdio.h>
#include <stdlib.h>

void objc_enumerationMutation(void *obj)
{
	fprintf(stderr, "Mutation occured during enumeration.");
	abort();
}

