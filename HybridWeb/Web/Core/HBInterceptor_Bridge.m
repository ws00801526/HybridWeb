//
//  HBInterceptor_Bridge.m
//  HybridWeb
//
//  Created by XMFraker on 2020/4/21.
//

#import "HBInterceptor_Bridge.h"
#import "WKWebView+HBExtension.h"

@interface HBWebController (Private)
- (void)updateUIIfConfigurationChanged;
@end

@interface HBWebConfiguration (Private)
@property (nonatomic, copy, readonly) NSArray<NSString *> *propertyKeys;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *properties;
@end

@interface HBJSBridge (Private)
@property (nonatomic, strong, readonly) NSDictionary<NSString *, HBJBHandler> *messageHandlers;
@property (nonatomic, strong, readonly) NSDictionary<NSString *, Class> *messageActions;
@end

@interface HBInterceptor_Bridge ()
@end

@implementation HBInterceptor_Bridge

#pragma mark - Life

- (instancetype)initWithWebController:(__kindof HBWebController *)webController {
    if (webController == nil) return nil;
    self = [super init];
    if (self) self.webController = webController;
    return self;
}

#pragma mark - HBInterceptor

- (void)webControllerViewDidLoaded:(HBWebController *)controller {
    
    __weak typeof(controller) wController = controller;
    [controller.bridge registerHandler:@"push" handler:^(id  _Nonnull userInfo, HBJBResponseCallback  _Nonnull handler) {
        __strong typeof(wController) scontroller = wController;
        if (scontroller == nil) return;
        NSString *url = [userInfo objectForKey:@"url"];
        if ([url isKindOfClass:[NSString class]] && url.length > 0) {
            HBWebConfiguration *config = [HBWebConfiguration defaultConfiguration];
            [config updateWithUserInfo:[userInfo objectForKey:@"config"]];
            HBWebController *theController = [[HBWebController alloc] initWithURL:[NSURL URLWithString:url] configuration:config];
            [scontroller.navigationController pushViewController:theController animated:YES];
        } else { handler(@{@"code" : @-1, @"message" : @"url should not be empty or illegal"}); }
    }];
    
    [controller.bridge registerHandler:@"pop" handler:^(id  _Nonnull userInfo, HBJBResponseCallback  _Nonnull handler) {
        __strong typeof(wController) scontroller = wController;
        if (scontroller == nil) return;
        int index = ABS([[userInfo objectForKey:@"index"] intValue]);
        
        if (index == NSNotFound || index <= 1) [scontroller.navigationController popViewControllerAnimated:YES];
        else {
            // !!!: remember your route path. using this method can pop to any controller in the stack.
            NSArray<UIViewController *> *controllers = [[[scontroller.navigationController viewControllers] reverseObjectEnumerator] allObjects];
            if (index >= controllers.count) { [scontroller.navigationController popViewControllerAnimated:YES]; }
            else [scontroller.navigationController popToViewController:[controllers objectAtIndex:index] animated:YES];
        }
        
        if (![[userInfo objectForKey:@"refresh"] boolValue]) return;
        id<HBContentRefreshable> refreshable = (id<HBContentRefreshable>)scontroller.navigationController.visibleViewController;
        if ([refreshable respondsToSelector:@selector(refreshWithUserInfo:)]) [refreshable refreshWithUserInfo:userInfo];
    }];
    
    [controller.bridge registerHandler:@"pasteboard" handler:^(id  _Nonnull userInfo, HBJBResponseCallback  _Nonnull handler) {
        // check pasteboard.
        __strong typeof(wController) scontroller = wController;
        if (scontroller == nil) return;
        NSString *string = [userInfo objectForKey:@"string"];
        if (string.length > 0) [[UIPasteboard generalPasteboard] setString:string];
        handler([[UIPasteboard generalPasteboard] string]);
    }];
    
    [controller.bridge registerHandler:@"webConfig" handler:^(id  _Nonnull userInfo, HBJBResponseCallback  _Nonnull handler) {
        __strong typeof(wController) scontroller = wController;
        if (scontroller == nil) return;
        BOOL needUpdateUI = [scontroller.configuration updateWithUserInfo:userInfo];
        if (needUpdateUI) [scontroller updateUIIfConfigurationChanged];
        handler(scontroller.configuration.properties);
    }];
    
    [controller.bridge registerHandler:@"checkApi" handler:^(id  _Nonnull userInfo, HBJBResponseCallback  _Nonnull handler) {
       
        __strong typeof(wController) scontroller = wController;
        if (scontroller == nil || handler == NULL) return;
        HBJSBridge *const bridge = scontroller.bridge;
        if ([userInfo isKindOfClass:[NSArray class]]) {
            NSArray<NSString *> *apis = (NSArray<NSString *> *)userInfo;
            NSArray<NSString *> *allApis = [bridge.messageActions.allKeys arrayByAddingObjectsFromArray:bridge.messageHandlers.allKeys];
            NSArray<NSString *> *available = [apis filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF in %@", allApis]];
            NSArray<NSString *> *unavailable = [apis filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"not (SELF in %@)", allApis]];
            handler(@{ @"available" : available ? : @[], @"unavailable" : unavailable ? : @[]});
        } else {
            NSArray<NSString *> *allApis = [bridge.messageActions.allKeys arrayByAddingObjectsFromArray:bridge.messageHandlers.allKeys];
            handler(@{ @"available" : allApis ? : @[] });
        }
    }];
}

- (HBInterceptorPriority)priority { return HBInterceptorPriorityHigh; }

@end
