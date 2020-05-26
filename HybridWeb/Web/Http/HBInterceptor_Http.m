//
//  HBInterceptor_Domain.m
//  HybridWeb
//
//  Created by XMFraker on 2020/4/14.
//

#import "HBInterceptor_Http.h"
#import "UIKit+Extension.h"
#import "WKWebView+HBExtension.h"
#import "HBURLRequestSerialization.h"

static Class kHTTPClass;
static HBHTTPRequestSerializer *kSerializer;

NSURLRequest *__nullable HBURLRequest(NSDictionary *userInfo, NSURL * __nullable relativeURL) {
    NSString *url = [userInfo objectForKey:@"url"];
    if (url.length <= 0) return nil;
    NSURL *URL = [NSURL URLWithString:url relativeToURL:relativeURL];
    
    NSString *HTTPMethod = [userInfo objectForKey:@"method"];
    if (HTTPMethod.length <= 0) HTTPMethod = @"GET";
    
    id paramters = [userInfo objectForKey:@"paramters"];
    
    NSTimeInterval timeoutInterval = 50.f;
    NSString *timeout = [userInfo objectForKey:@"timeout"];
    if (timeout.length > 0 && [timeout respondsToSelector:@selector(doubleValue)]) timeoutInterval = [timeout doubleValue];
    
    NSURLRequestCachePolicy cachePolicy = NSURLRequestUseProtocolCachePolicy;
    NSString *policy = [userInfo objectForKey:@"cachePolicy"];
    if (policy.length > 0 && [policy respondsToSelector:@selector(intValue)] && [@[@0, @1, @2, @3, @4, @5] containsObject:@([policy intValue])])
        cachePolicy = (NSURLRequestCachePolicy)[policy intValue];
    
    NSDictionary<NSString *, id> *headers = [userInfo objectForKey:@"headers"];
    
    NSArray<NSDictionary *> *forms = [userInfo objectForKey:@"forms"];
    NSMutableURLRequest *request = nil;
    NSError *error = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ kSerializer = [HBHTTPRequestSerializer serializer]; });
    if (forms.count) {
        request = [kSerializer multipartFormRequestWithMethod:[HTTPMethod uppercaseString] URLString:URL.absoluteString parameters:paramters constructingBodyWithBlock:^(id<HBMultipartFormData>  _Nonnull formData) {
            for (NSDictionary *form in forms) {
                NSString *theValue = [form objectForKey:@"value"];
                if (theValue.length <= 0) continue;
                NSString *theFieldName = [form objectForKey:@"field"];
                if (theFieldName.length <= 0) continue;
                NSString *mimeType = [form objectForKey:@"type"] ? : @"";
                BOOL isBase64 = [[form objectForKey:@"base64"] boolValue];
                if (isBase64) {
                    theValue = [theValue stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"data:%@;base64,", mimeType] withString:@""];
                    NSData *data = [[NSData alloc] initWithBase64EncodedString:theValue options:NSDataBase64DecodingIgnoreUnknownCharacters];
                    NSString *fileName = [form objectForKey:@"fileName"] ? : NSUUID.UUID.UUIDString;
                    [formData appendPartWithFileData:data name:theFieldName fileName:fileName mimeType:mimeType];
                } else {
                    [formData appendPartWithFormData:[theValue dataUsingEncoding:NSUTF8StringEncoding] name:theFieldName];
                }
            }
        } error:&error];
    } else {
        request = [kSerializer requestWithMethod:[HTTPMethod uppercaseString] URLString:URL.absoluteString parameters:paramters error:&error];
    }
    
    if (error) { HBLogE(@"create request error :%@", error.localizedDescription); }
    else {
        request.cachePolicy = cachePolicy;
        request.timeoutInterval = timeoutInterval;
        [headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL * _Nonnull stop) {
            NSString *field = HBPercentEscapedStringFromString([key description]);
            if (field.length > 0) [request setValue:[obj description] ? : @"" forHTTPHeaderField:field];
        }];
    }
    
    return request;
}

@interface _HBHTTPRequest : NSObject <HBHTTPRequest>
@property (nonatomic, copy) NSDictionary *userInfo;
@property (nonatomic, copy) HBJBResponseCallback handler;
@property (nonatomic, weak) NSURLSessionDataTask *task;
@end

@interface HBInterceptor_Http ()
@property (nonatomic, strong) NSHashTable *requests;
@end

@implementation HBInterceptor_Http

#pragma mark - Life

+ (void)load {
    [HBInterceptor_Http registerHTTPRequest:[_HBHTTPRequest class]];
    [HBWebController registerGlobalInterceptor:[HBInterceptor_Http class]];
}

- (instancetype)initWithWebController:(__kindof HBWebController *)webController {
    if (webController == nil) return nil;
    self = [super init];
    if (self) self.webController = webController;
    return self;
}

- (void)dealloc {
    //    for (id<HBHTTPRequest> request in self.requests) {
    //        [request cancel];
    //    }
    //    [self.requests removeAllObjects];
}

#pragma mark - HBInterceptor

- (void)webControllerViewDidLoaded:(HBWebController *)controller {
    
    NSBundle *klassBundle = [NSBundle bundleForClass:[self class]];
    NSURL *fileURL = [klassBundle URLForResource:@"WebHttp.bundle/nfetch" withExtension:@"js"];
    NSString *soure = [NSString stringWithContentsOfURL:fileURL encoding:NSUTF8StringEncoding error:nil];
    WKUserScript *script = [[WKUserScript alloc] initWithSource:soure injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:NO];
    [controller.webView.configuration.userContentController addUserScript:script];
    
    __weak typeof(self) wSelf = self;
    [controller.bridge registerHandler:@"fetch" handler:^(id  _Nonnull userInfo, HBJBResponseCallback  _Nonnull handler) {
        __strong typeof(wSelf) self = wSelf;
        if (self == nil) return ;
        id<HBHTTPRequest> request = [[kHTTPClass alloc] initWithUserInfo:userInfo handler:handler];
        if (request) [request startWithRelativeURL:self.webController.webView.backForwardList.currentItem.URL];
        else { handler(@{ @"status" : @600, @"statusText" : @"Request is unhandled" }); };
    }];
}

#pragma mark - Getter

- (HBInterceptorPriority)priority { return HBInterceptorPriorityNormal; }

#pragma mark - Class

+ (void)registerHTTPRequest:(Class<HBHTTPRequest>)klass {
    if (klass) kHTTPClass = klass;
    else kHTTPClass = [_HBHTTPRequest class];
}

@end

@implementation _HBHTTPRequest

- (instancetype)initWithUserInfo:(NSDictionary *)userInfo handler:(nonnull HBJBResponseCallback)handler {
    if (userInfo.count <= 0) return nil;
    self = [super init];
    if (self) {
        self->_handler = [handler copy];
        self->_userInfo = [userInfo copy];
    }
    return self;
}

- (void)startWithRelativeURL:(NSURL *)relativeURL {
    
    NSURLRequest *request = HBURLRequest(self.userInfo, relativeURL);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSMutableDictionary *res = [@{ @"status" : @(((NSHTTPURLResponse *)response).statusCode) } mutableCopy];
        if (((NSHTTPURLResponse *)response).allHeaderFields) [res setObject:((NSHTTPURLResponse *)response).allHeaderFields forKey:@"headers"];
        if (error) {
            [res setValue:error.localizedFailureReason ? : @"Unknown exception" forKey:@"statusText"];
        } else {
            [res setValue:[NSHTTPURLResponse localizedStringForStatusCode:((NSHTTPURLResponse *)response).statusCode] forKey:@"statusText"];
            NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (body.length) [res setObject:body forKey:@"body"];
        }
        if (self.handler) self.handler([res copy]);
    }];
    [task resume];
    self.task  = task;
}

- (void)cancel {
    if (self.task) [self.task cancel];
    if (self.handler) self.handler(@{ @"status" : @600, @"statusText" : @"Request is cancelled" });
}

@end
