/*
 * Copyright (c) 1999-2007 Apple Inc.  All Rights Reserved.
 * 
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */

extern const char *copyPropertyAttributeString(const objc_property_attribute_t *attrs, unsigned int count);
extern objc_property_attribute_t *copyPropertyAttributeList(const char *attrs, unsigned int *outCount);
extern char *copyPropertyAttributeValue(const char *attrs, const char *name);


const char *
copyPropertyAttributeString(const objc_property_attribute_t *attrs,
                            unsigned int count)
{
    char *result;
    unsigned int i;
    if (count == 0) return strdup("");
    
#ifndef NDEBUG
    // debug build: sanitize input
    for (i = 0; i < count; i++) {
        assert(attrs[i].name);
        assert(strlen(attrs[i].name) > 0);
        assert(! strchr(attrs[i].name, ','));
        assert(! strchr(attrs[i].name, '"'));
        if (attrs[i].value) assert(! strchr(attrs[i].value, ','));
    }
#endif

    size_t len = 0;
    for (i = 0; i < count; i++) {
        if (attrs[i].value) {
            size_t namelen = strlen(attrs[i].name);
            if (namelen > 1) namelen += 2;  // long names get quoted
            len += namelen + strlen(attrs[i].value) + 1;
        }
    }

    result = (char *)malloc(len + 1);
    char *s = result;
    for (i = 0; i < count; i++) {
        if (attrs[i].value) {
            size_t namelen = strlen(attrs[i].name);
            if (namelen > 1) {
                s += sprintf(s, "\"%s\"%s,", attrs[i].name, attrs[i].value);
            } else {
                s += sprintf(s, "%s%s,", attrs[i].name, attrs[i].value);
            }
        }
    }

    // remove trailing ',' if any
    if (s > result) s[-1] = '\0';

    return result;
}

/*
  Property attribute string format:

  - Comma-separated name-value pairs. 
  - Name and value may not contain ,
  - Name may not contain "
  - Value may be empty
  - Name is single char, value follows
  - OR Name is double-quoted string of 2+ chars, value follows

  Grammar:
    attribute-string: \0
    attribute-string: name-value-pair (',' name-value-pair)*
    name-value-pair:  unquoted-name optional-value
    name-value-pair:  quoted-name optional-value
    unquoted-name:    [^",]
    quoted-name:      '"' [^",]{2,} '"'
    optional-value:   [^,]*

*/
static unsigned int 
iteratePropertyAttributes(const char *attrs, 
                          BOOL (*fn)(unsigned int index, 
                                     void *ctx1, void *ctx2, 
                                     const char *name, size_t nlen, 
                                     const char *value, size_t vlen), 
                          void *ctx1, void *ctx2)
{
    if (!attrs) return 0;

#ifndef NDEBUG
    const char *attrsend = attrs + strlen(attrs);
#endif
    unsigned int attrcount = 0;

    while (*attrs) {
        // Find the next comma-separated attribute
        const char *start = attrs;
        const char *end = start + strcspn(attrs, ",");

        // Move attrs past this attribute and the comma (if any)
        attrs = *end ? end+1 : end;

        assert(attrs <= attrsend);
        assert(start <= attrsend);
        assert(end <= attrsend);
        
        // Skip empty attribute
        if (start == end) continue;

        // Process one non-empty comma-free attribute [start,end)
        const char *nameStart;
        const char *nameEnd;

        assert(start < end);
        assert(*start);
        if (*start != '\"') {
            // single-char short name
            nameStart = start;
            nameEnd = start+1;
            start++;
        }
        else {
            // double-quoted long name
            nameStart = start+1;
            nameEnd = nameStart + strcspn(nameStart, "\",");
            start++;                       // leading quote
            start += nameEnd - nameStart;  // name
            if (*start == '\"') start++;   // trailing quote, if any
        }

        // Process one possibly-empty comma-free attribute value [start,end)
        const char *valueStart;
        const char *valueEnd;

        assert(start <= end);

        valueStart = start;
        valueEnd = end;

        BOOL more = (*fn)(attrcount, ctx1, ctx2, 
                          nameStart, nameEnd-nameStart, 
                          valueStart, valueEnd-valueStart);
        attrcount++;
        if (!more) break;
    }

    return attrcount;
}


static BOOL 
copyOneAttribute(unsigned int index, void *ctxa, void *ctxs, 
                 const char *name, size_t nlen, const char *value, size_t vlen)
{
    objc_property_attribute_t **ap = (objc_property_attribute_t**)ctxa;
    char **sp = (char **)ctxs;

    objc_property_attribute_t *a = *ap;
    char *s = *sp;

    a->name = s;
    memcpy(s, name, nlen);
    s += nlen;
    *s++ = '\0';
    
    a->value = s;
    memcpy(s, value, vlen);
    s += vlen;
    *s++ = '\0';

    a++;
    
    *ap = a;
    *sp = s;

    return YES;
}

                 
objc_property_attribute_t *
copyPropertyAttributeList(const char *attrs, unsigned int *outCount)
{
    if (!attrs) {
        if (outCount) *outCount = 0;
        return NULL;
    }

    // Result size:
    //   number of commas plus 1 for the attributes (upper bound)
    //   plus another attribute for the attribute array terminator
    //   plus strlen(attrs) for name/value string data (upper bound)
    //   plus count*2 for the name/value string terminators (upper bound)
    unsigned int attrcount = 1;
    const char *s;
    for (s = attrs; s && *s; s++) {
        if (*s == ',') attrcount++;
    }

    size_t size = 
        attrcount * sizeof(objc_property_attribute_t) + 
        sizeof(objc_property_attribute_t) + 
        strlen(attrs) + 
        attrcount * 2;
    objc_property_attribute_t *result = (objc_property_attribute_t *) 
        calloc(size, 1);

    objc_property_attribute_t *ra = result;
    char *rs = (char *)(ra+attrcount+1);

    attrcount = iteratePropertyAttributes(attrs, copyOneAttribute, &ra, &rs);

    assert((uint8_t *)(ra+1) <= (uint8_t *)result+size);
    assert((uint8_t *)rs <= (uint8_t *)result+size);

    if (attrcount == 0) {
        free(result);
        result = NULL;
    }

    if (outCount) *outCount = attrcount;
    return result;
}


static BOOL
findOneAttribute(unsigned int index, void *ctxa, void *ctxs, 
                 const char *name, size_t nlen, const char *value, size_t vlen)
{
    const char *query = (char *)ctxa;
    char **resultp = (char **)ctxs;

    if (strlen(query) == nlen  &&  0 == strncmp(name, query, nlen)) {
        char *result = (char *)calloc(vlen+1, 1);
        memcpy(result, value, vlen);
        result[vlen] = '\0';
        *resultp = result;
        return NO;
    }

    return YES;
}

char *copyPropertyAttributeValue(const char *attrs, const char *name)
{
    char *result = NULL;

    iteratePropertyAttributes(attrs, findOneAttribute, (void*)name, &result);

    return result;
}