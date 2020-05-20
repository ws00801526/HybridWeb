#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "WKWebView+HBExtension.h"

#if __has_include(<HybridWeb/HBJSBridge.h>)
    #import "HBJSBridge.h"
    #import "HBJSBridgeHandler.h"
#endif

#if __has_include(<HybridWeb/HBWebController.h>)
    #import "HBWebController.h"
    #import "HBWebConfiguration.h"
#endif

#import <WebKit/WebKit.h>

FOUNDATION_EXPORT double HybridWebVersionNumber;
FOUNDATION_EXPORT const unsigned char HybridWebVersionString[];
