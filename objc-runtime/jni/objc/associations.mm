//
//  associations.mm
//  objc
//
//  Created by Philippe Hausler on 1/1/12.
//

#import <map>
#include "objc/runtime.h"
#include "objc_debug.h"

typedef std::map<const void *, objc_AssociationPolicy> ObjCPolicy;
typedef std::map<const void *, id> ObjCBinding;
typedef std::map<id, ObjCPolicy> ObjCPolicyMap;
typedef std::map<id, ObjCBinding> ObjCBindingMap;

static int __objc_finalizers_imminent = 0; 

class ObjCAssociationMap {
private:
	ObjCPolicyMap policies;
	ObjCBindingMap associations;
public:
	~ObjCAssociationMap() {
		__objc_finalizers_imminent = 1; // helps to avoid a race condition on finalizers
	}
	
	void set(id object, const void *key, id value, objc_AssociationPolicy policy) {
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
	
	id get(id object, const void *key) {
		return associations[object][key];
	}
	
	void remove(id object) {
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
};

static ObjCAssociationMap store;

void objc_setAssociatedObject(id object, const void *key, id value, objc_AssociationPolicy policy)
{
    if(!object || !key || __objc_finalizers_imminent)
        return;
    store.set(object, key, value, policy);
}

id objc_getAssociatedObject(id object, const void *key)
{
    if(!object || !key || __objc_finalizers_imminent)
        return NULL;
    return store.get(object, key);
}

void objc_removeAssociatedObjects(id object)
{
    if(!object || __objc_finalizers_imminent)
        return;
    store.remove(object);
}