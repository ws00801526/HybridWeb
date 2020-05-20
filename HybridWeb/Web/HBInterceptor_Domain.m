//
//  HBInterceptor_Domain.m
//  HybridWeb
//
//  Created by XMFraker on 2020/4/14.
//

#import "HBInterceptor_Domain.h"
#import "UIKit+Extension.h"

@interface HBInterceptor_Domain ()
@property (nonatomic, strong) UILabel *domainLabel;
@end

@implementation HBInterceptor_Domain

#pragma mark - Life

- (instancetype)initWithWebController:(__kindof HBWebController *)webController {
    if (webController == nil) return nil;
    self = [super init];
    if (self) self.webController = webController;
    return self;
}

- (void)dealloc {
    if (self.domainLabel.superview) [self.domainLabel removeFromSuperview];
}

#pragma mark - Private

- (void)updateDomainURL:(NSURL *)URL {
    if (URL == nil) self.domainLabel.text = @"";
#if DEBUG
    else if (URL.isFileURL) self.domainLabel.text = @"此网页为本地URL";
#endif
    else if (URL.host.length > 0) self.domainLabel.text = [NSString stringWithFormat:@"此网页由 %@ 提供", URL.host];
    else self.domainLabel.text = @"";
}

#pragma mark - HBInterceptor

- (void)webController:(HBWebController *)controller observerValueDidChangedForKeyPath:(NSString *)keyPath {
    if ([@"url" isEqualToString:[keyPath lowercaseString]]) [self updateDomainURL:controller.webView.URL];
}

- (void)webControllerViewDidLoaded:(HBWebController *)controller {
    if (!self.webController.configuration.showDomain) return;
    [self updateDomainURL:self.webController.startURL];
    if (self.domainLabel.superview) [self.domainLabel removeFromSuperview];
    [self.webController.webView.scrollView insertSubview:self.domainLabel atIndex:0];
}

- (void)webController:(HBWebController *)controller didLoadURL:(NSURL *)URL error:(NSError *)error {
    if (!self.webController.configuration.showDomain) return;
    [self updateDomainURL:URL];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView.contentOffset.y > 0) return;
    if (!self.webController.configuration.showDomain) return;
    self.domainLabel.alpha = (ABS(scrollView.contentOffset.y) - self.webController.webView.safeArea.top) / (self.domainLabel.height * 2.5f);
    self.domainLabel.frame = (CGRect) { CGPointMake(15.f, scrollView.contentOffset.y + self.webController.webView.safeArea.top), self.domainLabel.frame.size };
}

#pragma mark - Getter

- (HBInterceptorPriority)priority { return HBInterceptorPriorityNormal; }

- (UILabel *)domainLabel {
    if (!_domainLabel) {
        _domainLabel = [[UILabel alloc] initWithFrame:CGRectMake(15.f, self.webController.webView.safeArea.top, self.webController.webView.width - 30.f, 50.f)];
        _domainLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _domainLabel.textColor = [UIColor hb_colorWithHex:0x999999];
        _domainLabel.textAlignment = NSTextAlignmentCenter;
        _domainLabel.font = [UIFont systemFontOfSize:15.f];
    }
    return _domainLabel;
}

@end
