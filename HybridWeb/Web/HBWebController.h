//
//  HBWebController.h
//  HybridWeb
//
//  Created by XMFraker on 2020/4/9.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <HybridWeb/HBJSBridge.h>
#import <HybridWeb/HBWebConfiguration.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, HBInterceptorPriority) {
    HBInterceptorPriorityLow = 250,
    HBInterceptorPriorityNormal = 750,
    HBInterceptorPriorityHigh = 1000,
    HBInterceptorPriorityDefault = HBInterceptorPriorityNormal
};

typedef NS_ENUM(NSInteger, HBWebViewDecidePolicy) {
    HBWebViewDecidePolicyCancelled = 0,
    HBWebViewDecidePolicyAllow,
    HBWebViewDecidePolicyIgnored = NSNotFound,
};

@class HBWebController;
@protocol HBInterceptor <UIScrollViewDelegate>
@property (nonatomic, weak)             HBWebController *webController;
@property (nonatomic, assign, readonly) HBInterceptorPriority priority;

@required
- (nullable instancetype)initWithWebController:(__kindof HBWebController *)webController;

@optional
/// Invoked after viewDidLoad or (addInterceptor & viewLoaded)
/// @param controller the controller invoke the method
- (void)webControllerViewDidLoaded:(HBWebController *)controller;
- (void)webController:(HBWebController *)controller observerValueDidChangedForKeyPath:(NSString *)keyPath;
- (void)webController:(HBWebController *)controller didLoadURL:(NSURL *)URL error:(nullable NSError *)error;
- (NSMutableURLRequest *)webController:(HBWebController *)controller willLoadURLRequest:(NSURLRequest *)URLRequest;

/// Intercept the decide policy for navigation.
/// @warning make sure return value if you using the decisionHandler.
/// @param controller the controller of Web
/// @param navigationAction the navigation
- (HBWebViewDecidePolicy)webController:(HBWebController *)controller decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction;
- (HBWebViewDecidePolicy)webController:(HBWebController *)controller decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse;

- (void)webController:(HBWebController *)controller willTransitionToSize:(CGSize)size withContext:(id<UIViewControllerTransitionCoordinatorContext>)context;
- (void)webController:(HBWebController *)controller didTransitionToSize:(CGSize)size withContext:(id<UIViewControllerTransitionCoordinatorContext>)context;

@end

@protocol HBContentRefreshable <NSObject>
- (void)refreshWithUserInfo:(nullable NSDictionary *)userInfo;
@end

@interface HBWebController : UIViewController <HBContentRefreshable>

@property (nonatomic, assign, readonly) BOOL canGoBack;
@property (nonatomic, assign, readonly) BOOL canGoForward;
@property (nonatomic, copy,   readonly) NSURL *startURL;
@property (nonatomic, weak,   readonly) __kindof WKWebView *webView;
@property (nonatomic, strong, readonly) __kindof HBJSBridge *bridge;
@property (nonatomic, strong, readonly) HBWebConfiguration *configuration;

- (instancetype)initWithURL:(nullable NSURL *)URL;
- (instancetype)initWithURL:(nullable NSURL *)URL configuration:(nullable HBWebConfiguration *)configuration NS_DESIGNATED_INITIALIZER;

- (void)refreshWithUserInfo:(nullable NSDictionary *)userInfo;

@end

@interface HBWebController (Interceptor)
@property (nonatomic, strong, readonly) NSArray<id<HBInterceptor>> *interceptors;
- (void)addInterceptor:(id<HBInterceptor>)interceptor;
- (void)removeInterceptor:(id<HBInterceptor>)interceptor;

+ (void)registerGlobalInterceptor:(Class<HBInterceptor>)interceptor;
@end

NS_ASSUME_NONNULL_END
