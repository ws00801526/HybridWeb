//
//  HBJSBridgeHandler.h
//  HybridWeb
//
//  Created by XMFraker on 2020/4/7.
//

#import <HybridWeb/HBJSBridge.h>

NS_ASSUME_NONNULL_BEGIN

#define EWJS_REGISTER_HANDLER(isAsync) \
+ (void)load { if (!#isAsync) [HBJSBridge registerDynamicHandler:[self class]];  \
else dispatch_async(dispatch_get_main_queue(), ^{ [HBJSBridge registerDynamicHandler:[self class]]; }); }

@protocol HBJSBridgeHandlerProtocol <NSObject>
- (nullable instancetype)initWithContext:(id)context;
- (void)finishWithResponse:(nullable id)response;
- (void)handle:(nullable HBJBMessage *)message completion:(nullable HBJBResponseCallback)completion;
@end

@interface HBJSBridgeHandler : NSObject <HBJSBridgeHandlerProtocol>

/// The data info pass from JS Side
@property (nonatomic, copy,  readonly, nullable) id userInfo;
/// The message call from JS Side
@property (nonatomic, copy,  readonly, nullable) HBJBMessage *message;
/// The context of handler.
@property (nonatomic, weak,  readonly, nullable) id context;

- (nullable instancetype)initWithContext:(nullable id)context NS_DESIGNATED_INITIALIZER;

/// Start handle the message.
/// Add your login by override this method.
/// @param message  the message will be handled
- (void)handle:(nullable HBJBMessage *)message completion:(nullable HBJBResponseCallback)completion NS_REQUIRES_SUPER;

/// Finish the action with response.
/// The action will be nil after finished.
/// @warning make  call [super finishWithResponse:] to release the action
/// @param response the response will be send to js side if needed
- (void)finishWithResponse:(nullable id)response NS_REQUIRES_SUPER;

@end

NS_ASSUME_NONNULL_END
