//
//  HBWebConfiguration.h
//  HybridWeb
//
//  Created by XMFraker on 2020/4/13.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HBWebBarStyle : NSObject
/// The value of bar is hide. Default is NO.
@property (nonatomic, assign, getter=isHidden) BOOL hidden;
/// The value of bar is translucent. Default is NO.
@property (nonatomic, assign, getter=isTranslucent) BOOL translucent;
/// The color of title\item of the bar. Default is HEX(0x333333)
@property (nonatomic, copy  ) UIColor *tintColor;
/// The background color of bar. Default is UIColor.white.
@property (nonatomic, copy  ) UIColor *barTintColor;
/// The shadow image of bar. Default is UIImage.new.
@property (nonatomic, copy  , nullable) UIImage *shadowImage;
/// The shadowColor will be apply to the shadow of bar. Over iOS13 if nil or UIColor.clearColor, will hide the shadow. Default is nil.
@property (nonatomic, copy  , nullable) UIColor *shadowColor NS_AVAILABLE_IOS(13.0);
/// The background image of bar. Default is UIImage.color(.white).
@property (nonatomic, copy  , nullable) UIImage *backgroundImage;
@end

@interface HBWebConfiguration : NSObject

// Nav UI
@property (nonatomic, assign) BOOL preferredDefaultStyle;
@property (nonatomic, assign) BOOL hidesBottomBarWhenPushed;
@property (nonatomic, strong) HBWebBarStyle *navBarStyle;
@property (nonatomic, strong) HBWebBarStyle *tabBarStyle;

/// Should show menu on the right. Default is YES.
@property (nonatomic, assign) BOOL showMenu;
/// Auto read the title of webView. Default is YES.
@property (nonatomic, assign) BOOL autoReadTitle;
/// The title will be display default. Default is @"".
@property (nonatomic, copy  ) NSString *defaultTitle;
/// The max title length, the title will be tailed if it's over length. Default is 30.
@property (nonatomic, assign) NSUInteger maxTitleLength;
/// The style of status bar. Default is UIStatusBarStyleDefault.
///
/// Need next steps, then you can config statusBarStyle as your way.
///
/// 1. Set the value of key `View controller-based status bar appearance` in Info.plist to YES.
///
/// 2. If you are using UINavigationController or UITabBarController as Window.rootViewControler, Override the method `childViewControllerForStatusBarStyle`.
///
/// 3. Makesure userInterfaceStyle is Light, you can do nothing if it's dark.
@property (nonatomic, assign) UIStatusBarStyle statusBarStyle;
/// The style of user inerface. Default is UIUserInterfaceStyleLight.
@property (nonatomic, assign) UIUserInterfaceStyle userInterfaceStyle NS_AVAILABLE_IOS(12.0);

// View UI

/// The color of webView\view\webView.scrollView. Default is [UIColor white].
@property (nonatomic, copy) UIColor *backgroundColor;
/// Show the progress of webView loading. Default is YES.
@property (nonatomic, assign) BOOL showProgress;
/// The color of progress bar. Default is RGB(0, 135, 230)
@property (nonatomic, copy) UIColor *progressColor;
/// Should show the domain of current url. Default is NO if it's a local file url, otherwise is YES.
@property (nonatomic, assign) BOOL showDomain;

/// The cache policy of loading request url. Default is NSURLRequestUseProtocolCachePolicy.
@property (nonatomic, assign) NSURLRequestCachePolicy cachePolicy;
/// The timeout of loading request url. Default is 50s.
@property (nonatomic, assign) NSTimeInterval timeoutInterval;

+ (instancetype)defaultConfiguration;

- (BOOL)updateWithUserInfo:(NSDictionary *)userInfo;

@end

//defaultTitle    dt    string    默认标题，在页面第一次加载之前显示在标题栏上    “”    Y
//showLoading    sl    string    YES/NO，是否在页面加载前显示全局菊花    “NO”    Y
//readTitle    rt    string    YES/NO，是否读取网页标题显示在 titleBar 上    “YES”    Y
//bizScenario    bz    string    业务场景来源，这个值会记录到每一个埋点中，可以用来区分不同来源。    “”    -
//backBehavior    bb    string    back/pop/auto 指定后退按钮行为。
//back: 如存在浏览器历史则后退上一页，否则关闭当前 webview。
//pop: 直接关闭当前窗口。
//auto: 在 iOS 上相当于 pop；在 Android 上，toolbar 可见时相当于 back，toolbar 不可见时相当于 pop。
//非 H5App 的通用浏览器模式（appId 为 20000067）为 back，H5App（用 startApp 来启动）为 pop    -
//pullRefresh    pr    string    YES/NO，是否支持下拉刷新。
//只有本地文件允许设置为 YES    “NO”    Y
//toolbarMenu    tm    string    JSON 字符串，更多的菜单项列表（放在分享、字号、复制链接后面）
//例：{“menus”:[{“name”:”恭喜”,”icon”:”H5Service.bundle/h5_popovermenu_share”,”action”:”hello”},{“name”:”发财”,”icon”:”H5Service.bundle/h5_popovermenu_abuse”,”action”:”world”}]}    “”    Y
//showProgress    sp    bool    YES/NO，是否显示加载的进度条    “NO”    -
//canPullDown    pd    string    YES/NO，页面是否支持下拉（显示出黑色背景或者域名）
//只有本地文件允许设置为 NO    “YES”    YES
//showDomain    sd    bool    YES/NO，页面下拉时是否显示域名
//只有本地文件允许设置为 NO，离线包强制设置为 NO，不容许显示    “YES”    -
//backgroundColor    bc    int    设置背景颜色（十进制，例如：bc=16775138）    “”    -
//showOptionMenu    so    bool    YES/NO，是否显示右上角的“…”按钮    对于 H5App 为 NO
//对于非 H5App 为 YES
//showTitleLoading    tl    bool    YES/NO，是否在 TitleBar 的标题左边显示小菊花）    NO    Y
//enableScrollBar    es    bool    YES/NO，是否使用 webview 的滚动条，包括垂直和水平。只对 Android 有效    默认为”YES”    -

NS_ASSUME_NONNULL_END
