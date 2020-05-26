//
//  HBInterceptor_Cookie.m
//  HybridWeb
//
//  Created by XMFraker on 2020/5/22.
//

#import "HBInterceptor_Cookie.h"

@implementation HBInterceptor_Cookie

- (nullable instancetype)initWithWebController:(nonnull __kindof HBWebController *)webController {
    self = [super init];
    if (self) self->_webController = webController;
    return self;
}

- (NSMutableURLRequest *)webController:(HBWebController *)controller willLoadURLRequest:(NSURLRequest *)URLRequest {
    NSMutableURLRequest *request = [URLRequest mutableCopy];
    NSArray<NSHTTPCookie *> *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:request.URL];
    if (cookies.count) {
        NSMutableDictionary *headers = [request.allHTTPHeaderFields ? : @{} mutableCopy];
        [headers addEntriesFromDictionary:[NSHTTPCookie requestHeaderFieldsWithCookies:cookies] ? : @{}];
        request.allHTTPHeaderFields = [headers copy];
    }
    return request;
}

- (HBWebViewDecidePolicy)webController:(HBWebController *)controller decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction {
 
    // The request is redirected. maybe invoked by server\<target="_blank">
    if ([navigationAction.request isKindOfClass:[NSMutableURLRequest class]]) {
        NSMutableURLRequest *request = (NSMutableURLRequest *)navigationAction.request;
        NSArray<NSHTTPCookie *> *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:request.URL];
        if (cookies.count) {
            NSMutableDictionary *headers = [request.allHTTPHeaderFields ? : @{} mutableCopy];
            [headers addEntriesFromDictionary:[NSHTTPCookie requestHeaderFieldsWithCookies:cookies] ? : @{}];
            request.allHTTPHeaderFields = [headers copy];
        }
    }
    return HBWebViewDecidePolicyIgnored;
}

- (HBWebViewDecidePolicy)webController:(HBWebController *)controller decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse {
    if (@available(iOS 11, *)) {
        [controller.webView.configuration.websiteDataStore.httpCookieStore getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
            for (NSHTTPCookie *cookie in cookies) { [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie]; }
        }];
    } else {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)[navigationResponse response];
        NSArray<NSHTTPCookie *> *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:response.allHeaderFields forURL:response.URL];
        for (NSHTTPCookie *cookie in cookies) { [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie]; }
    }
    return HBWebViewDecidePolicyIgnored;
}

- (HBInterceptorPriority)priority { return HBInterceptorPriorityHigh; }

@end
