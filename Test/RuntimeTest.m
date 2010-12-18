#import <Foundation/Foundation.h>
#include <objc/runtime.h>

static int exitStatus = 0;

static void _test(BOOL X, char *expr, int line)
{
  if (!X)
  {
    exitStatus = 1;
    fprintf(stderr, "ERROR: Test failed: '%s' on %s:%d\n", expr, __FILE__, line);
  }
}
#define test(X) _test(X, #X, __LINE__)

static int stringsEqual(const char *a, const char *b)
{
  return 0 == strcmp(a,b);
}



@interface Foo : NSObject
{
  id a;
}
- (void) aMethod;
+ (void) aMethod;
- (int) manyTypes;
- (void) synchronizedCode;
+ (void) synchronizedCode;
+ (id) shared;
- (BOOL) basicThrowAndCatchException;
@end

@interface Bar : Foo
{
  id b;
}
- (void) anotherMethod;
+ (void) anotherMethod;
- (id) manyTypes;
- (id) aBool: (BOOL)d andAnInt: (int) w;
@end


@implementation Foo
- (void) aMethod
{
}
+ (void) aMethod
{
}
- (int) manyTypes
{
  return YES;
}
- (void) synchronizedCode
{
	@synchronized(self) { [[self class] synchronizedCode]; }		
}
+ (void) synchronizedCode
{
	@synchronized(self) { }
}
+ (id) shared
{
	@synchronized(self) { }
	return nil;
}
- (void) throwException
{
	@throw [NSException exceptionWithName: @"RuntimeTestException" reason: @"" userInfo: nil];
}
- (BOOL) basicThrowAndCatchException
{
	@try
	{  
		[self throwException];
	}
	@catch (NSException *e)
	{
		NSLog(@"Caught %@", e);
	}
	@finally
	{
		return YES;
	}
	return NO;
}
@end

@implementation Bar
- (void) anotherMethod
{
}
+ (void) anotherMethod
{
}
- (id) manyTypes
{
  return @"Hello";
}
- (id) aBool: (BOOL)d andAnInt: (int) w
{
  return @"Hello";
}
@end


void testInvalidArguments()
{
  test(NO == class_conformsToProtocol([NSObject class], NULL));
  test(NO == class_conformsToProtocol(Nil, NULL));
  test(NO == class_conformsToProtocol(Nil, @protocol(NSCoding)));
  test(NULL == class_copyIvarList(Nil, NULL));
  test(NULL == class_copyMethodList(Nil, NULL));
  test(NULL == class_copyPropertyList(Nil, NULL));
  test(NULL == class_copyProtocolList(Nil, NULL));
  test(nil == class_createInstance(Nil, 0));
  test(0 == class_getVersion(Nil));
  test(NO == class_isMetaClass(Nil));
  test(Nil == class_getSuperclass(Nil));
        
  test(NULL == method_getName(NULL));
  test(NULL == method_copyArgumentType(NULL, 0));
  test(NULL == method_copyReturnType(NULL));
  method_exchangeImplementations(NULL, NULL);
  test((IMP)NULL == method_setImplementation(NULL, (IMP)NULL));
  test((IMP)NULL == method_getImplementation(NULL));
  method_getArgumentType(NULL, 0, NULL, 0);
  test(0 == method_getNumberOfArguments(NULL));
  test(NULL == method_getTypeEncoding(NULL));
  method_getReturnType(NULL, NULL, 0);
  
  test(NULL == ivar_getName(NULL));
  test(0 == ivar_getOffset(NULL));
  test(NULL == ivar_getTypeEncoding(NULL));
  
  test(nil == objc_getProtocol(NULL));
  
  test(stringsEqual("<null selector>", sel_getName((SEL)0)));
  test((SEL)0 == sel_getUid(NULL));
  test(0 != sel_getUid("")); // the empty string is permitted as a selector
  test(stringsEqual("", sel_getName(sel_getUid(""))));
  test(YES == sel_isEqual((SEL)0, (SEL)0));
  
  //test(NULL == property_getName(NULL));

  printf("testInvalidArguments() ran\n");
}

void testAMethod(Method m)
{
  test(NULL != m);
  test(stringsEqual("aMethod", sel_getName(method_getName(m))));
  
  printf("testAMethod() ran\n");
}

void testGetMethod()
{
  testAMethod(class_getClassMethod([Bar class], @selector(aMethod)));
  testAMethod(class_getClassMethod([Bar class], sel_getUid("aMethod")));

  printf("testGetMethod() ran\n");  
}

void testProtocols()
{
  test(protocol_isEqual(@protocol(NSCoding), objc_getProtocol("NSCoding")));

  printf("testProtocols() ran\n");  
}

void testMultiTypedSelector()
{
  test(sel_isEqual(@selector(manyTypes),sel_getUid("manyTypes")));
  test(@selector(manyTypes) == sel_getUid("manyTypes"));
    
  Method intMethod = class_getInstanceMethod([Foo class], @selector(manyTypes));
  Method idMethod = class_getInstanceMethod([Bar class], @selector(manyTypes));  
  
  test(method_getName(intMethod) == @selector(manyTypes));
  test(method_getName(idMethod) == @selector(manyTypes));

  test(sel_isEqual(method_getName(intMethod), @selector(manyTypes)));
  test(sel_isEqual(method_getName(idMethod), @selector(manyTypes)));
 
  char ret[10];
  method_getReturnType(intMethod, ret, 10);
  test(stringsEqual(ret, "i"));
  method_getReturnType(idMethod, ret, 10);
  test(stringsEqual(ret, "@"));
  
  printf("testMultiTypedSelector() ran\n");
}

void testClassHierarchy()
{
  Class nsProxy = objc_getClass("NSProxy");
  Class nsObject = objc_getClass("NSObject");
  Class nsProxyMeta = object_getClass(nsProxy);
  Class nsObjectMeta = object_getClass(nsObject);
  
  test(object_getClass(nsProxyMeta) == nsProxyMeta);
  test(object_getClass(nsObjectMeta) == nsObjectMeta);
  
  test(Nil == class_getSuperclass(nsProxy));
  test(Nil == class_getSuperclass(nsObject));
  
  test(nsObject == class_getSuperclass(nsObjectMeta));
  test(nsProxy == class_getSuperclass(nsProxyMeta));
  printf("testClassHierarchy() ran\n");
}

void testAllocateClass()
{
  Class newClass = objc_allocateClassPair(objc_lookUpClass("NSObject"), "UserAllocated", 0);
  test(Nil != newClass);
  // class_getSuperclass() will call objc_resolve_class().
  // Although we have not called objc_registerClassPair() yet, this works with 
  // the Apple runtime and GNUstep Base relies on this behavior in 
  // GSObjCMakeClass().
  test(objc_lookUpClass("NSObject") == class_getSuperclass(newClass));
  printf("testAllocateClass() ran\n");
}

void testSynchronized()
{
  Foo *foo = [Foo new];
  printf("Enter synchronized code\n");
  [foo synchronizedCode];
  [foo release];
  [Foo shared];
  printf("testSynchronized() ran\n");
}

void testExceptions()
{
  Foo *foo = [Foo new];
  test([foo basicThrowAndCatchException]);
  [foo release];
  printf("testExceptions() ran\n");

}

int main (int argc, const char * argv[])
{
  testInvalidArguments();
  testGetMethod();
  testProtocols();
  testMultiTypedSelector();
  testClassHierarchy();
  testAllocateClass();
  printf("Instance of NSObject: %p\n", class_createInstance([NSObject class], 0));

  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  testSynchronized();
  testExceptions();
  [pool release];

  return exitStatus;
}
