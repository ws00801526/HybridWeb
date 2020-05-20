//
//  UIImage+UIKit_Extension.h
//  HybridWeb
//
//  Created by XMFraker on 2020/4/9.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURL (Extension)
@property (nonatomic, assign, readonly) BOOL hb_isNotEmpty;
@end

@interface UIView (Extension)
@property (nonatomic, assign) CGFloat x;
@property (nonatomic, assign) CGFloat y;
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, assign, readonly) UIEdgeInsets safeArea;
@end

@interface UIColor (Extension)
@property (nonatomic, copy, readonly) NSString *hb_hex;
+ (instancetype)hb_colorWithHex:(NSUInteger)hex;
+ (instancetype)hb_colorWithHex:(NSUInteger)hex alpha:(CGFloat)alpha;
@end

@interface UIImage (Extension)

@property (nonatomic, copy, readonly) NSString *hb_base64;
+ (instancetype)hb_imageWithNamed:(NSString *)name inBundle:(nullable NSBundle *)bundle;
+ (instancetype)hb_imageWithNamed:(NSString *)name ofBundle:(nullable NSString *)bundleName;

+ (nullable instancetype)hb_imageWithColor:(UIColor *)color;
+ (nullable instancetype)hb_imageWithColor:(UIColor *)color size:(CGSize)size;
@end

@class HBWebBarStyle;
@protocol HBWebBarStyleable <NSObject>
@property (nonatomic, strong) HBWebBarStyle *storedBarStyle;
- (void)hb_applyBarStyle:(HBWebBarStyle *)style;
- (void)hb_restoreBarStyle;
@end

@interface UINavigationBar (Extension) <HBWebBarStyleable>
@end
@interface UITabBar (Extension) <HBWebBarStyleable>
@end
@interface UIToolbar (Extension) <HBWebBarStyleable>
@end

NS_ASSUME_NONNULL_END
