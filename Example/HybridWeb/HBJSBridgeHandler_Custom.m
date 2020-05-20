//
//  HBJSBridgeHandler_Custom.m
//  HybridWeb_Example
//
//  Created by XMFraker on 2020/5/14.
//  Copyright © 2020 ws00801526. All rights reserved.
//

#import "HBJSBridgeHandler_Custom.h"

@implementation HBJSBridgeHandler_Custom

- (void)handle:(HBJBMessage *)message completion:(HBJBResponseCallback)completion {
    [super handle:message completion:completion];

    NSLog(@"i am custom handle");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self finishWithResponse:@{ @"message" : @"completed" }];
    });
}

@end
