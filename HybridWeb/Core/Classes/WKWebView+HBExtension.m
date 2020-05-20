//
//  WKWebView+HBExtension.m
//  HybridWeb
//
//  Created by XMFraker on 2020/4/3.
//

#import "WKWebView+HBExtension.h"

#if DEBUG
static HBLogLevel kLogLevel = HBLogLevelDebug;
#else
static HBLogLevel kLogLevel = HBLogLevelWarn;
#endif

void HBConfigLogLevel(HBLogLevel level) {
    kLogLevel = level;
}

void HBLog(NSString *format, ...) {
    if (kLogLevel > HBLogLevelDebug) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"EWLog-D: %@", message);
}

void HBLogW(NSString *format, ...) {
    if (kLogLevel > HBLogLevelWarn) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"EWLog-W: %@", message);
}

void HBLogE(NSString *format, ...) {
    if (kLogLevel > HBLogLevelError) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"EWLog-E: %@", message);
}

@implementation WKWebView (EWExtension)

- (void)appendUserAgent:(NSString *)userAgent {
    
    if (userAgent.length <= 0) { HBLog(@"append empty userAgent is unnecesssary"); return; }
    
    NSString *theUserAgent = [self evaluateJavaScript:@"navigator.userAgent" timeout:5.f];
    if (theUserAgent == nil) theUserAgent = [WKWebView defaultUserAgent];
    if ([theUserAgent hasSuffix:userAgent]) return;
    [self replaceUserAgent:[theUserAgent stringByAppendingFormat:@" %@", userAgent]];
}

- (void)replaceUserAgent:(NSString *)userAgent {
    
    if (userAgent.length <= 0) { HBLogW(@"replace empty userAgent is too danagerous"); return; }
    
    if (@available(iOS 9.0, *)) {  self.customUserAgent = userAgent; }
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{ @"UserAgent" : userAgent }];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


- (void)setCookie:(NSHTTPCookie *)cookie handler:(nullable void(^)(void))handler {
    
    if (@available(iOS 11, *)) {
        [self.configuration.websiteDataStore.httpCookieStore setCookie:cookie completionHandler:handler];
    } else {
        NSMutableString *cookieValue = [NSMutableString stringWithFormat:@"%@=%@;path=%@",cookie.name, cookie.value, (cookie.path ? : @"/")];
        if (cookie.domain.length > 0) [cookieValue appendFormat:@";domain=%@",cookie.domain];
        if (cookie.expiresDate) {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss z";
            [cookieValue appendFormat:@";expires=%@", [formatter stringFromDate:cookie.expiresDate]];
        }
        if (cookie.secure) [cookieValue appendFormat:@";secure=true"];
        NSString *js = [NSString stringWithFormat:@"document.cookie='%@';", [cookieValue copy]];
        [self evaluateJavaScript:js completionHandler:^(id res, NSError *error) {
            if (error) HBLogW(@"set cookie failed :%@--%@\n%@", cookie.name, cookie.value, error);
            if (handler && error == nil) handler();
        }];
    }
}

- (void)deleteCookie:(NSHTTPCookie *)cookie handler:(nullable void(^)(void))handler {
    if (@available(iOS 11, *)) {
        [self.configuration.websiteDataStore.httpCookieStore deleteCookie:cookie completionHandler:handler];
    } else {
        // using expires to delete a cookie
        NSMutableString *cookieValue = [NSMutableString stringWithFormat:@"%@=%@", cookie.name, cookie.value];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss z";
        [cookieValue appendFormat:@";expires=%@", [formatter stringFromDate:[NSDate distantPast]]];
        NSString *js = [NSString stringWithFormat:@"document.cookie='%@';", [cookieValue copy]];
        [self evaluateJavaScript:js completionHandler:^(id res, NSError *error) {
            if (error) HBLogW(@"delete cookie failed :%@--%@\n%@", cookie.name, cookie.value, error);
            if (handler && error == nil) handler();
        }];
    }
}

#pragma mark - Private

/// evaluate js sync, using runloop to waiting for over. default timeoutInterval is 5s
/// @warning never using this api on background thread.
- (nullable id)evaluateJavaScript:(NSString *)js timeout:(NSTimeInterval)timeout {
    
    if (js.length <= 0) return nil;
    __block id theValue = nil;
    __block BOOL finished = NO;
    [self evaluateJavaScript:js completionHandler:^(id value, NSError * _Nullable error) {
        theValue = value;
        if (error) HBLogE(@"evaluate js failed :%@", error);
        finished = YES;
    }];
    if (timeout <= 0.f) timeout = 5.f;
    int count = (int)(timeout * 20);
    while (!finished && count > 0) {
        count -= 1;
        // using runloop, check the result every 0.05s & never block the main thread
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    return theValue;
}

#pragma mark - Class

+ (NSString *)defaultUserAgent {
    NSString *userAgent = nil;
#if TARGET_OS_IOS
    // User-Agent Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.43
    userAgent = [NSString stringWithFormat:@"%@/%@ (%@; iOS %@; Scale/%0.2f)", [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleExecutableKey] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleIdentifierKey], [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleVersionKey], [[UIDevice currentDevice] model], [[UIDevice currentDevice] systemVersion], [[UIScreen mainScreen] scale]];
#elif TARGET_OS_WATCH
    // User-Agent Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.43
    userAgent = [NSString stringWithFormat:@"%@/%@ (%@; watchOS %@; Scale/%0.2f)", [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleExecutableKey] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleIdentifierKey], [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleVersionKey], [[WKInterfaceDevice currentDevice] model], [[WKInterfaceDevice currentDevice] systemVersion], [[WKInterfaceDevice currentDevice] screenScale]];
#endif
    if (userAgent) {
        if (![userAgent canBeConvertedToEncoding:NSASCIIStringEncoding]) {
            NSMutableString *mutableUserAgent = [userAgent mutableCopy];
            if (CFStringTransform((__bridge CFMutableStringRef)(mutableUserAgent), NULL, (__bridge CFStringRef)@"Any-Latin; Latin-ASCII; [:^ASCII:] Remove", false)) {
                userAgent = mutableUserAgent;
            }
        }
    }
    return userAgent;
}

+ (void)clearCacheOf:(HBWebCacheType)types since:(nullable NSDate *)date handler:(nullable void(^)(void))handler {
    
    if (@available(iOS 10.0, *)) {
        NSMutableSet<NSString *> *datatypes = [NSMutableSet set];
        if ((types & HBWebCacheTypeCookies) == HBWebCacheTypeCookies) [datatypes addObject:WKWebsiteDataTypeCookies];
        if ((types & HBWebCacheTypeDiskCache) == HBWebCacheTypeDiskCache) [datatypes addObject:WKWebsiteDataTypeDiskCache];
        if ((types & HBWebCacheTypeMemoryCache) == HBWebCacheTypeMemoryCache) [datatypes addObject:WKWebsiteDataTypeMemoryCache];
        if ((types & HBWebCacheTypeLocalStorage) == HBWebCacheTypeLocalStorage) [datatypes addObject:WKWebsiteDataTypeLocalStorage];
        if ((types & HBWebCacheTypeSessionStorage) == HBWebCacheTypeSessionStorage) [datatypes addObject:WKWebsiteDataTypeSessionStorage];
        [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:datatypes modifiedSince:date ? : [NSDate distantPast] completionHandler:^{
            if (handler) handler();
        }];
    }
    
    NSString *library = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString *cachePath;
    NSError *error;
    if ((types & HBWebCacheTypeCookies) == HBWebCacheTypeCookies) {
        cachePath = [library stringByAppendingString:@"/Cookies"];
        [[NSFileManager defaultManager] removeItemAtPath:cachePath error:&error];
    }

    if (types == HBWebCacheTypeAll) {
        NSString *identifier = [[NSBundle mainBundle] bundleIdentifier];
        cachePath = [library stringByAppendingString:[NSString stringWithFormat:@"/WebKit/%@", identifier]];
        [[NSFileManager defaultManager] removeItemAtPath:cachePath error:&error];

        cachePath = [library stringByAppendingString:[NSString stringWithFormat:@"/Caches/%@", identifier]];
        [[NSFileManager defaultManager] removeItemAtPath:cachePath error:&error];
    }
}

+ (void)syncCookiesOf:(NSURL *)URL handler:(nullable void(^)(void))handler {
    
    NSArray<NSHTTPCookie *> *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:URL];
    if (cookies.count <= 0) return;
    if (@available(iOS 11.0, *)) {
        dispatch_group_t group = dispatch_group_create();
        WKHTTPCookieStore *store = [WKWebsiteDataStore defaultDataStore].httpCookieStore;
        for (NSHTTPCookie *cookie in cookies) {
            dispatch_group_enter(group);
            [store setCookie:cookie completionHandler:^{
                HBLog(@"set cookie success :%@-%@-%@", cookie.name, cookie.value, cookie.domain);
                dispatch_group_leave(group);
            }];
        }
        dispatch_group_notify(group, dispatch_get_main_queue(), ^{ if (handler) handler(); });
    }
}

@end
