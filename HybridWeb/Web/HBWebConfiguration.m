//
//  HBWebConfiguration.m
//  HybridWeb
//
//  Created by XMFraker on 2020/4/13.
//

#import "HBWebConfiguration.h"

#import "UIKit+Extension.h"
#import "WKWebView+HBExtension.h"

static UIImage *__nullable EWImage(id value) {
    if ([value isKindOfClass:[UIImage class]]) return value;
    else if ([value isKindOfClass:[NSString class]]) {
        if ([value hasPrefix:@"http"]) {
            // !!!:
            NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:(NSString *)value]];
            if (data.length > 0) return [UIImage imageWithData:data scale:2.0];
        } else {
            // take as image base64
            NSData *data = [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
            if (data.length > 0) return [UIImage imageWithData:data scale:2.0];
        }
    }
    return nil;
}

static UIColor *__nullable EWColor(id value) {
    if ([value isKindOfClass:[UIColor class]]) return value;
    else if ([value isKindOfClass:[NSString class]]) {
        
        NSString *str = [[(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
        if ([str hasPrefix:@"#"]) str = [str stringByReplacingOccurrencesOfString:@"#" withString:@"0x"];
        if ([str hasPrefix:@"0x"]) str = [str substringFromIndex:2];
        // support style is  RGB RGBA RRGGBB RRGGBBAA
        if (![@[@3, @4, @6, @8] containsObject:@(str.length)]) return nil;
        
        CGFloat red, green, blue, alpha, divisor;
        NSScanner *scanner = [[NSScanner alloc] initWithString:str];
        unsigned long long rgba = 0;
        if (![scanner scanHexLongLong:&rgba]) return nil;
        BOOL hasAlpha = (str.length % 4) == 0;
        if (str.length < 5) {
            divisor = 15.f;
            red = ((rgba & (hasAlpha ? 0xF000 : 0xF00)) >> (hasAlpha ? 12 : 8)) / divisor;
            green = ((rgba & (hasAlpha ? 0x0F00 : 0x0F0)) >> (hasAlpha ? 8 : 4)) / divisor;
            blue = ((rgba & (hasAlpha ? 0x00F0 : 0x00F)) >> (hasAlpha ? 4 : 0)) / divisor;
            alpha = hasAlpha ? ((rgba & 0x000F) / divisor) : 1.0;
        } else {
            divisor = 255.f;
            red = ((rgba & (hasAlpha ? 0xFF000000 : 0xFF0000)) >> (hasAlpha ? 24 : 16)) / divisor;
            green = ((rgba & (hasAlpha ? 0x00FF0000 : 0x00FF00)) >> (hasAlpha ? 16 : 8)) / divisor;
            blue = ((rgba & (hasAlpha ? 0x0000FF00 : 0x0000FF)) >> (hasAlpha ? 8 : 0)) / divisor;
            alpha = hasAlpha ? ((rgba & 0x000000FF) / divisor) : 1.0;
        }
        // ???: maybe use P3Color in the future
//      return [UIColor colorWithDisplayP3Red:red green:green blue:blue alpha:alpha];
        return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
    }
    return nil;
}

@implementation HBWebBarStyle

- (instancetype)init {
    self = [super init];
    if (self) {
        self->_hidden = NO;
        self->_translucent = NO;
        self->_barTintColor = [UIColor whiteColor];
        self->_tintColor = [UIColor hb_colorWithHex:0x333333];
        self->_shadowImage = [UIImage new];
        self->_backgroundImage = nil;
        self->_shadowColor = [UIColor clearColor];
    }
    return self;
}

- (BOOL)isEqualToStyle:(HBWebBarStyle *)style {
    
    if (self.isHidden != style.isHidden) return NO;
    if (self.isTranslucent != style.isTranslucent) return NO;
    if (![self.tintColor isEqual:style.tintColor]) return NO;
    if (![self.barTintColor isEqual:style.barTintColor]) return NO;
    if (![self.shadowImage isEqual:style.shadowImage]) return NO;
    if (![self.backgroundImage isEqual:style.backgroundImage]) return NO;
    return YES;
}

- (BOOL)isEqual:(id)other {
    
    if (![other isKindOfClass:[HBWebBarStyle class]]) return NO;
    if (other == self) return YES;
    return [self isEqualToStyle:other];
}

#pragma mark - Setter

- (void)setTintColor:(UIColor *)tintColor { _tintColor = EWColor(tintColor); }

- (void)setBarTintColor:(UIColor *)barTintColor { _barTintColor = EWColor(barTintColor); }

- (void)setShadowImage:(UIImage *)shadowImage { _shadowImage = EWImage(shadowImage); }

- (void)setShadowColor:(UIColor *)shadowColor { _shadowColor = EWColor(shadowColor); }

- (void)setBackgroundImage:(UIImage *)backgroundImage { _backgroundImage = EWImage(backgroundImage); }

@end

@interface HBWebConfiguration ()
@property (nonatomic, strong) NSMutableSet<Class<UIAppearanceContainer>> *styleClasses;
@end

@implementation HBWebConfiguration

#pragma mark - Life

+ (instancetype)defaultConfiguration {
    return [[HBWebConfiguration alloc] init];
}

- (instancetype)init {

    self = [super init];
    if (self) {
        
        self->_preferredDefaultStyle = YES;
        self->_hidesBottomBarWhenPushed = YES;

        self->_navBarStyle = [[HBWebBarStyle alloc] init];
        self->_tabBarStyle = [[HBWebBarStyle alloc] init];
        
        self->_showDomain = YES;
        
        self->_timeoutInterval = 50.f;
        self->_cachePolicy = NSURLRequestUseProtocolCachePolicy;
        
        self->_backgroundColor = self.navBarStyle.barTintColor;
        
        // progress UI
        self->_showProgress = YES;
        self->_progressColor = [UIColor colorWithRed:0.f green:130.f/255.f blue:230.f/255.f alpha:1.f];

        // Nav UI
        self->_showMenu = YES;
        self->_autoReadTitle = YES;
        self->_maxTitleLength = 30;

        self->_defaultTitle = @"";
        self->_statusBarStyle = UIStatusBarStyleDefault;
        if (@available(iOS 12.0, *)) self->_userInterfaceStyle = UIUserInterfaceStyleLight;
    }
    return self;
}

#pragma mark - Public

- (BOOL)updateWithUserInfo:(NSDictionary *)userInfo {
    if (![userInfo isKindOfClass:[NSDictionary class]] || userInfo.count <= 0) return NO;
    NSArray<NSString *> *availableKeyPaths = [self.propertyKeys copy];
    __block BOOL needUpdateUI = NO;
    [userInfo enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if (![availableKeyPaths containsObject:key]) { HBLogW(@"unsupported keyPath :%@", key); return; }
        if (obj) { [self setValue:obj forKeyPath:key]; needUpdateUI = YES; }
    }];
    return needUpdateUI;
}

#pragma mark - Setter

- (void)setProgressColor:(UIColor *)progressColor {
    UIColor *color = EWColor(progressColor);
    if (color) _progressColor = color;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    UIColor *color = EWColor(backgroundColor);
    if (color) _backgroundColor = color;
}

#pragma mark - Getter

- (NSArray<NSString *> *)propertyKeys {
    
    return @[
        @"preferredDefaultStyle", @"hidesBottomBarWhenPushed",
    
             @"navBarStyle.hidden", @"navBarStyle.translucent", @"navBarStyle.tintColor", @"navBarStyle.barTintColor", @"navBarStyle.shadowImage", @"navBarStyle.shadowColor", @"navBarStyle.backgroundImage",
    
             @"tabBarStyle.hidden", @"tabBarStyle.translucent", @"tabBarStyle.tintColor", @"tabBarStyle.barTintColor", @"tabBarStyle.shadowImage", @"tabBarStyle.shadowColor", @"tabBarStyle.backgroundImage",
    
             // control the statusBarStyle
             @"statusBarStyle", @"userInterfaceStyle",
             
             @"showMenu", @"autoReadTitle", @"defaultTitle", @"maxTitleLength", @"backgroundColor", @"showProgress",
             @"progressColor", @"showDomain",
             
         @"cachePolicy", @"timeoutInterval"
    ];
}

/// Return all the supported properties of configuration.
- (NSDictionary<NSString *, id> *)properties {

    NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithCapacity:self.propertyKeys.count];
    for (NSString *keyPath in self.propertyKeys) {
        id value = [self valueForKeyPath:keyPath];
        if (value == nil) [properties setObject:[NSNull null] forKey:keyPath];
        if ([value isKindOfClass:[UIColor class]]) [properties setObject:((UIColor *)value).hb_hex ? : [NSNull null] forKey:keyPath];
        else if ([value isKindOfClass:[UIImage class]]) [properties setObject:((UIImage *)value).hb_base64 ? : [NSNull null] forKey:keyPath];
        else [properties setObject:value ? : [NSNull null] forKey:keyPath];
    }
    return [properties copy];
}

@end
