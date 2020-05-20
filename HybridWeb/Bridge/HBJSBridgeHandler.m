//
//  HBJSBridgeHandler.m
//  HybridWeb
//
//  Created by XMFraker on 2020/4/7.
//

#import "HBJSBridge.h"
#import "HBJSBridgeHandler.h"

FOUNDATION_EXTERN NSString *const kEWJBCallbackKey;
FOUNDATION_EXTERN NSString *const kEWJBResponseKey;
FOUNDATION_EXTERN NSString *const kEWJBDataKey;
FOUNDATION_EXTERN NSString *const kEWJBResponseDataKey;



typedef NSMutableArray<__kindof HBJSBridgeHandler *> HBJSBridgeHandlers;
static dispatch_semaphore_t kHBJSBridgeHandlersSemaphore = nil;
static HBJSBridgeHandlers *kHBJSBridgeHandlers = nil;
static NSMutableArray<__kindof HBJSBridgeHandler *> *kJSBridgeHandlers() {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kHBJSBridgeHandlersSemaphore = dispatch_semaphore_create(1);
        kHBJSBridgeHandlers = [NSMutableArray arrayWithCapacity:10];
    });
    dispatch_semaphore_wait(kHBJSBridgeHandlersSemaphore, DISPATCH_TIME_FOREVER);
    HBJSBridgeHandlers *handlers = kHBJSBridgeHandlers;
    dispatch_semaphore_signal(kHBJSBridgeHandlersSemaphore);
    return handlers;
}


@interface HBJSBridgeHandler ()
@property (nonatomic, copy) HBJBMessage *message;
@property (nonatomic, copy) HBJBResponseCallback completion;
@end

@implementation HBJSBridgeHandler

#pragma mark - Life

- (instancetype)init {
#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Weverything"
    return [self initWithContext:nil];
#pragma clang diagnostic pop
}

- (nullable instancetype)initWithContext:(id)context {
    self = [super init];
    if (self) self->_context = context;
    return self;
}

#pragma mark - Public

- (void)handle:(HBJBMessage *)message completion:(HBJBResponseCallback)completion {
    self->_message = [message ? : @{} copy];
    if (completion) self->_completion = [completion copy];
    [kJSBridgeHandlers() addObject:self];
}

- (void)finishWithResponse:(id)response {
    if (self.context && self.completion) self.completion(response);
    [kJSBridgeHandlers() removeObject:self];
}

#pragma mark - Getter

- (id)userInfo { return [self.message objectForKey:kEWJBDataKey]; }

@end
