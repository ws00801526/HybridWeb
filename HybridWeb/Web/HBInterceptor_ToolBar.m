//
//  HBInterceptor_ToolBar.m
//  HybridWeb
//
//  Created by XMFraker on 2020/4/14.
//

#import "HBInterceptor_ToolBar.h"

#import "UIKit+Extension.h"
#import "WKWebView+HBExtension.h"

static CGFloat const kEWToolBarHeight = 50.f;

@interface HBWebController (Private)
@property (nonatomic, assign, readonly) UIEdgeInsets webContentInsets;
@property (nonatomic, strong, readonly) UIProgressView *progressView;
@end

@interface HBInterceptor_ToolBar ()

@property (nonatomic, assign, readonly) UIEdgeInsets webContentInsets;
@property (nonatomic, weak,   readonly) HBWebConfiguration *configuration;

@property (nonatomic, assign) BOOL hasLoadedURL;
/// ToolBar UI
@property (nonatomic, weak) UIToolbar *toolBar;
@property (nonatomic, weak) UIBarButtonItem *backItem;
@property (nonatomic, weak) UIBarButtonItem *forwardItem;


@property (nonatomic, strong) dispatch_source_t timer;
@property (nonatomic, assign, readonly) CGFloat toolBarMinY;
@property (nonatomic, assign, readonly) CGFloat toolBarMaxY;
@property (nonatomic, assign, readonly) BOOL shouldToolBarVisible;

@property (nonatomic, assign, readonly) BOOL canGoBack;
@property (nonatomic, assign, readonly) BOOL canGoForward;

@end

@implementation HBInterceptor_ToolBar

#pragma mark - Life

- (instancetype)initWithWebController:(__kindof HBWebController *)webController {
    if (webController == nil) return nil;
    self = [super init];
    if (self) self.webController = webController;
    return self;
}

- (void)dealloc {
    if (self.timer) { dispatch_source_cancel(self.timer); self.timer = nil; }
    if (self.toolBar.superview) [self.toolBar removeFromSuperview];
}

#pragma mark - Private

- (void)updateToolBarVisible:(BOOL)isVisible animated:(BOOL)animated {
    
    // the position of toolBar is correct. don't update it again.
    if (isVisible && CGRectGetMinY(self.toolBar.frame) <= self.toolBarMinY) return;
    if (!isVisible && CGRectGetMinY(self.toolBar.frame) >= self.toolBarMaxY) return;
    
    kEWScrollOverLimit = NO;
    kEWScrollViewOffset = CGPointZero;
    CGFloat const theY = isVisible ? self.toolBarMinY : self.toolBarMaxY;
    [UIView animateWithDuration:animated ? .25f : CGFLOAT_MIN animations:^{
        // update tool bar frame
        self.toolBar.frame = (CGRect) { CGPointMake(0.f, theY), self.toolBar.frame.size };

        // update webView.scrollView contentInset
        UIEdgeInsets insets = self.webController.webView.scrollView.contentInset;
        insets.bottom = isVisible ? kEWToolBarHeight : self.webContentInsets.bottom;
        if (isVisible && !self.configuration.tabBarStyle.isHidden) insets.bottom += CGRectGetHeight(self.webController.tabBarController.tabBar.frame);
        self.webController.webView.scrollView.contentInset = insets;
    } completion:^(BOOL finished) {
        if (!isVisible && !finished) return;
        self.backItem.enabled = self.canGoBack;
        self.forwardItem.enabled = self.canGoForward;
    }];
}

- (void)setupTooBarUI {
    
    CGFloat const width = CGRectGetWidth(UIScreen.mainScreen.bounds);
    UIToolbar *toolBar = [[UIToolbar alloc] initWithFrame:(CGRect){ CGPointMake(0.f, self.toolBarMaxY), CGSizeMake(width, 50.f) }];
    [toolBar hb_applyBarStyle:self.configuration.tabBarStyle];
    toolBar.delegate = (id<UIToolbarDelegate>)self;
    toolBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    
    UIBarButtonItem *flexLeftItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
    
    UIImage *image = [UIImage hb_imageWithNamed:@"web_ui_arrow_left" ofBundle:@"Web"];
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(goBack)];
    UIBarButtonItem *fixedItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:NULL];
    fixedItem.width = 50.f;
    image = [UIImage hb_imageWithNamed:@"web_ui_arrow_right" ofBundle:@"Web"];
    UIBarButtonItem *forwardItem = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(goForward)];
    UIBarButtonItem *flexRightItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
    
    forwardItem.enabled = backItem.enabled = NO;
    toolBar.items = @[flexLeftItem, self.backItem = backItem, fixedItem, self.forwardItem = forwardItem, flexRightItem];
    [self.webController.view addSubview:self.toolBar = toolBar];
}

#pragma mark - Events

- (void)goForward {
    
    if (self.canGoForward) [self.webController.webView goForward];
    else self.forwardItem.enabled = self.canGoForward;
}

- (void)goBack {    
    
    if (self.canGoBack) [self.webController.webView goBack];
    else self.backItem.enabled = self.canGoBack;
}

#pragma mark - UIToolBarDelegate

- (UIBarPosition)positionForBar:(id <UIBarPositioning>)bar { return UIBarPositionBottom; }

#pragma mark - HBInterceptor

- (void)webController:(HBWebController *)controller didLoadURL:(NSURL *)URL error:(nullable NSError *)error {
    if (self.shouldToolBarVisible) [self updateToolBarVisible:YES animated:YES];
    if (!self.hasLoadedURL && URL.hb_isNotEmpty) self.hasLoadedURL = YES;
}

- (void)webController:(HBWebController *)controller observerValueDidChangedForKeyPath:(NSString *)keyPath {
    
    if (!self.hasLoadedURL) return;
    if (![@[@"cangoback", @"cangoforward", @"estimatedprogress"] containsObject:[keyPath lowercaseString]]) return;
    if ([@"estimatedProgress" isEqualToString:keyPath] && controller.webView.estimatedProgress <= 0.4f) return;
    if (self.backItem.enabled != self.canGoBack) self.backItem.enabled = self.canGoBack;
    if (self.forwardItem.enabled != self.canGoForward) self.forwardItem.enabled = self.canGoForward;
}

- (void)webControllerViewDidLoaded:(HBWebController *)controller {
    [self setupTooBarUI];
}

- (WKNavigationActionPolicy)webController:(HBWebController *)controller decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction {
    NSURL *targetURL = navigationAction.request.URL;
    if (!targetURL.hb_isNotEmpty) return WKNavigationActionPolicyIgnored;
    if (self.shouldToolBarVisible) [self updateToolBarVisible:YES animated:YES];
    else if (![targetURL isEqual:self.webController.startURL]) [self updateToolBarVisible:YES animated:YES];
    return WKNavigationActionPolicyIgnored;
}

- (void)webController:(HBWebController *)controller willTransitionToSize:(CGSize)size withContext:(id<UIViewControllerTransitionCoordinatorContext>)context {
    if (self.shouldToolBarVisible) [self updateToolBarVisible:NO animated:YES];
}

- (void)webController:(HBWebController *)controller didTransitionToSize:(CGSize)size withContext:(id<UIViewControllerTransitionCoordinatorContext>)context {
    if (self.shouldToolBarVisible) [self updateToolBarVisible:YES animated:YES];
}

#pragma mark - UIScrollViewDelegate

static CGPoint kEWScrollViewOffset;
static BOOL    kEWScrollOverLimit = NO;

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
        
    if (!self.webController.canGoBack && !self.webController.canGoForward) return;
    if (scrollView.contentSize.height < CGRectGetHeight(self.webController.webView.frame) * 2) return;
    // fix bounce bug while pulling down over content size
    if (CGPointEqualToPoint(kEWScrollViewOffset, CGPointZero)) return;
    if (scrollView.contentOffset.y <= 0) return;
    if (scrollView.contentOffset.y >= (scrollView.contentSize.height - CGRectGetHeight(scrollView.frame))) return;
    
    // reset the frame of toolBar
    if (!kEWScrollOverLimit) {
        kEWScrollOverLimit = ABS(scrollView.contentOffset.y - kEWScrollViewOffset.y) >= 100.f;
        if (kEWScrollOverLimit) kEWScrollViewOffset = scrollView.contentOffset;
        return;
    }
    
    CGFloat diff = (scrollView.contentOffset.y - kEWScrollViewOffset.y);
    CGRect frame = self.toolBar.frame;
    frame.origin.y = MAX(self.toolBarMinY, MIN(self.toolBarMaxY, CGRectGetMinY(frame) + diff));
    self.toolBar.frame = frame;
        
    // reset the frame of webView
    CGFloat maxBottom = kEWToolBarHeight;
    if (!self.configuration.tabBarStyle.isHidden) maxBottom += CGRectGetHeight(self.webController.tabBarController.tabBar.bounds);
    UIEdgeInsets insets = self.webController.webView.scrollView.contentInset;
    insets.bottom -= diff;
    insets.bottom = MIN(MAX(insets.bottom, self.webContentInsets.bottom), maxBottom);
    self.webController.webView.scrollView.contentInset = insets;

    kEWScrollViewOffset = scrollView.contentOffset;
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    // begin dragging. stored the
    if (!self.webController.canGoBack && !self.webController.canGoForward) return;
    if (scrollView.contentSize.height < CGRectGetHeight(self.webController.webView.frame) * 2) return;
    kEWScrollOverLimit = NO;
    kEWScrollViewOffset = scrollView.contentOffset;
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    // begin dragging. stored the
    if (!self.webController.canGoBack && !self.webController.canGoForward) return;
    if (scrollView.contentSize.height < CGRectGetHeight(self.webController.webView.frame) * 2) return;
    // maybe the scroll is bounceing
    if (targetContentOffset->y >= (scrollView.contentSize.height - scrollView.frame.size.height) && scrollView.contentOffset.y >= targetContentOffset->y) return;
    if (targetContentOffset->y <= 0) return;

    CGFloat diff = (scrollView.contentOffset.y - kEWScrollViewOffset.y);
    CGRect frame = self.toolBar.frame;
    frame.origin.y = MAX(self.toolBarMinY, MIN(self.toolBarMaxY, CGRectGetMinY(frame) + diff));
    // here we just need to calculate it, then we will using animation to change it
    BOOL isVisible = frame.origin.y < self.toolBarMaxY && ((int)scrollView.contentOffset.y) >= ((int)targetContentOffset->y);
    [self updateToolBarVisible:isVisible animated:YES];
    kEWScrollViewOffset = CGPointZero;
    kEWScrollOverLimit = NO;
}

#pragma mark - Setter

- (void)setWebController:(HBWebController *)webController {
    NSAssert(webController != nil && [webController isKindOfClass:[HBWebController class]], @"Should set correct webController");
    _webController = webController;
}

#pragma mark - Getter

- (HBInterceptorPriority)priority { return HBInterceptorPriorityNormal; }
- (HBWebConfiguration *)configuration { return self.webController.configuration; }

- (UIEdgeInsets)webContentInsets { return self.webController.webContentInsets; }

- (BOOL)shouldToolBarVisible {
    if (!self.hasLoadedURL) return NO;
    if (self.webController.canGoBack || self.webController.canGoForward) return YES;
    if (![self.webController.webView.URL isEqual:self.webController.startURL]) return YES;
    if (self.webController.webView.scrollView.contentSize.height <= CGRectGetHeight(self.webController.webView.frame) * 2)
        return YES;
    return NO;
}

- (CGFloat)toolBarHeight {
    CGFloat height = CGRectGetHeight(self.toolBar.frame);
    if (@available(iOS 11.0, *)) height += ((self.configuration.tabBarStyle.isHidden || self.configuration.hidesBottomBarWhenPushed) ? self.webController.view.safeAreaInsets.bottom : CGFLOAT_MIN);
    return height;
}

- (CGFloat)toolBarMinY { return self.toolBarMaxY - kEWToolBarHeight - self.webController.webView.safeArea.bottom; }

- (CGFloat)toolBarMaxY {
    CGFloat y = CGRectGetHeight(self.webController.view.frame);
    if (self.configuration.hidesBottomBarWhenPushed) return y;
    if (self.configuration.tabBarStyle.isTranslucent) y -= CGRectGetHeight(self.webController.tabBarController.tabBar.frame);
    return y;
}

- (BOOL)canGoBack {
    if (!self.hasLoadedURL) return NO;
    return [self.webController canGoBack];
}

- (BOOL)canGoForward {
    if (!self.hasLoadedURL) return NO;
    return [self.webController canGoForward];
}

@end
