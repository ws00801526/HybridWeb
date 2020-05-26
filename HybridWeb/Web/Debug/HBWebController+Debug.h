//
//  HBWebController+Debug.h
//  HybridWeb
//
//  Created by XMFraker on 2020/5/25.
//

#import <HybridWeb/HybridWeb.h>

NS_ASSUME_NONNULL_BEGIN

@interface HBWebController (Debug)
+ (void)startDebugOf:(__kindof UIViewController *)parent;
+ (void)startDebugOf:(__kindof UIViewController *)parent userInfo:(nullable NSDictionary *)userInfo;
@end

NS_ASSUME_NONNULL_END
