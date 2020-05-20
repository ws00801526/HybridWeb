//
//  HBWebViewReusePool.h
//  HybridWeb
//
//  Created by XMFraker on 2020/4/9.
//

#import <WebKit/WebKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


/// Reuse pool of webView.
/// For the first time create a webView caused about 100ms.
/// after that create a webView will be speed up caused about 10ms.
@interface HBWebViewReusePool : NSObject

/// Call you want to reset all webView.
/// Such as user logout.
- (void)reset;

/// Get a reusable webView
- (WKWebView *)dequeueReusableWebView;

/// Get a webView. maybe it's reusable if you don't pass userInfo. otherwise will create a new webView for you.
/// @param userInfo the config will be set to self.configuration.
- (WKWebView *)dequeueReusableWebViewWithUserInfo:(nullable NSDictionary *)userInfo;

/// Recycle a reusable webView.
/// @param webView  the webView will be reused
- (void)recycleReusableWebView:(WKWebView *)webView;

@end

NS_ASSUME_NONNULL_END
