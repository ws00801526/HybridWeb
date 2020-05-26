//
//  HBWebController.m
//  HybridWeb
//
//  Created by XMFraker on 2020/4/9.
//

#import "HBWebController.h"

#import "HBWebViewReusePool.h"
#import "HBJSBridge.h"

#import "HBProgressView.h"

#import "HBInterceptor_Domain.h"
#import "HBInterceptor_ToolBar.h"

#import "UIKit+Extension.h"
#import "WKWebView+HBExtension.h"

#if __has_include(<HybridWeb/HBInterceptor_Bridge.h>)
    #import "HBInterceptor_Bridge.h"
#endif

static HBWebViewReusePool *kEWReusePool;
@interface HBWebController ()

@property (nonatomic, weak  ) WKWebView *webView;
@property (nonatomic, strong) HBJSBridge *bridge;

@property (nonatomic, copy) NSURL *startURL;
@property (nonatomic, copy) NSDictionary *options;

/// NavBar UI
@property (nonatomic, strong) UIBarButtonItem *closeItem;
@property (nonatomic, strong) UIBarButtonItem *menuItem;

/// Progress UI
@property (nonatomic, strong) HBProgressView *progressView;

@property (nonatomic, strong) NSMutableArray<id<HBInterceptor>> *interceptors;

@property (nonatomic, copy) NSDictionary<NSString *, id> *restoredTabBarInfo;
@property (nonatomic, copy) NSDictionary<NSString *, id> *restoredNavBarInfo;

@property (nonatomic, strong, readonly, class) NSMutableSet<Class<HBInterceptor>> *globalInterceptors;
@end

@implementation HBWebController

#pragma mark - Life

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    return [self initWithURL:nil configuration:nil];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    return [self initWithURL:nil configuration:nil];
}

- (instancetype)initWithURL:(NSURL *)URL {
    return [self initWithURL:URL configuration:nil];
}

- (instancetype)initWithURL:(nullable NSURL *)URL configuration:(nullable HBWebConfiguration *)configuration {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        
        self->_interceptors = [NSMutableArray arrayWithCapacity:3];
        if (URL) self->_startURL = [URL copy];
        self->_configuration = configuration ? : [HBWebConfiguration defaultConfiguration];
        
        self.hidesBottomBarWhenPushed = self->_configuration.hidesBottomBarWhenPushed;
        for (Class klass in self.class.globalInterceptors) {
            id<HBInterceptor> interceptor = [[klass alloc] initWithWebController:self];
            if (interceptor != nil) [self->_interceptors addObject:interceptor];
        }
        [self->_interceptors sortUsingComparator:^NSComparisonResult(id<HBInterceptor> obj1, id<HBInterceptor> obj2) {
            return obj1.priority >= obj2.priority ? NSOrderedDescending : NSOrderedAscending;
        }];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAppBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAppWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc {

    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.webView removeObserver:self forKeyPath:@"URL"];
    [self.webView removeObserver:self forKeyPath:@"title"];
    [self.webView removeObserver:self forKeyPath:@"canGoBack"];
    [self.webView removeObserver:self forKeyPath:@"canGoForward"];
    [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
    
    HBLog(@"webView will be recycled :%@", self.webView);
    HBLog(@"the session of startPage will dealloc :%@", self.startURL);
    [kEWReusePool recycleReusableWebView:self.webView];
    
    @synchronized (self) { [self->_interceptors removeAllObjects]; }
}

#pragma mark - Override

- (void)viewDidLoad {

    [super viewDidLoad];
    [self setupUI];
    [self setupObservers];
    [self updateUIIfConfigurationChanged];

    NSMutableURLRequest *request = self.startURL.isFileURL ? nil : [NSMutableURLRequest requestWithURL:self.startURL cachePolicy:self.configuration.cachePolicy timeoutInterval:self.configuration.timeoutInterval];

    for (id<HBInterceptor> interceptor in self.interceptors) {
        if (interceptor.webController != self) continue;
        
        if ([interceptor respondsToSelector:@selector(webControllerViewDidLoaded:)])
            dispatch_async(dispatch_get_main_queue(), ^{ [interceptor webControllerViewDidLoaded:self]; });
            
        /// can't modify request while load file url
        if (request && [interceptor respondsToSelector:@selector(webController:willLoadURLRequest:)])
            request = [interceptor webController:self willLoadURLRequest:request];
    }

    if (self.startURL.isFileURL) {
        if (@available(iOS 9.0, *)) [self.webView loadFileURL:self.startURL allowingReadAccessToURL:self.startURL.URLByDeletingLastPathComponent];
        else {
            // !!!: load html data only once, shouldn't reload by webView.
            NSString *html = [NSString stringWithContentsOfURL:self.startURL encoding:NSUTF8StringEncoding error:0];
            [self.webView loadHTMLString:html baseURL:[self.startURL URLByDeletingLastPathComponent]];
        }
    } else if (request) {
        [self.webView loadRequest:[request copy]];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    
    if (object == self.webView) {
        WKWebView *webView = (WKWebView *)object;

        if (self.configuration.showProgress &&
            [@"estimatedProgress" isEqualToString:keyPath]) {
            if (self.progressView.superview == nil) [self.view addSubview:self.progressView];
            [self.progressView setProgress:webView.estimatedProgress animated:YES];
        }
        
        if (self.configuration.autoReadTitle && [@"title" isEqualToString:keyPath])
            self.navigationItem.title = [self tailTitle:self.webView.title];
        
        for (id<HBInterceptor> interceptor in self.interceptors) {
            if (interceptor.webController != self) continue;
            if (![interceptor respondsToSelector:@selector(webController:observerValueDidChangedForKeyPath:)]) continue;
            [interceptor webController:self observerValueDidChangedForKeyPath:keyPath];
        }
    } else [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    NSArray<id<HBInterceptor>> *interceptors = [self.interceptors copy];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        for (id<HBInterceptor> interceptor in interceptors) {
            if (interceptor.webController != self) continue;
            if (![interceptor respondsToSelector:@selector(webController:willTransitionToSize:withContext:)]) continue;
            [interceptor webController:self willTransitionToSize:size withContext:context];
        }
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        for (id<HBInterceptor> interceptor in interceptors) {
            if (interceptor.webController != self) continue;
            if (![interceptor respondsToSelector:@selector(webController:didTransitionToSize:withContext:)]) continue;
            [interceptor webController:self didTransitionToSize:size withContext:context];
        }
    }];
}

- (BOOL)prefersStatusBarHidden { return NO; }
- (UIStatusBarStyle)preferredStatusBarStyle { return self.configuration.statusBarStyle; }
- (UIUserInterfaceStyle)overrideUserInterfaceStyle { return self.configuration.userInterfaceStyle; }
- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation { return UIStatusBarAnimationFade; }

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if (self.configuration.preferredDefaultStyle) {
        UINavigationBar *navBar = self.navigationController.navigationBar;
        [self.navigationController setNavigationBarHidden:navBar.storedBarStyle.isHidden animated:animated];
        [UIView performWithoutAnimation:^{
            [navBar hb_restoreBarStyle];
            [self.tabBarController.tabBar hb_restoreBarStyle];
        }];
    }
    
    [self.bridge dispatchEvent:@"pagePause" options:@{ @"startUrl" : self.startURL.absoluteString ? : @"", @"currentUrl" : self.webView.URL.absoluteString ? : @"" }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateUIIfConfigurationChanged];
    [self.bridge dispatchEvent:@"pageResume" options:@{ @"startUrl" : self.startURL.absoluteString ? : @"", @"currentUrl" : self.webView.URL.absoluteString ? : @"" }];
}

#pragma mark - Public

- (void)refreshWithUserInfo:(NSDictionary *)userInfo { [self.webView reload]; }

- (void)updateUIIfConfigurationChanged {

    // background
    self.view.backgroundColor = self.webView.backgroundColor = self.webView.scrollView.backgroundColor = self.configuration.backgroundColor;
    
    // progress
    self.progressView.hidden = !self.configuration.showProgress;
    self.progressView.alpha = (self.progressView.progress >= 1.f || self.progressView.progress <= 0.f) ? 0.f : 1.f;
    self.progressView.trackTintColor = self.configuration.backgroundColor;
    self.progressView.progressTintColor = self.configuration.progressColor;
    
    // nav
//    self.menuItem.tintColor = self.closeItem.tintColor = self.configuration.navBarStyle.tintColor;
    UINavigationBar *navBar = self.navigationController.navigationBar;
    if (self.configuration.preferredDefaultStyle) {
        [navBar hb_applyBarStyle:self.configuration.navBarStyle];
        [self.navigationController setNavigationBarHidden:self.configuration.navBarStyle.isHidden animated:YES];
    } else {
        [self.navigationController setNavigationBarHidden:navBar.storedBarStyle.isHidden animated:YES];
        [navBar hb_restoreBarStyle];
    }
    
    if (self.webView.title.length <= 0) self.navigationItem.title = [self tailTitle:self.configuration.defaultTitle];
    else self.navigationItem.title = [self tailTitle:self.webView.title];
    
    self.navigationItem.rightBarButtonItem = self.configuration.showMenu ? self.menuItem : nil;
    self.navigationItem.rightBarButtonItem.tintColor = self.configuration.navBarStyle.tintColor;
    
    if (self.configuration.preferredDefaultStyle) {
        [self.tabBarController.tabBar hb_applyBarStyle:self.configuration.tabBarStyle];
    } else {
        [self.tabBarController.tabBar hb_restoreBarStyle];
    }
    
    // domain
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"class = %@", [HBInterceptor_Domain class]];
    if (self.configuration.showDomain) {
        NSArray<HBInterceptor_Domain *> *interceptors = [self.interceptors filteredArrayUsingPredicate:predicate];
        if (interceptors.count <= 0) [self addInterceptor:[[HBInterceptor_Domain alloc] init]];
    } else {
        NSArray<HBInterceptor_Domain *> *interceptors = [self.interceptors filteredArrayUsingPredicate:predicate];
        for (HBInterceptor_Domain *interceptor in interceptors) { [self removeInterceptor:interceptor]; }
    }

    self.webView.UIDelegate = (id<WKUIDelegate>)self;
    [self setNeedsStatusBarAppearanceUpdate];
}

#pragma mark - Private

- (void)viewBack {
    if (self.presentingViewController) [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
    else [self.navigationController popViewControllerAnimated:YES];
}

- (void)menuAction {
    // TODO: do menu action
    UIBarStyle barStyle = self.navigationController.navigationBar.barStyle;
    if (barStyle == UIBarStyleDefault) [self.navigationController.navigationBar setBarStyle:UIBarStyleBlack];
    else [self.navigationController.navigationBar setBarStyle:UIBarStyleDefault];
}

- (void)setupObservers {
    
    NSKeyValueObservingOptions options = NSKeyValueObservingOptionNew;
    [self.webView addObserver:self forKeyPath:@"URL" options:options context:nil];
    [self.webView addObserver:self forKeyPath:@"title" options:options context:nil];
    [self.webView addObserver:self forKeyPath:@"canGoBack" options:options context:nil];
    [self.webView addObserver:self forKeyPath:@"canGoForward" options:options context:nil];
    [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:options | NSKeyValueObservingOptionInitial context:nil];
}

- (void)setupUI {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{  kEWReusePool = [[HBWebViewReusePool alloc] init];  });
    WKWebView *webView = [kEWReusePool dequeueReusableWebView];
    self.bridge = [[HBJSBridge alloc] initWithWebView:webView];
    webView.hidden = YES;
    [self.view addSubview:self.webView = webView];
    
    self.webView.scrollView.delegate = (id<UIScrollViewDelegate>)self;
    [self.bridge setWebViewDelegate:(id<WKNavigationDelegate>)self];

    UIImage *closeImage = [UIImage hb_imageWithNamed:@"web_ui_close" ofBundle:@"Web"];
    UIBarButtonItem *closeItem = [[UIBarButtonItem alloc] initWithImage:closeImage style:UIBarButtonItemStylePlain target:self action:@selector(viewBack)];
    self.navigationItem.leftBarButtonItem = closeItem;
    self.navigationItem.backBarButtonItem = nil;
    self.navigationItem.hidesBackButton = YES;
    self.navigationItem.leftItemsSupplementBackButton = YES;
    
    [self.view addSubview:self.progressView];
        
    [self setupFrame];
    dispatch_async(dispatch_get_main_queue(), ^{ [self setupFrame]; });

    if (@available(iOS 11.0, *))
        self.webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    else self.automaticallyAdjustsScrollViewInsets = NO;
}

- (void)setupFrame {
    self.webView.frame = self.view.bounds;
    self.webView.scrollView.contentInset = self.webContentInsets;
    self.progressView.frame = (CGRect) { CGPointMake(0.f, self.webContentInsets.top), self.progressView.frame.size };
}

#pragma mark - Events

- (void)handleAppBecomeActive:(NSNotification *)note {
    [self.bridge dispatchEvent:@"appResume" options:@{ @"startUrl" : self.startURL.absoluteString ? : @"", @"currentUrl" : self.webView.URL.absoluteString ? : @"" }];
}

- (void)handleAppWillResignActive:(NSNotification *)note {
    [self.bridge dispatchEvent:@"appPause" options:@{ @"startUrl" : self.startURL.absoluteString ? : @"", @"currentUrl" : self.webView.URL.absoluteString ? : @"" }];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    for (id<HBInterceptor> interceptor in self.interceptors) {
        if (interceptor.webController != self) continue;
        if (![interceptor respondsToSelector:@selector(scrollViewDidScroll:)]) continue;
        [interceptor scrollViewDidScroll:scrollView];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {

    for (id<HBInterceptor> interceptor in self.interceptors) {
        if (interceptor.webController != self) continue;
        if (![interceptor respondsToSelector:@selector(scrollViewWillBeginDragging:)]) continue;
        [interceptor scrollViewWillBeginDragging:scrollView];
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    
    for (id<HBInterceptor> interceptor in self.interceptors) {
        if (interceptor.webController != self) continue;
        if (![interceptor respondsToSelector:@selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)]) continue;
        [interceptor scrollViewWillEndDragging:scrollView withVelocity:velocity targetContentOffset:targetContentOffset];
    }
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    
    for (id<HBInterceptor> interceptor in self.interceptors) {
        if (interceptor.webController != self) continue;
        if (![interceptor respondsToSelector:@selector(webController:didLoadURL:error:)]) continue;
        [interceptor webController:self didLoadURL:webView.URL error:nil];
    }
//    if (webView.isHidden && CGPointEqualToPoint(webView.scrollView.contentOffset, CGPointZero))
//        webView.scrollView.contentOffset = CGPointMake(0.f, -88.f);
    if (webView.isHidden) webView.hidden = NO;
    HBLog(@"sss didFinishNavigation :%@", webView.scrollView);
//    dispatch_async(dispatch_get_main_queue(), ^{ [webView.scrollView setContentOffset:CGPointMake(0.f, -88.f) animated:NO]; });
}

- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {

    for (id<HBInterceptor> interceptor in self.interceptors) {
        if (interceptor.webController != self) continue;
        if (![interceptor respondsToSelector:@selector(webController:didLoadURL:error:)]) continue;
        [interceptor webController:self didLoadURL:webView.URL error:error];
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction preferences:(WKWebpagePreferences *)preferences decisionHandler:(void (^)(WKNavigationActionPolicy, WKWebpagePreferences *))decisionHandler  API_AVAILABLE(ios(13.0)){
    
    HBWebViewDecidePolicy policy = HBWebViewDecidePolicyIgnored;
    for (id<HBInterceptor> interceptor in self.interceptors) {
        if (interceptor.webController != self) continue;
        if (![interceptor respondsToSelector:@selector(webController:decidePolicyForNavigationAction:)]) continue;
        policy = [interceptor webController:self decidePolicyForNavigationAction:navigationAction];
        if (policy != HBWebViewDecidePolicyIgnored) break;
    }
    if (policy == HBWebViewDecidePolicyIgnored) policy = HBWebViewDecidePolicyAllow;
    decisionHandler((WKNavigationActionPolicy)policy, [[WKWebpagePreferences alloc] init]);
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    
    HBWebViewDecidePolicy policy = HBWebViewDecidePolicyIgnored;
    for (id<HBInterceptor> interceptor in self.interceptors) {
        if (interceptor.webController != self) continue;
        if (![interceptor respondsToSelector:@selector(webController:decidePolicyForNavigationAction:)]) continue;
        policy = [interceptor webController:self decidePolicyForNavigationAction:navigationAction];
        if (policy != HBWebViewDecidePolicyIgnored) break;
    }
    if (policy == HBWebViewDecidePolicyIgnored) policy = HBWebViewDecidePolicyAllow;
    decisionHandler((WKNavigationActionPolicy)policy);
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    
    HBWebViewDecidePolicy policy = HBWebViewDecidePolicyIgnored;
    for (id<HBInterceptor> interceptor in self.interceptors) {
        if (interceptor.webController != self) continue;
        if (![interceptor respondsToSelector:@selector(webController:decidePolicyForNavigationResponse:)]) continue;
        policy = [interceptor webController:self decidePolicyForNavigationResponse:navigationResponse];
        if (policy != HBWebViewDecidePolicyIgnored) break;
    }
    if (policy == HBWebViewDecidePolicyIgnored) policy = HBWebViewDecidePolicyAllow;
    decisionHandler((WKNavigationResponsePolicy)policy);
}

#pragma mark - WKUIDelegate

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        completionHandler();
    }]];
    [self showDetailViewController:alertController sender:self];
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler {
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        completionHandler(YES);
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        completionHandler(NO);
    }]];
    [self showDetailViewController:alertController sender:self];
}

- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable))completionHandler {
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:prompt preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = prompt;
        textField.text = defaultText;
    }];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = nil;
        if (alertController.textFields && alertController.textFields.count) { text = alertController.textFields.firstObject.text; }
        completionHandler(text);
    }]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        completionHandler(nil);
    }]];
    [self showDetailViewController:alertController sender:self];
}

#pragma mark - Getter

- (UIEdgeInsets)webContentInsets {
    
    UIEdgeInsets insets = UIEdgeInsetsZero;
    if (self.navigationController.navigationBar.isTranslucent) {
        if (!self.configuration.preferredDefaultStyle || !self.configuration.navBarStyle.isHidden) {
            insets.top += CGRectGetHeight(self.navigationController.navigationBar.frame);
            insets.top += CGRectGetHeight([UIApplication sharedApplication].statusBarFrame);
        }
    }
    
    if (self.tabBarController.tabBar.isTranslucent && !self.hidesBottomBarWhenPushed) {
        insets.bottom += CGRectGetHeight(self.tabBarController.tabBar.frame);
    }
    return insets;
}

- (BOOL)canGoBack {
    if (self.webView == nil) return NO;
    if (!self.webView.canGoBack) return NO;
    return self.webView.backForwardList.backItem.URL.hb_isNotEmpty || self.webView.backForwardList.backList.count >= 3;
}

- (BOOL)canGoForward {
    if (self.webView == nil) return NO;
    if (!self.webView.canGoForward) return NO;
    return ![self.webView.backForwardList.forwardItem.URL isEqual:self.startURL];
    return self.webView.canGoForward;
}

- (HBProgressView *)progressView {
    
    if (!_progressView) {
        _progressView = [[HBProgressView alloc] initWithFrame:CGRectZero];
        _progressView.frame = CGRectMake(0.f, 0.f, CGRectGetWidth(self.view.bounds), 2.f);
        _progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
        _progressView.progressTintColor = self.configuration.progressColor;
        _progressView.trackTintColor = self.configuration.backgroundColor;
        _progressView.autoHide = YES;
    }
    return _progressView;
}

- (UIBarButtonItem *)menuItem {
    if (_menuItem) return _menuItem;
    UIImage *moreImage = [UIImage hb_imageWithNamed:@"web_ui_more" ofBundle:@"Web"];
    _menuItem = [[UIBarButtonItem alloc] initWithImage:moreImage style:UIBarButtonItemStylePlain target:self action:@selector(menuAction)];
    _menuItem.tintColor = [UIColor hb_colorWithHex:0x333333];
    return _menuItem;
}

- (NSString *)tailTitle:(NSString *)origin {
    if (origin.length < self.configuration.maxTitleLength) return origin;
    return [[origin substringToIndex:self.configuration.maxTitleLength] stringByAppendingString:@"..."];
}

#pragma mark - Class

+ (NSMutableSet<Class<HBInterceptor>> *)globalInterceptors {
    static NSMutableSet<Class<HBInterceptor>> *globals = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        globals = [NSMutableSet set];
        [globals addObject:[HBInterceptor_ToolBar class]];
    #if __has_include(<HybridWeb/HBInterceptor_Bridge.h>)
        [globals addObject:[HBInterceptor_Bridge class]];
    #endif
    });
    return globals;
}

@end


@implementation HBWebController (Interceptor)

- (void)addInterceptor:(id<HBInterceptor>)interceptor {
    
    BOOL needViewDidLoad = self.isViewLoaded && [interceptor respondsToSelector:@selector(webControllerViewDidLoaded:)];
    @synchronized (self) {
        if (![self.interceptors containsObject:interceptor]) {
            interceptor.webController = self;
            [self->_interceptors addObject:interceptor];
            [self->_interceptors sortedArrayUsingComparator:^NSComparisonResult(id<HBInterceptor> obj1, id<HBInterceptor> obj2) {
                return obj1.priority >= obj2.priority ? NSOrderedDescending : NSOrderedAscending;
            }];
        } else needViewDidLoad = NO;
    }
    if (needViewDidLoad) [interceptor webControllerViewDidLoaded:self];
}

- (void)removeInterceptor:(id<HBInterceptor>)interceptor {
    @synchronized (self) {
        interceptor.webController = nil;
        if ([self->_interceptors containsObject:interceptor]) [self->_interceptors removeObject:interceptor];
    }
}

+ (void)registerGlobalInterceptor:(Class<HBInterceptor>)interceptor {
    [[HBWebController globalInterceptors] addObject:interceptor];
}

@end


#if DEBUG
@implementation HBWebController (Debug)

+ (void)startDebugOf:(__kindof UIViewController *)parent {
    [self startDebugOf:parent userInfo:nil];
}

+ (void)startDebugOf:(__kindof UIViewController *)parent userInfo:(nullable NSDictionary *)userInfo {
    
    NSBundle *klassBundle = [NSBundle bundleForClass:self];
    NSURL *fileURL = [klassBundle URLForResource:@"Web.bundle/demo" withExtension:@"html"];
    HBWebConfiguration *configuration = [HBWebConfiguration defaultConfiguration];
    if (userInfo.count) [configuration updateWithUserInfo:userInfo];
    HBWebController *controller = [[HBWebController alloc] initWithURL:fileURL configuration:configuration];
    if (parent.navigationController) [parent.navigationController pushViewController:controller animated:YES];
    else {
        UINavigationController *wrapper = [[UINavigationController alloc] initWithRootViewController:controller];
        [parent presentViewController:wrapper animated:YES completion:NULL];
    }
}

@end
#endif
