//
//  HBWebController+Debug.m
//  HybridWeb
//
//  Created by XMFraker on 2020/5/25.
//

#import "HBWebController+Debug.h"

@implementation HBWebController (Debug)

+ (void)startDebugOf:(__kindof UIViewController *)parent {
    [self startDebugOf:parent userInfo:nil];
}

+ (void)startDebugOf:(__kindof UIViewController *)parent userInfo:(nullable NSDictionary *)userInfo {
    
    NSBundle *klassBundle = [NSBundle bundleForClass:self];
    NSURL *fileURL = [klassBundle URLForResource:@"WebDebug.bundle/demo" withExtension:@"html"];
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
