#include "objc/runtime.h"
#include "objc/objc-arc.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "class.h"
#include "properties.h"
#include "spinlock.h"
#include "visibility.h"
#include "nsobject.h"
#include "gc_ops.h"
#include "lock.h"

PRIVATE int spinlocks[spinlock_count];

/**
 * Public function for getting a property.  
 */
id objc_getProperty(id obj, SEL _cmd, ptrdiff_t offset, BOOL isAtomic)
{
	if (nil == obj) { return nil; }
	char *addr = (char*)obj;
	addr += offset;
	if (isGCEnabled)
	{
		return *(id*)addr;
	}
	id ret;
	if (isAtomic)
	{
		volatile int *lock = lock_for_pointer(addr);
		lock_spinlock(lock);
		ret = *(id*)addr;
		ret = objc_retain(ret);
		unlock_spinlock(lock);
		ret = objc_autoreleaseReturnValue(ret);
	}
	else
	{
		ret = *(id*)addr;
		ret = objc_retainAutoreleaseReturnValue(ret);
	}
	return ret;
}

void objc_setProperty(id obj, SEL _cmd, ptrdiff_t offset, id arg, BOOL isAtomic, BOOL isCopy)
{
	if (nil == obj) { return; }
	char *addr = (char*)obj;
	addr += offset;

	if (isGCEnabled)
	{
		if (isCopy)
		{
			arg = [arg copy];
		}
		*(id*)addr = arg;
		return;
	}
	if (isCopy)
	{
		arg = [arg copy];
	}
	else
	{
		arg = objc_retain(arg);
	}
	id old;
	if (isAtomic)
	{
		volatile int *lock = lock_for_pointer(addr);
		lock_spinlock(lock);
		old = *(id*)addr;
		*(id*)addr = arg;
		unlock_spinlock(lock);
	}
	else
	{
		old = *(id*)addr;
		*(id*)addr = arg;
	}
	objc_release(old);
}

/**
 * Structure copy function.  This is provided for compatibility with the Apple
 * APIs (it's an ABI function, so it's semi-public), but it's a bad design so
 * it's not used.  The problem is that it does not identify which of the
 * pointers corresponds to the object, which causes some excessive locking to
 * be needed.
 */
void objc_copyPropertyStruct(void *dest,
                             void *src,
                             ptrdiff_t size,
                             BOOL atomic,
                             BOOL strong)
{
	if (atomic)
	{
		volatile int *lock = lock_for_pointer(src);
		volatile int *lock2 = lock_for_pointer(src);
		lock_spinlock(lock);
		lock_spinlock(lock2);
		memcpy(dest, src, size);
		unlock_spinlock(lock);
		unlock_spinlock(lock2);
	}
	else
	{
		memcpy(dest, src, size);
	}
}

/**
 * Get property structure function.  Copies a structure from an ivar to another
 * variable.  Locks on the address of src.
 */
void objc_getPropertyStruct(void *dest,
                            void *src,
                            ptrdiff_t size,
                            BOOL atomic,
                            BOOL strong)
{
	if (atomic)
	{
		volatile int *lock = lock_for_pointer(src);
		lock_spinlock(lock);
		memcpy(dest, src, size);
		unlock_spinlock(lock);
	}
	else
	{
		memcpy(dest, src, size);
	}
}

/**
 * Set property structure function.  Copes a structure to an ivar.  Locks on
 * dest.
 */
void objc_setPropertyStruct(void *dest,
                            void *src,
                            ptrdiff_t size,
                            BOOL atomic,
                            BOOL strong)
{
	if (atomic)
	{
		volatile int *lock = lock_for_pointer(dest);
		lock_spinlock(lock);
		memcpy(dest, src, size);
		unlock_spinlock(lock);
	}
	else
	{
		memcpy(dest, src, size);
	}
}


objc_property_t class_getProperty(Class cls, const char *name)
{
	// Old ABI classes don't have declared properties
	if (Nil == cls || !objc_test_class_flag(cls, objc_class_flag_new_abi))
	{
		return NULL;
	}
	struct objc_property_list *properties = cls->properties;
	while (NULL != properties)
	{
		for (int i=0 ; i<properties->count ; i++)
		{
			objc_property_t p = &properties->properties[i];
			if (strcmp(p->name, name) == 0)
			{
				return p;
			}
		}
		properties = properties->next;
	}
	return NULL;
}

objc_property_t* class_copyPropertyList(Class cls, unsigned int *outCount)
{
	if (Nil == cls || !objc_test_class_flag(cls, objc_class_flag_new_abi))
	{
		if (NULL != outCount) { *outCount = 0; }
		return NULL;
	}
	struct objc_property_list *properties = cls->properties;
	unsigned int count = 0;
	for (struct objc_property_list *l=properties ; NULL!=l ; l=l->next)
	{
		count += l->count;
	}
	if (NULL != outCount)
	{
		*outCount = count;
	}
	if (0 == count)
	{
		return NULL;
	}
	objc_property_t *list = calloc(sizeof(objc_property_t), count);
	unsigned int out = 0;
	for (struct objc_property_list *l=properties ; NULL!=l ; l=l->next)
	{
		for (int i=0 ; i<properties->count ; i++)
		{
			list[out] = &l->properties[i];
		}
	}
	return list;
}

const char *property_getName(objc_property_t property)
{
	if (NULL == property) { return NULL; }

	const char *name = property->name;
	if (name[0] == 0)
	{
		name += name[1];
	}
	return name;
}

PRIVATE size_t lengthOfTypeEncoding(const char *types);

/**
 * The compiler stores the type encoding of the getter.  We replace this with
 * the type encoding of the property itself.  We use a 0 byte at the start to
 * indicate that the swap has taken place.
 */
static const char *property_getTypeEncoding(objc_property_t property)
{
	if (NULL == property) { return NULL; }

	const char *name = property->getter_types;
	if (name[0] == 0)
	{
		return &name[1];
	}
	size_t typeSize = lengthOfTypeEncoding(name);
	char *buffer = malloc(typeSize + 2);
	buffer[0] = 0;
	memcpy(buffer+1, name, typeSize);
	buffer[typeSize+1] = 0;
	if (!__sync_bool_compare_and_swap(&(property->getter_types), name, buffer))
	{
		free(buffer);
	}
	return &property->getter_types[1];
}

const char *property_getAttributes(objc_property_t property)
{
	if (NULL == property) { return NULL; }

	const char *name = (char*)property->name;
	if (name[0] == 0)
	{
		return name + 2;
	}

	const char *typeEncoding = property_getTypeEncoding(property);
	size_t typeSize = strlen(typeEncoding);
	size_t nameSize = strlen(property->name);
	// Encoding is T{type},V{name}, so 4 bytes for the "T,V" that we always
	// need.  We also need two bytes for the leading null and the length.
	size_t encodingSize = typeSize + nameSize + 6;
	char flags[16];
	size_t i = 0;
	// Flags that are a comma then a character
	if ((property->attributes & OBJC_PR_readonly) == OBJC_PR_readonly)
	{
		flags[i++] = ',';
		flags[i++] = 'R';
	}
	if ((property->attributes & OBJC_PR_copy) == OBJC_PR_copy)
	{
		flags[i++] = ',';
		flags[i++] = 'C';
	}
	if ((property->attributes & OBJC_PR_retain) == OBJC_PR_retain)
	{
		flags[i++] = ',';
		flags[i++] = '&';
	}
	if ((property->attributes & OBJC_PR_nonatomic) == OBJC_PR_nonatomic)
	{
		flags[i++] = ',';
		flags[i++] = 'N';
	}
	encodingSize += i;
	flags[i] = '\0';
	size_t setterLength = 0;
	size_t getterLength = 0;
	if ((property->attributes & OBJC_PR_getter) == OBJC_PR_getter)
	{
		getterLength = strlen(property->getter_name);
		encodingSize += 2 + getterLength;
	}
	if ((property->attributes & OBJC_PR_setter) == OBJC_PR_setter)
	{
		setterLength = strlen(property->setter_name);
		encodingSize += 2 + setterLength;
	}
	unsigned char *encoding = malloc(encodingSize);
	// Set the leading 0 and the offset of the name
	unsigned char *insert = encoding;
	*(insert++) = 0;
	*(insert++) = 0;
	// Set the type encoding
	*(insert++) = 'T';
	memcpy(insert, typeEncoding, typeSize);
	insert += typeSize;
	// Set the flags
	memcpy(insert, flags, i);
	insert += i;
	if ((property->attributes & OBJC_PR_getter) == OBJC_PR_getter)
	{
		*(insert++) = ',';
		*(insert++) = 'G';
		memcpy(insert, property->getter_name, getterLength);
		insert += getterLength;
	}
	if ((property->attributes & OBJC_PR_setter) == OBJC_PR_setter)
	{
		*(insert++) = ',';
		*(insert++) = 'S';
		memcpy(insert, property->setter_name, setterLength);
		insert += setterLength;
	}
	*(insert++) = ',';
	*(insert++) = 'V';
	encoding[1] = (unsigned char)(uintptr_t)(insert - encoding);
	memcpy(insert, property->name, nameSize);
	insert += nameSize;
	*insert = '\0';
	// If another thread installed the encoding string while we were computing
	// it, then discard the one that we created and return theirs.
	if (!__sync_bool_compare_and_swap(&(property->name), name, (char*)encoding))
	{
		free(encoding);
		return property->name + 2;
	}
	return (const char*)(encoding + 2);
}

objc_property_attribute_t *property_copyAttributeList(objc_property_t property,
                                                      unsigned int *outCount)
{
	if (NULL == property) { return NULL; }
	objc_property_attribute_t attrs[10];
	int count = 0;

	attrs[count].name = "T";
	attrs[count].value = property_getTypeEncoding(property);
	count++;
	if ((property->attributes & OBJC_PR_copy) == OBJC_PR_copy)
	{
		attrs[count].name = "C";
		attrs[count].value = "";
		count++;
	}
	if ((property->attributes & OBJC_PR_retain) == OBJC_PR_retain)
	{
		attrs[count].name = "&";
		attrs[count].value = "";
		count++;
	}
	if ((property->attributes & OBJC_PR_nonatomic) == OBJC_PR_nonatomic)
	{
		attrs[count].name = "N";
		attrs[count].value = "";
		count++;
	}
	if ((property->attributes & OBJC_PR_getter) == OBJC_PR_getter)
	{
		attrs[count].name = "G";
		attrs[count].value = property->getter_name;
		count++;
	}
	if ((property->attributes & OBJC_PR_setter) == OBJC_PR_setter)
	{
		attrs[count].name = "S";
		attrs[count].value = property->setter_name;
		count++;
	}
	attrs[count].name = "V";
	attrs[count].value = property_getName(property);
	count++;

	objc_property_attribute_t *propAttrs = calloc(sizeof(objc_property_attribute_t), count);
	memcpy(propAttrs, attrs, count * sizeof(objc_property_attribute_t));
	if (NULL != outCount)
	{
		*outCount = count;
	}
	return propAttrs;
}

PRIVATE struct objc_property propertyFromAttrs(const objc_property_attribute_t *attributes,
                                               unsigned int attributeCount)
{
	struct objc_property p = { 0 };
	for (unsigned int i=0 ; i<attributeCount ; i++)
	{
		switch (attributes[i].name[0])
		{
			case 'T':
			{
				size_t typeSize = strlen(attributes[i].value);
				char *buffer = malloc(typeSize + 2);
				buffer[0] = 0;
				memcpy(buffer+1, attributes[i].value, typeSize);
				buffer[typeSize+1] = 0;
				p.getter_types = buffer;
				break;
			}
			case 'S':
			{
				p.setter_name = strdup(attributes[i].value);
				break;
			}
			case 'G':
			{
				p.getter_name = strdup(attributes[i].value);
				break;
			}
			case 'V':
			{
				p.name = strdup(attributes[i].value);
				break;
			}
			case 'C':
			{
				p.attributes |= OBJC_PR_copy;
			}
			case '&':
			{
				p.attributes |= OBJC_PR_retain;
			}
			case 'N':
			{
				p.attributes |= OBJC_PR_nonatomic;
			}
		}
	}
	return p;
}

BOOL class_addProperty(Class cls,
                       const char *name,
                       const objc_property_attribute_t *attributes, 
                       unsigned int attributeCount)
{
	if ((Nil == cls) || (NULL == name) || (class_getProperty(cls, name) != 0)) { return NO; }
	struct objc_property p = propertyFromAttrs(attributes, attributeCount);
	// If there is a name mismatch, the attributes are invalid.
	if ((p.name != 0) && (strcmp(name, p.name) != 0)) { return NO; }

	struct objc_property_list *l = calloc(1, sizeof(struct objc_property_list)
			+ sizeof(struct objc_property));
	l->count = 0;
	memcpy(&l->properties, &p, sizeof(struct objc_property));
	LOCK_RUNTIME_FOR_SCOPE();
	l->next = cls->properties;
	cls->properties = l;
	return YES;
}

void class_replaceProperty(Class cls,
                           const char *name,
                           const objc_property_attribute_t *attributes,
                           unsigned int attributeCount)
{
	if ((Nil == cls) || (NULL == name)) { return; }
	objc_property_t old = class_getProperty(cls, name);
	if (NULL == old)
	{
		class_addProperty(cls, name, attributes, attributeCount);
		return;
	}
	struct objc_property p = propertyFromAttrs(attributes, attributeCount);
	memcpy(old, &p, sizeof(struct objc_property));
	if (NULL == old->name)
	{
		old->name = name;
	}
}
char *property_copyAttributeValue(objc_property_t property,
                                  const char *attributeName)
{
	if ((NULL == property) || (NULL == attributeName)) { return NULL; }
	switch (attributeName[0])
	{
		case 'T':
		{
			return strdup(property_getTypeEncoding(property));
		}
		case 'V':
		{
			return strdup(property_getName(property));
		}
		case 'S':
		{
			return strdup(property->setter_name);
		}
		case 'G':
		{
			return strdup(property->getter_name);
		}
		case 'C':
		{
			return ((property->attributes |= OBJC_PR_copy) == OBJC_PR_copy) ? strdup("") : 0;
		}
		case '&':
		{
			return ((property->attributes |= OBJC_PR_retain) == OBJC_PR_retain) ? strdup("") : 0;
		}
		case 'N':
		{
			return ((property->attributes |= OBJC_PR_nonatomic) == OBJC_PR_nonatomic) ? strdup("") : 0;
		}
	}
	return 0;
}

SEL _property_getSetterSelector(objc_property_t property) {
	return sel_registerName(property->setter_name);
}

SEL _property_getGetterSelector(objc_property_t property) {
	return sel_registerName(property->getter_name);
}

/* Function returns resulting string size and optionally makes string
 *  in 'attrs' buffer. First call with 'attrs' being NULL, allocate
 *  memory and call again.
 */
/*static size_t makeAttributeString(objc_property_t property, char *attrs) {
	// Create the attr string
	// Format of property attributes on iOS
	// T for type name, Example: T@"NSString"
	// & for retain
	// N for nonatomic
	// G for getter, Example: Gval
	// S for setter, Example: SsetVal:
	// V for backing iVar, Example: V_val
	// Start with the size for terminator.
	size_t size = 1;

	#define ATTRS_STRCAT(string) \
		size += strlen(string); \
		if (attrs) attrs = strcat(attrs, string)
	#define ATTRS_STRNCAT(string, length) \
		size += length; \
		if (attrs) attrs = strncat(attrs, string, length)
	
	// Prepare buffer for strcats.
	if (attrs) {
		*attrs = 0;

	ATTRS_STRCAT("T");

	const char *first = strchr(property->name, '|');
	const char *last = strrchr(property->name, '|');
	if (first && last) {
		ATTRS_STRNCAT(first + 1, last - first - 1);
	// & for retain
	if (!(property->attributes & OBJC_PR_assign)) {
		ATTRS_STRCAT(",&");
	}
	if (property->attributes & OBJC_PR_nonatomic) {
		ATTRS_STRCAT(",N");
	}
	if (property->attributes & OBJC_PR_getter) {
		ATTRS_STRCAT(",G");
		if (property->getter_name != NULL)
		{
			ATTRS_STRCAT(property->getter_name);
		}
		else
		{
			DEBUG_LOG("Property name has invalid getter_name!");
		}
	}

	ATTRS_STRCAT(",V");

	if (last) {
		ATTRS_STRCAT(last + 1);
	}

	return size;

	#undef ATTRS_STRCAT
	#undef ATTRS_STRNCAT
}


struct objc_property_extra *property_createExtras(objc_property_t property) {

	struct objc_property_extra *entry = (struct objc_property_extra *)malloc(sizeof(struct objc_property_extra));
	entry->property = property;

	// 1. Create the name
	const char *c = strchr(property->name, '|');
	entry->name = strndup(property->name, c - property->name);

	// 2. Create the attr string
	size_t attrsSize = makeAttributeString(property, NULL);
	char *attrs = malloc(attrsSize);
	makeAttributeString(property, attrs);
	entry->attributes = attrs;

	return entry;
}

const char *property_getName(objc_property_t property) {
	if(property == NULL) {
		DEBUG_LOG("Property name requested on null property");
		return "";
	}
	struct objc_property_extra* entry = NULL;
	HASH_WLOCK();
	HASH_FIND_PTR(prop_extras, &property, entry);
	if (entry == NULL) {
		entry = property_createExtras(property);
    	HASH_ADD_PTR(prop_extras, property, entry);
	}
	HASH_WUNLOCK();
	return entry->name;
}

const char *property_getAttributes(objc_property_t property)
{
	struct objc_property_extra* entry = NULL;
	HASH_WLOCK();
	HASH_FIND_PTR(prop_extras, &property, entry);
	if (entry == NULL) {
		entry = property_createExtras(property);
    	HASH_ADD_PTR(prop_extras, property, entry);
	}
	HASH_WUNLOCK();
	return entry->attributes;
}
*/


const char *_property_getGetterTypes(objc_property_t property) {
	return property->getter_types;
}

const char *_property_getSetterTypes(objc_property_t property) {
	return property->setter_types;
}