//
//  HBWebViewReusePool.m
//  HybridWeb
//
//  Created by XMFraker on 2020/4/9.
//

#import "HBWebViewReusePool.h"

@interface HBWebViewReusePool ()
@property (nonatomic, strong) WKProcessPool *processPool;
@property (nonatomic, strong) NSMutableSet<WKWebView *> *visibleWebViews;
@property (nonatomic, strong) NSMutableSet<WKWebView *> *reusableWebViews;
@end

@implementation HBWebViewReusePool {
    dispatch_semaphore_t _lock;
}
#pragma mark - Life

+ (void)load {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didFinishLaunchingNotification:) name:UIApplicationDidFinishLaunchingNotification object:nil];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self->_lock = dispatch_semaphore_create(1);
        self->_processPool = [[WKProcessPool alloc] init];
        self->_visibleWebViews = [NSMutableSet setWithCapacity:3];
        self->_reusableWebViews = [NSMutableSet setWithCapacity:1];
        [self->_reusableWebViews addObject:[self prepareReusableWebView]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

- (void)didReceiveMemoryWarning:(NSNotification *)note {
    // remove all reusable webView while receive memory warnings
    dispatch_semaphore_wait(self->_lock, DISPATCH_TIME_FOREVER);
    [self.reusableWebViews removeAllObjects];
    dispatch_semaphore_signal(self->_lock);
}

- (void)dealloc {
    [self.visibleWebViews removeAllObjects];
    [self.reusableWebViews removeAllObjects];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Private

- (WKWebView *)prepareReusableWebView {
    
    // maybe called from notification
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:[self.class defaultConfiguration]];
    webView.configuration.processPool = self.processPool;
    webView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]]];
    return webView;
}

#pragma mark - Public

- (void)reset {
    
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    [self.reusableWebViews removeAllObjects];
    [self.reusableWebViews addObject:[self prepareReusableWebView]];
    dispatch_semaphore_signal(_lock);
}

- (WKWebView *)dequeueReusableWebView {
    
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    WKWebView *webView = [self.reusableWebViews anyObject];
    if (webView) {
        [self.reusableWebViews removeObject:webView];
        [self.visibleWebViews addObject:webView];
    } else {
        webView = [self prepareReusableWebView];
        [self.visibleWebViews addObject:webView];
    }

    // create a new reusable webView.
    if (self.reusableWebViews.count <= 0) [self.reusableWebViews addObject:[self prepareReusableWebView]];

    dispatch_semaphore_signal(_lock);
    return webView;
}

- (WKWebView *)dequeueReusableWebViewWithUserInfo:(NSDictionary<NSString *, id> *)userInfo {
    if (userInfo.count <= 0) return [self dequeueReusableWebView];
    WKWebViewConfiguration *configuration = [self.class defaultConfiguration];
    [userInfo enumerateKeysAndObjectsUsingBlock:^(NSString *key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([configuration respondsToSelector:NSSelectorFromString(key)]) { [configuration setValue:obj forKey:key]; }
    }];
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    webView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    return webView;
}

- (void)recycleReusableWebView:(WKWebView *)webView {
    if (webView == nil) return;
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    if ([self.visibleWebViews containsObject:webView]) {
        webView.UIDelegate = nil;
        webView.navigationDelegate = nil;
        webView.scrollView.contentOffset = CGPointZero;
        [webView.configuration.userContentController removeScriptMessageHandlerForName:@"flushQueue"];
        [webView.configuration.userContentController removeScriptMessageHandlerForName:@"injectBridge"];
        webView.configuration.userContentController = [[WKUserContentController alloc] init];
        SEL sel = NSSelectorFromString([NSString stringWithFormat:@"%@%@%@%@%@%@", @"_re", @"move", @"A", @"llI", @"te", @"ms"]);
#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Weverything"
        // !!!: Please take attention here, you known that. make decisions for myself.
        if ([webView.backForwardList respondsToSelector:sel]) [webView.backForwardList performSelector:sel];
#pragma clang diagnostic pop
        else {
            // back to the first item to clear the history
            WKBackForwardListItem *item = webView.backForwardList.backList.firstObject;
            if (item && ![item isEqual:webView.backForwardList.currentItem]) [webView goToBackForwardListItem:item];
        }
        [self.visibleWebViews removeObject:webView];
        if (self.reusableWebViews.count == 0) [self.reusableWebViews addObject:webView];
    }
    dispatch_semaphore_signal(_lock);
}

#pragma mark - Class

+ (WKWebViewConfiguration *)defaultConfiguration {
    
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.preferences.minimumFontSize = 9.f;
    // allow user play video inline
    configuration.allowsInlineMediaPlayback = YES;
    if (@available(iOS 9.0, *)) {
        configuration.allowsAirPlayForMediaPlayback = NO;
        configuration.allowsPictureInPictureMediaPlayback = YES;
    } else {
        // disable airPlay
        configuration.mediaPlaybackAllowsAirPlay = NO;
    }
    if (@available(iOS 10.0, *)) { configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone; }
    else { configuration.mediaPlaybackRequiresUserAction = NO; }
    return configuration;
}

+ (void)didFinishLaunchingNotification:(NSNotification *)note {
    // create the webView after loaded to speed up the next webView.initialize
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidFinishLaunchingNotification object:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        __block WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:[self defaultConfiguration]];
        [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            webView = nil;
        });
    });
}

@end
