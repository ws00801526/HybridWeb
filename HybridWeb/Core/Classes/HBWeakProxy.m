//
//  HBWeakProxy.m
//  HybridWeb
//
//  Created by XMFraker on 2020/5/22.
//

#import "HBWeakProxy.h"

@implementation HBWeakProxy
@synthesize target = _target;
#pragma mark - Life

- (instancetype)initWithTarget:(id)target {
    if (target == nil) return nil;
    self->_target = target;
    return self;
}

+ (instancetype)proxyWithTarget:(id)target { return [[self alloc] initWithTarget:target]; }

#pragma - Override

- (id)forwardingTargetForSelector:(SEL)selector { return _target; }

- (void)forwardInvocation:(NSInvocation *)invocation {
    void *null = NULL;
    [invocation setReturnValue:&null];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [NSObject instanceMethodSignatureForSelector:@selector(init)];
}

- (BOOL)respondsToSelector:(SEL)aSelector { return [_target respondsToSelector:aSelector]; }

- (BOOL)isEqual:(id)object { return [_target isEqual:object]; }

- (NSUInteger)hash { return [_target hash]; }

- (Class)class { return [_target class]; }

- (Class)superclass { return [_target superclass]; }

- (BOOL)isKindOfClass:(Class)aClass { return [_target isKindOfClass:aClass]; }

- (BOOL)isMemberOfClass:(Class)aClass { return [_target isMemberOfClass:aClass]; }

- (BOOL)conformsToProtocol:(Protocol *)aProtocol { return [_target conformsToProtocol:aProtocol]; }

- (BOOL)isProxy { return YES; }

- (NSString *)description { return [_target description]; }

- (NSString *)debugDescription { return [_target debugDescription]; }

@end
