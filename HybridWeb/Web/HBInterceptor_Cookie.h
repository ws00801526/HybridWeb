//
//  HBInterceptor_Cookie.h
//  HybridWeb
//
//  Created by XMFraker on 2020/5/22.
//

#import <Foundation/Foundation.h>
#import <HybridWeb/HBWebController.h>

NS_ASSUME_NONNULL_BEGIN

@interface HBInterceptor_Cookie : NSObject <HBInterceptor>
@property (nonatomic, weak) HBWebController *webController;
@end

NS_ASSUME_NONNULL_END
