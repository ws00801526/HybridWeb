//
//  HBWeakProxy.h
//  HybridWeb
//
//  Created by XMFraker on 2020/5/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HBWeakProxy : NSProxy

@property (nonatomic, weak, readonly, nullable) id target;

- (nullable instancetype)initWithTarget:(id)target;
+ (nullable instancetype)proxyWithTarget:(id)target;

@end

NS_ASSUME_NONNULL_END
