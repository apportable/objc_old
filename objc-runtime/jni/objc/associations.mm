//
//  associations.mm
//  objc
//
//  Created by Philippe Hausler on 1/1/12.
//

#import <map>
#include "objc/runtime.h"

typedef std::map<const void *, objc_AssociationPolicy> ObjCPolicy;
typedef std::map<const void *, id> ObjCBinding;
typedef std::map<id, ObjCPolicy> ObjCPolicyMap;
typedef std::map<id, ObjCBinding> ObjCBindingMap;

static ObjCPolicyMap policies;
static ObjCBindingMap associations;

void objc_setAssociatedObject(id object, const void *key, id value, objc_AssociationPolicy policy)
{
    if(!object || !key)
        return;
    switch(policy)
    {
        case OBJC_ASSOCIATION_ASSIGN:
            associations[object][key] = value;
            break;
        case OBJC_ASSOCIATION_RETAIN_NONATOMIC:
        case OBJC_ASSOCIATION_RETAIN:
            if(associations[object][key] != value)
            {
                [associations[object][key] release];
                associations[object][key] = [value retain];
            }
            break;
        case OBJC_ASSOCIATION_COPY_NONATOMIC:
        case OBJC_ASSOCIATION_COPY:
            if(associations[object][key] != value)
            {
                [associations[object][key] release];
                associations[object][key] = [value copy];
            }
            break;
    }
    
    policies[object][key] = policy;
}

id objc_getAssociatedObject(id object, const void *key)
{
    if(!object || !key)
        return NULL;
    return associations[object][key];
}

void objc_removeAssociatedObjects(id object)
{
    if(!object)
        return;
    // Technically this should be syncrhonized to avoid stepping on the toes of another remove op or another set/get op
    // but if you are playing with this api, it is the caller's responsability to make sure it is dealt with in a thread
    // safe manner, else the performance takes a severe dive since this is called on EVERY release of an object
    
    ObjCBindingMap::iterator bindings = associations.find(object);
    if(bindings != associations.end())
    {
        for(ObjCBinding::iterator it = bindings->second.begin(); it != bindings->second.end(); ++it) 
        {
            switch(policies[object][it->first])
            {
                case OBJC_ASSOCIATION_RETAIN_NONATOMIC:
                case OBJC_ASSOCIATION_RETAIN:
                case OBJC_ASSOCIATION_COPY_NONATOMIC:
                case OBJC_ASSOCIATION_COPY:
                    [it->second release];
                    // fall through
                case OBJC_ASSOCIATION_ASSIGN:
                    it->second = NULL;
                    break;
            }
        }
        bindings->second.clear();
        associations.erase(object);
        policies.erase(object);
    }
}