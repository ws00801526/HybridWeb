//
//  WKWebView+HBExtension.h
//  HybridWeb
//
//  Created by XMFraker on 2020/4/3.
//

#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, HBLogLevel) {
    HBLogLevelDebug,
    HBLogLevelWarn,
    HBLogLevelError,
    HBLogLevelNone
};

FOUNDATION_EXPORT void HBConfigLogLevel(HBLogLevel level);
FOUNDATION_EXPORT void HBLog(NSString *format, ...);
FOUNDATION_EXPORT void HBLogW(NSString *format, ...);
FOUNDATION_EXPORT void HBLogE(NSString *format, ...);

typedef NS_ENUM(NSUInteger, HBWebCacheType) {
    HBWebCacheTypeNone = 0,
    HBWebCacheTypeCookies = 1 << 0,
    HBWebCacheTypeDiskCache = 1 << 1,
    HBWebCacheTypeMemoryCache = 1 << 2,
    HBWebCacheTypeLocalStorage = 1 << 3,
    HBWebCacheTypeSessionStorage = 1 << 4,
    HBWebCacheTypeAll = 0xFFFFFFF
};

@interface WKWebView (EWExtension)

/// append userAgent behind default value
- (void)appendUserAgent:(NSString *)userAgent;
- (void)replaceUserAgent:(NSString *)userAgent;

/// Set a cookie
/// @param cookie the cookie will be set
/// @param handler  A block to invoke once the cookie has been stored.
- (void)setCookie:(NSHTTPCookie *)cookie handler:(nullable void(^)(void))handler;

/// Delete a cookie
/// @param cookie  the cookie will be delete
/// @param handler  A block to invoke once the cookie has been deleted.
- (void)deleteCookie:(NSHTTPCookie *)cookie handler:(nullable void(^)(void))handler;

/// Clear specified caches
/// @param types  the cache type will be cleared
/// @param date    the cache modified after the date, Default will be [NSDate distancePash]
/// @param handler  invoked after completed.
+ (void)clearCacheOf:(HBWebCacheType)types since:(nullable NSDate *)date handler:(nullable void(^)(void))handler;

/// Sync cookie of URL from `NSHTTPCookieStorage` to `WKHTTPCookieStore`
/// @param URL  the url
/// @param handler  the handler will be invoked when completed.
+ (void)syncCookiesOf:(NSURL *)URL handler:(nullable void(^)(void))handler;

@end

NS_ASSUME_NONNULL_END
