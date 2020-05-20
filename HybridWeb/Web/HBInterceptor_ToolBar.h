//
//  HBInterceptor_ToolBar.h
//  HybridWeb
//
//  Created by XMFraker on 2020/4/14.
//

#import <Foundation/Foundation.h>
#import <HybridWeb/HBWebController.h>

NS_ASSUME_NONNULL_BEGIN

@interface HBInterceptor_ToolBar : NSObject <HBInterceptor>
@property (nonatomic, weak) HBWebController *webController;
@end

NS_ASSUME_NONNULL_END
