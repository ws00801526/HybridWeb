//
//  HBProgressView.m
//  HybridWeb
//
//  Created by XMFraker on 2020/4/13.
//

#import "HBProgressView.h"

@implementation HBProgressView

- (void)setProgress:(float)progress animated:(BOOL)animated {
    
    [super setProgress:progress animated:animated];
    if (progress < 1.f) {
        self.hidden = NO;
    } else {
        if (!self.autoHide) return;
        [UIView animateWithDuration:0.35 delay:0.15 options:UIViewAnimationOptionAllowAnimatedContent animations:^{
            self.alpha = 0.f;
        } completion:^(BOOL finished) {
            if (!finished) return;
            self.alpha = 1.f;
            self.hidden = YES;
            self.progress = 0.f;
        }];
    }
}

@end
