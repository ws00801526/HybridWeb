//
//  HBViewController.m
//  HybridWeb
//
//  Created by ws00801526 on 05/14/2020.
//  Copyright (c) 2020 ws00801526. All rights reserved.
//

#import "HBViewController.h"
#import "HBJSBridgeHandler_Custom.h"
#import <objc/runtime.h>
#import <HybridWeb/HybridWeb.h>

typedef NS_ENUM(NSUInteger, HBTableViewCellMode) {
    HBTableViewCellModeUnknown,
    HBTableViewCellModeSwitch = 100,
    HBTableViewCellModeTextField,
    HBTableViewCellModeColor,
    HBTableViewCellModePicker
};

@interface UIControl (Associate)
@property (nonatomic, strong) NSIndexPath *indexPath;
@end

@implementation UIControl (Associate)

- (void)setIndexPath:(NSIndexPath *)indexPath {
    objc_setAssociatedObject(self, @selector(indexPath), indexPath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSIndexPath *)indexPath { return objc_getAssociatedObject(self, _cmd); }

@end


@implementation HBNavigationController

//- (UIStatusBarStyle)preferredStatusBarStyle { return self.visibleViewController.preferredStatusBarStyle; }

- (UIViewController *)childViewControllerForStatusBarHidden { return self.visibleViewController; }
- (UIViewController *)childViewControllerForStatusBarStyle { return self.visibleViewController; }
@end

@implementation HBTabBarController

- (UIViewController *)childViewControllerForStatusBarHidden { return self.selectedViewController; }
- (UIViewController *)childViewControllerForStatusBarStyle {  return self.selectedViewController; }
//- (UIStatusBarStyle)preferredStatusBarStyle { return self.selectedViewController.preferredStatusBarStyle; }

@end

@interface HBViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, copy) NSMutableArray<NSMutableArray<NSDictionary *> *> *options;
@property (nonatomic, copy) NSArray<NSString *> *urls;


@property (nonatomic, assign) BOOL needLight;
@end

@implementation HBViewController

- (void)viewDidLoad {
    [super viewDidLoad];
        
    [HBJSBridge registerGlobalHandler:[HBJSBridgeHandler_Custom class]];
    
    self.navigationController.navigationBar.barTintColor = [UIColor redColor];
    self.tableView.tableFooterView = [UIView new];
    UIBarButtonItem *pushItem = [[UIBarButtonItem alloc] initWithTitle:@"Push" style:UIBarButtonItemStylePlain target:self action:@selector(handlePushWeb:)];
    self.navigationItem.rightBarButtonItem = pushItem;
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    
}

- (BOOL)prefersStatusBarHidden { return NO; }
- (UIUserInterfaceStyle)overrideUserInterfaceStyle { return UIUserInterfaceStyleLight; }
- (UIStatusBarStyle)preferredStatusBarStyle { return self.needLight ? UIStatusBarStyleLightContent : UIStatusBarStyleDefault; }
- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation { return UIStatusBarAnimationFade; }

#pragma mark - Events

- (IBAction)handlePushWeb:(id)sender {

    int index = arc4random() % self.urls.count;
    NSURL *URL = [NSURL URLWithString:self.urls[index]];
    if ([URL.absoluteString isEqualToString:@"app://debug/"]) {
        [HBWebController startDebugOf:self];
    } else {
        HBWebConfiguration *config = [[HBWebConfiguration alloc] init];
        for (NSArray<NSDictionary *> *options in self.options) {
            for (NSDictionary *option in options) {
                NSString *key = [option objectForKey:@"key"];
                id value = [option objectForKey:@"value"];
                if (key.length <= 0 || value == nil) continue;
                SEL setter = NSSelectorFromString(key);
                if ([config respondsToSelector:setter]) [config setValue:value forKeyPath:key];
                else [config setValue:value forKeyPath:key];
            }
        }

        HBWebController *controller = [[HBWebController alloc] initWithURL:URL configuration:config];
        [self.navigationController pushViewController:controller animated:YES];
    }
}

- (void)handleSwitchValueChanged:(UISwitch *)sender {
    
    self.needLight = !self.needLight;
    [UIView animateWithDuration:0.25 animations:^{ [self setNeedsStatusBarAppearanceUpdate]; }];
    [self replaceValue:@(sender.isOn) at:sender.indexPath];
}

- (void)replaceValue:(id)value at:(NSIndexPath *)indexPath {
    
    if (value == nil) return;
    if (indexPath == nil) return;
    if (self.options.count <= indexPath.section) return;
    
    NSMutableDictionary *info = [[[self.options objectAtIndex:indexPath.section] objectAtIndex:indexPath.row] mutableCopy];
    NSString *key = [info objectForKey:@"key"];
    if ([key isEqualToString:@"hideNavBar"]) [self.navigationController setNavigationBarHidden:[value boolValue] animated:YES];
    if ([key isEqualToString:@"hideTabBar"]) [self.tabBarController.tabBar setHidden:[value boolValue]];
    [info setValue:value forKey:@"value"];
    [[self.options objectAtIndex:indexPath.section] replaceObjectAtIndex:indexPath.row withObject:[info copy]];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *newValue = [textField.text stringByReplacingCharactersInRange:range withString:string];
    [self replaceValue:newValue at:textField.indexPath];
    return YES;
}

#pragma mark - UITableViewDelegate & UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.options.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self.options objectAtIndex:section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *info = [[self.options objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    HBTableViewCellMode mode = (HBTableViewCellMode)[[info objectForKey:@"mode"] integerValue];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[NSString stringWithFormat:@"%d", (int)mode]];
    cell.textLabel.text = [info objectForKey:@"title"];
    switch (mode) {
        case HBTableViewCellModeSwitch:
            [(UISwitch *)[cell viewWithTag:mode] setIndexPath:indexPath];
            [(UISwitch *)[cell viewWithTag:mode] setOn:[[info objectForKey:@"value"] boolValue]];
            [(UISwitch *)[cell viewWithTag:mode] removeTarget:self action:@selector(handleSwitchValueChanged:) forControlEvents:UIControlEventValueChanged];
            [(UISwitch *)[cell viewWithTag:mode] addTarget:self action:@selector(handleSwitchValueChanged:) forControlEvents:UIControlEventValueChanged];
            break;
        case HBTableViewCellModeTextField:
            [(UITextField *)[cell viewWithTag:mode] setIndexPath:indexPath];
            [(UITextField *)[cell viewWithTag:mode] setDelegate:(id<UITextFieldDelegate>)self];
            [(UITextField *)[cell viewWithTag:mode] setText:[info objectForKey:@"value"]];
            break;
        default:
            break;
    }
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 28.f;
}

#pragma mark - Getter

- (NSArray<NSString *> *)urls {
    
    return @[
//        @"https://m.baidu.com",
//        @"https://m.youku.com",
//        @"https://xw.qq.com/?f=c_news",
//        @"https://guides.cocoapods.org",
//        @"https://github.com/",
        @"app://debug/"
    ];
}

- (NSMutableArray<NSMutableArray<NSDictionary *> *> *)options {
    
    if (_options == nil) {
        _options = [@[
            [@[
                @{ @"key" : @"navBarStyle.hidden", @"title" : @"隐藏navBar", @"value" : @NO, @"mode" : @(HBTableViewCellModeSwitch) },
                @{ @"key" : @"hidesBottomBarWhenPushed", @"title" : @"隐藏tabBar", @"value" : @YES, @"mode" : @(HBTableViewCellModeSwitch) },
                @{ @"key" : @"showProgress", @"title" : @"显示进度条", @"value" : @YES, @"mode" : @(HBTableViewCellModeSwitch) },
                @{ @"key" : @"autoReadTitle", @"title" : @"自动读取标题", @"value" : @YES, @"mode" : @(HBTableViewCellModeSwitch) },
                @{ @"key" : @"showMenu", @"title" : @"显示右侧菜单", @"value" : @YES, @"mode" : @(HBTableViewCellModeSwitch) }
            ] mutableCopy],
            [@[
                @{ @"key" : @"defaultTitle", @"title" : @"默认标题", @"value" : @"默认标题", @"mode" : @(HBTableViewCellModeTextField) }
            ] mutableCopy]
        ] mutableCopy];
    }
    return _options;
}

@end

