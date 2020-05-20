//
//  HBJSBridge.h
//  HybridWeb
//
//  Created by XMFraker on 2020/4/7.
//

#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSDictionary HBJBMessage;
typedef void(^HBJBResponseCallback)(id response);
typedef void(^HBJBHandler)(id userInfo, HBJBResponseCallback handler);

typedef NS_ENUM(NSUInteger, HBJBInjectMode) {
    HBJBInjectAutomatic,
    HBJBInjectManully
};

@interface HBJSBridge : NSObject

/// The webView to inject the Bridge.
/// @warning don't set webView.navigationDelegate again, using setWebViewDelegate: insteaded
@property (nonatomic, weak, readonly) WKWebView *webView;

/// How the Bridge should be inject
@property (nonatomic, assign, readonly) HBJBInjectMode mode;

/// The actions will be placed in. Default is @[[NSBundle mainBundle]].
/// Using this if the action is Swift code to make sure we can get the correct action class.
@property (nonatomic, strong, nullable) NSMutableArray<NSBundle *> *actionBundles;

/// Create Bridge for WebView
/// @param webView  the webView will be inject Bridge JS
- (instancetype)initWithWebView:(WKWebView *)webView;
- (instancetype)initWithWebView:(WKWebView *)webView mode:(HBJBInjectMode)mode;

/// clear startupMessageQueue & callbacks
- (void)reset;

/// Flush message from JS
- (void)flushMessageQueue;

/// Set the new delegate for WKWebView. The real delegate is used by Bridge
/// @param delegate the delegate
- (void)setWebViewDelegate:(id<WKNavigationDelegate>)delegate;

@end

@interface HBJSBridge (JS2N)

/// Register the actions from plist.
/// The plist's content should be same as
/// @[ @{@"handlerName" : @"the handler name of action", @"class" : @"the handler action class"}, ... ]
/// @param plistPath the absoulte plist path
- (void)registerActionsPlistPath:(NSString *)plistPath;

- (void)registerHandler:(NSString *)handlerName clazz:(Class)clazz;
- (void)registerHandler:(NSString *)handlerName handler:(HBJBHandler)handler;
- (void)removeHandler:(NSString *)handlerName;

/// Register dynamic handler
/// The handle class should be HBJSBridgeHandler_Custom, and  custom will be used as handlerName.
/// @param clazz the class of handler
+ (void)registerGlobalHandler:(Class)clazz;
+ (void)registerGlobalHandler:(NSString *)handlerName clazz:(Class)clazz;

@end

@interface HBJSBridge (N2JS)

- (void)disableAsync;

/// Dispatch an js event.
/// @param eventName the name of event
/// @param options the options will be send to js.
- (void)dispatchEvent:(NSString *)eventName options:(nullable NSDictionary *)options;

/// Call JS event
/// @param handlerName the name of handler.
- (void)callHandler:(NSString *)handlerName;

/// Call JS event
/// @param handlerName the name of handler
/// @param data the data will be send to JS
- (void)callHandler:(NSString *)handlerName data:(nullable id)data;

/// Call JS event
/// @param handlerName the name of handler.
/// @param data the data will be send to JS.
/// @param callback the callBack will be invoked by js  side.
- (void)callHandler:(NSString *)handlerName data:(nullable id)data responseCallback:(nullable HBJBResponseCallback)callback;

@end

NS_ASSUME_NONNULL_END
