//
//  UIImage+UIKit_Extension.m
//  HybridWeb
//
//  Created by XMFraker on 2020/4/9.
//

#import "UIKit+Extension.h"
#import "HBWebConfiguration.h"
#import <objc/runtime.h>

@implementation NSURL (Extension)

- (BOOL)hb_isNotEmpty {
    if (self.absoluteString.length <= 0) return NO;
    if ([self.absoluteString isEqualToString:@"about:blank"]) return NO;
    return YES;
}

@end

@implementation UIView (Extension)

#define kSetFrameOrigin(_x) \
CGRect frame = self.frame; \
frame.origin._x = _x; \
self.frame = frame; \

- (void)setX:(CGFloat)x { kSetFrameOrigin(x) }
- (void)setY:(CGFloat)y { kSetFrameOrigin(y) }

#undef kSetFrameOrigin

#define kSetFrameSize(_x) \
CGRect frame = self.frame; \
frame.size._x = _x; \
self.frame = frame; \

- (void)setWidth:(CGFloat)width { kSetFrameSize(width) }
- (void)setHeight:(CGFloat)height { kSetFrameSize(height) }

#undef kSetFrameSize

- (CGFloat)x { return CGRectGetMinX(self.frame); }
- (CGFloat)y { return CGRectGetMinY(self.frame); }
- (CGFloat)width { return CGRectGetWidth(self.frame); }
- (CGFloat)height { return CGRectGetHeight(self.frame); }
- (UIEdgeInsets)safeArea {
    if (@available(iOS 11, *)) { return self.safeAreaInsets; }
    else { return UIEdgeInsetsZero; }
}

@end

@implementation UIColor (Extension)

+ (instancetype)hb_colorWithHex:(NSUInteger)hex {
    return [self hb_colorWithHex:hex alpha:1.f];
}

+ (instancetype)hb_colorWithHex:(NSUInteger)hex alpha:(CGFloat)alpha {
    return [UIColor colorWithRed:((float)((hex & 0xFF0000) >> 16))/255.0f
                           green:((float)((hex & 0xFF00) >> 8))/255.0f
                            blue:((float)(hex & 0xFF))/255.0f
                           alpha:alpha];
}

- (NSString *)hb_hex {
    
    static NSString *format = @"%02x%02x%02x";
    CGFloat red, green, blue, alpha = 0.f;
    [self getRed:&red green:&green blue:&blue alpha:&alpha];
    if (alpha <= 0) return nil;
    else return [NSString stringWithFormat:format, (int)(red * 255.f), (int)(green * 255.f), (int)(blue * 255.f)];
}

@end

@implementation UIImage (Extension)

+ (instancetype)hb_imageWithNamed:(NSString *)name inBundle:(nullable NSBundle *)bundle {
    
    UIImage *image;
    if (bundle && ![bundle.bundleURL isEqual:[NSBundle mainBundle].bundleURL]) {
        if (@available(iOS 13, *)) {
            image = [UIImage imageNamed:name inBundle:bundle withConfiguration:nil];
        } else if (@available(iOS 8, *)) {
            image = [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:nil];
        } else {
            NSString *imagePath = [bundle pathForResource:name ofType:nil];
            image = [UIImage imageWithContentsOfFile:imagePath];
        }
    }
    return image ? : [UIImage imageNamed:name];
}

+ (instancetype)hb_imageWithNamed:(NSString *)name ofBundle:(nullable NSString *)bundleName {
    
    NSBundle *innerBundle = nil;
    if (bundleName.length > 0) {
        NSString *bundlePath = [[NSBundle bundleForClass:NSClassFromString(@"HBWebController")] pathForResource:bundleName ofType:@"bundle"];
        innerBundle = [NSBundle bundleWithPath:bundlePath];
    }
    return [self hb_imageWithNamed:name inBundle:innerBundle];
}

+ (instancetype)hb_imageWithColor:(UIColor *)color {
    return [self hb_imageWithColor:color size:CGSizeMake(1.f, 1.f)];
}

+ (instancetype)hb_imageWithColor:(UIColor *)color size:(CGSize)size {
    if (color == nil) return nil;
    if (CGSizeEqualToSize(CGSizeZero, size)) return nil;
    CGRect rect= (CGRect) { CGPointZero, size };
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    UIImage *theImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return theImage;
}


- (NSString *)hb_base64 {
    NSData *data = UIImagePNGRepresentation(self);
    if (data.length <= 0) return @"";
    NSString *base64 = [data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    if (base64.length <= 0) return @"";
    return [@"data:image/png;base64," stringByAppendingString:base64];
}

@end

@implementation UINavigationBar (Extension)

- (void)hb_applyBarStyle:(HBWebBarStyle *)style {
    
    if (self.storedBarStyle == nil) {
        self.storedBarStyle = [[HBWebBarStyle alloc] init];
        self.storedBarStyle.hidden = self.isHidden;
        self.storedBarStyle.tintColor = self.tintColor;
        self.storedBarStyle.translucent = self.isTranslucent;
        self.storedBarStyle.barTintColor = self.barTintColor;
        self.storedBarStyle.shadowImage = self.shadowImage;
        self.storedBarStyle.backgroundImage = [self backgroundImageForBarMetrics:UIBarMetricsDefault];

        if (@available(iOS 13.0, *)) self.storedBarStyle.shadowColor = self.standardAppearance.shadowColor;
    }
    [self hb_restoreBarStyle:style];
}

- (void)hb_restoreBarStyle { [self hb_restoreBarStyle:self.storedBarStyle]; }

- (void)hb_restoreBarStyle:(HBWebBarStyle *)style {

    if (style == nil) return;
    self.tintColor = style.tintColor;
    self.translucent = style.isTranslucent;
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = self.standardAppearance;
        appearance.titleTextAttributes = @{ NSForegroundColorAttributeName : style.tintColor };
        appearance.shadowImage = style.shadowImage;
        appearance.shadowColor = style.shadowColor;
        appearance.backgroundColor = style.barTintColor;
        appearance.backgroundImage = style.backgroundImage;
        self.standardAppearance = appearance;
    } else {
        self.titleTextAttributes = @{ NSForegroundColorAttributeName : style.tintColor };
        self.barTintColor = style.barTintColor;
        self.shadowImage = style.shadowImage;
        [self setBackgroundImage:style.backgroundImage forBarMetrics:UIBarMetricsDefault];
    }
}

- (void)setStoredBarStyle:(HBWebBarStyle *)barStyle {
    objc_setAssociatedObject(self, @selector(storedBarStyle), barStyle, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (HBWebBarStyle *)storedBarStyle { return objc_getAssociatedObject(self, _cmd); }

@end

@implementation UITabBar (Extension)

- (void)hb_applyBarStyle:(HBWebBarStyle *)style {
    
    if (self.storedBarStyle == nil) {
        self.storedBarStyle = [[HBWebBarStyle alloc] init];
        self.storedBarStyle.tintColor = self.tintColor;
        self.storedBarStyle.translucent = self.isTranslucent;
        self.storedBarStyle.barTintColor = self.barTintColor;
        self.storedBarStyle.shadowImage = self.shadowImage;
        self.storedBarStyle.backgroundImage = self.backgroundImage;
        
        if (@available(iOS 13.0, *)) self.storedBarStyle.shadowColor = self.standardAppearance.shadowColor;
    }
    [self hb_restoreBarStyle:style];
}

- (void)hb_restoreBarStyle { [self hb_restoreBarStyle:self.storedBarStyle]; }

- (void)hb_restoreBarStyle:(HBWebBarStyle *)style {
    
    if (style == nil) return;
    self.tintColor = style.tintColor;
    self.translucent = style.isTranslucent;
    if (@available(iOS 13.0, *)) { // iOS13 using appearance
        UITabBarAppearance *appearance = [self.standardAppearance copy];
        appearance.shadowImage = style.shadowImage;
        appearance.backgroundColor = style.barTintColor;
        appearance.backgroundImage = style.backgroundImage;
        appearance.shadowColor = style.shadowColor;
        self.standardAppearance = appearance;
    } else {
        self.shadowImage = style.shadowImage;
        self.barTintColor = style.barTintColor;
        self.backgroundImage = style.backgroundImage;
    }
}

- (void)setStoredBarStyle:(HBWebBarStyle *)barStyle {
    objc_setAssociatedObject(self, @selector(storedBarStyle), barStyle, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (HBWebBarStyle *)storedBarStyle { return objc_getAssociatedObject(self, _cmd); }

@end

@implementation UIToolbar (Extension)

- (void)hb_applyBarStyle:(HBWebBarStyle *)style {

    self.tintColor = style.tintColor;
    self.translucent = style.isTranslucent;
    if (@available(iOS 13.0, *)) {
        UIToolbarAppearance *appearance = [self.standardAppearance copy];
        appearance.shadowImage = style.shadowImage;
        appearance.backgroundColor = style.barTintColor;
        appearance.backgroundImage = style.backgroundImage;
        if (appearance.shadowImage == nil) appearance.shadowColor = [UIColor clearColor];
        else appearance.shadowColor = [UIColor hb_colorWithHex:0xf2f3f4];
        self.standardAppearance = appearance;
    } else {
        self.barTintColor = style.barTintColor;
        [self setShadowImage:style.shadowImage forToolbarPosition:UIToolbarPositionAny];
        [self setBackgroundImage:style.backgroundImage forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    }
}

- (void)setStoredBarStyle:(HBWebBarStyle *)barStyle { }
- (HBWebBarStyle *)storedBarStyle { return nil; }
- (void)hb_restoreBarStyle { }

@end

