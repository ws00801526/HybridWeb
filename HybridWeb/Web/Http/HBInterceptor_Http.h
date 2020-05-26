//
//  HBInterceptor_Domain.h
//  HybridWeb
//
//  Created by XMFraker on 2020/4/14.
//

#import <Foundation/Foundation.h>
#import <HybridWeb/HBWebController.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSURLRequest *__nullable HBURLRequest(NSDictionary *userInfo, NSURL * __nullable relativeURL);
@protocol HBHTTPRequest <NSObject>
@property (nonatomic, copy, readonly) HBJBResponseCallback handler;
@property (nonatomic, copy, readonly) NSDictionary *userInfo;
- (nullable instancetype)initWithUserInfo:(NSDictionary *)userInfo handler:(HBJBResponseCallback)handler;
- (void)startWithRelativeURL:(nullable NSURL *)relativeURL;
- (void)cancel;
@end

@interface HBInterceptor_Http : NSObject <HBInterceptor>
@property (nonatomic, weak) HBWebController *webController;
+ (void)registerHTTPRequest:(Class<HBHTTPRequest>)klass;
@end

NS_ASSUME_NONNULL_END
