//
//  HBInterceptor_Bridge.h
//  HybridWeb
//
//  Created by XMFraker on 2020/4/21.
//

#import <Foundation/Foundation.h>
#import <HybridWeb/HBWebController.h>

NS_ASSUME_NONNULL_BEGIN

@interface HBInterceptor_Bridge : NSObject <HBInterceptor>
@property (nonatomic, weak) HBWebController *webController;
@end

NS_ASSUME_NONNULL_END
