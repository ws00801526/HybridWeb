//
//  HBJSBridge.m
//  HybridWeb
//
//  Created by XMFraker on 2020/4/7.
//

#import "HBJSBridge.h"
#import "HBJSBridgeHandler.h"
#import "HBJSBridge_JS.h"
#import "WKWebView+HBExtension.h"

// !!!: the next keys should be same as HBJSBridge_JS files
NSString *const kEWJBHandlerKey  = @"handlerName";
NSString *const kEWJBCallbackKey = @"callbackId";
NSString *const kEWJBResponseKey = @"responseId";
NSString *const kEWJBDataKey     = @"data";
NSString *const kEWJBResponseDataKey = @"responseData";

static NSString *const kEWJSProtocolScheme = @"https";
static NSString *const kEWJSQueueHasMessage = @"__ewjb_queue_message__";
static NSString *const kHBJSBridgeHasLoaded = @"__bridge_loaded__";

static NSString *const kEWJSHandlerDispatchEvent = @"_dispatchEventFromObjC";
static NSString *const kEWJSHandlerDisableAsync = @"_disableAsync";



@interface HBJSBridge () <WKScriptMessageHandler>

@property (nonatomic, strong) NSMutableArray<__kindof HBJSBridgeHandler *> *actions;
@property (nonatomic, strong) NSMutableArray *startupMessageQueue;
@property (nonatomic, strong) NSMutableDictionary<NSString *, HBJBResponseCallback> *responseCallbacks;
@property (nonatomic, strong) NSMutableDictionary<NSString *, HBJBHandler> *messageHandlers;
@property (nonatomic, strong) NSMutableDictionary<NSString *, Class<HBJSBridgeHandlerProtocol>> *messageActions;

@property (nonatomic, weak)   id<WKNavigationDelegate> webViewDelegate;
@property (nonatomic, copy,   readonly) NSString *flushQueueCommand;
@property (nonatomic, copy,   readonly) NSString *checkBridgeCommand;
@property (nonatomic, strong, readonly, class) NSMutableDictionary<NSString *, Class<HBJSBridgeHandlerProtocol>> *globalActions;

@end

@implementation HBJSBridge {
    long _uniqueId;
}
#pragma mark - Life


- (instancetype)initWithWebView:(WKWebView *)webView {
    return [self initWithWebView:webView mode:HBJBInjectAutomatic];
}

- (instancetype)initWithWebView:(WKWebView *)webView mode:(HBJBInjectMode)mode {
    
    NSAssert(webView != nil, @"WebView should not be nil");
    self = [super init];
    if (self) {

        self->_webView = webView;
        self->_webView.navigationDelegate = (id<WKNavigationDelegate>)self;
        self->_uniqueId = 0;
        self->_actions = [NSMutableArray array];
        self->_startupMessageQueue = [NSMutableArray array];
        self->_messageActions    = [NSMutableDictionary dictionaryWithDictionary:[[self class] globalActions]];
        self->_messageHandlers   = [NSMutableDictionary dictionary];
        self->_responseCallbacks = [NSMutableDictionary dictionary];
        self->_actionBundles = [NSMutableArray arrayWithObject:[NSBundle mainBundle]];

        self->_mode = mode;
        if (mode == HBJBInjectAutomatic) {

            // the URL is loaded, need inject the JS using evaluate first
            if (webView.URL && !webView.isLoading && webView.backForwardList.currentItem) {
                [self _evaluateJavascript:HBJSBridge_JS() handler:^(id res, NSError * _Nullable error) {
                    if (error) HBLogW(@"Inject BridgeJS failed :%@", error);
                }];
            }

            // Should add the script into content controller, otherwise the bridge will be empty if reload webView
            WKUserScript *script = [[WKUserScript alloc] initWithSource:HBJSBridge_JS() injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
            [self.webView.configuration.userContentController addUserScript:script];
        }
        
        [self.webView.configuration.userContentController addScriptMessageHandler:self name:@"flushQueue"];
        [self.webView.configuration.userContentController addScriptMessageHandler:self name:@"injectBridge"];
    }
    return self;
}

- (void)dealloc {
    
    self.actions = nil;
    self.messageHandlers = nil;
    self.responseCallbacks = nil;
    self.startupMessageQueue = nil;
    
    // TODO: should we remove the JSBridge script
    [self->_webView.configuration.userContentController removeScriptMessageHandlerForName:@"injectBridge"];
    [self->_webView.configuration.userContentController removeScriptMessageHandlerForName:@"flushQueue"];
    [self->_webView.configuration.userContentController removeAllUserScripts];
    self->_webView.navigationDelegate = nil;
    self->_webView = nil;
}

#pragma mark - Private

- (nullable NSString *)_serializeMessage:(id)message pretty:(BOOL)pretty {
    NSJSONWritingOptions options = (NSJSONWritingOptions)(pretty ? NSJSONWritingPrettyPrinted : kNilOptions);
    NSData *data = [NSJSONSerialization dataWithJSONObject:message options:options error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (nonnull NSArray<HBJBMessage *> *)_deserializeMessageJSON:(NSString *)messageJSON {
    NSArray<HBJBMessage *> *messages = [NSJSONSerialization JSONObjectWithData:[messageJSON dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
    if (![messages isKindOfClass:[NSArray class]]) return @[];
    return messages;
}

/// stored message to queue if the Bridge has't injected, or just dispatch the message to JS side
/// @param message the message will be stored
- (void)_queueMessage:(HBJBMessage *)message {
    if (message == nil || message.count <= 0) return;
    if (self.startupMessageQueue) [self.startupMessageQueue addObject:message];
    else [self _dispatchMessage:message];
}

- (void)_dispatchMessage:(HBJBMessage *)message {
    
    NSString *messageJSON = [self _serializeMessage:message pretty:NO];
    [self _log:@"Send2JS" json:messageJSON];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\f" withString:@"\\f"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\u2028" withString:@"\\u2028"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\u2029" withString:@"\\u2029"];
    NSString *js = [NSString stringWithFormat:@"HBJSBridge._handleMessageFromObjC('%@');", messageJSON];
    [self _evaluateJavascript:js handler:NULL];
}

/// evaluate js on matin thread
/// @param js the js wiil be evaluated by delegate if exists
/// @param handler the handler will be executed after the js has evaluated
- (void)_evaluateJavascript:(NSString *)js handler:(nullable void (^)(_Nullable id, NSError * _Nullable error))handler {
    
    if (js.length <= 0 || self.webView == nil) return;
    
    if ([[NSThread currentThread] isMainThread]) {
        [self.webView evaluateJavaScript:js completionHandler:handler];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{ [self.webView evaluateJavaScript:js completionHandler:handler]; });
    }
}

- (void)_log:(NSString *)action json:(id)json {
    if (![json isKindOfClass:[NSString class]]) json = [self _serializeMessage:json pretty:YES];
    HBLog(@"%@: %@", action, json);
}

- (void)_flushMessageQueue:(NSArray<HBJBMessage *> *)messages {
    
    if (![messages isKindOfClass:[NSArray class]] || messages.count <= 0) {
        HBLogW(@"ObjC got nil while fetching messages from JS.");
        return;
    }
        
    for (HBJBMessage *message in messages) {
        if (![message isKindOfClass:[HBJBMessage class]]) {
            HBLogW(@"Invalid %@ received: %@", [message class], message);
            continue;
        }
        [self _log:@"ReceiveFromJS" json:message];
        NSString *responseID = [message objectForKey:kEWJBResponseKey];
        if (responseID.length > 0) {
            // the response ID is exists, this is a message response from JS side
            HBJBResponseCallback callback = [self.responseCallbacks objectForKey:kEWJBCallbackKey];
            callback(message[kEWJBResponseDataKey]);
            [self.responseCallbacks removeObjectForKey:kEWJBCallbackKey];
        } else {
            NSString *handlerName = [message objectForKey:kEWJBHandlerKey];
            if (handlerName.length <= 0) continue;
            
            if ([handlerName isEqualToString:@"HBJSBridgeReady"]) {
                NSArray<HBJBMessage *> *queue = [self.startupMessageQueue copy];
                self.startupMessageQueue = nil;
                for (HBJBMessage *message in queue) {
                    [self _dispatchMessage:message];
                }
                continue;
            }
                        
            HBJBHandler handler = [self.messageHandlers objectForKey:handlerName];
            HBJBResponseCallback completion = NULL;
            NSString *callbackID = [message objectForKey:kEWJBCallbackKey];
            if (callbackID.length > 0) {
                // the callback ID is exists, which means need callback to JS side
                completion = ^(id response) {
                    HBJBMessage *msg = @{ kEWJBResponseKey : callbackID, kEWJBResponseDataKey : response ? : [NSNull null] };
                    [self _dispatchMessage:msg];
                };
            } else { completion = ^(id response) { }; }

            if (handler) {
                handler([message objectForKey:kEWJBDataKey], [completion copy]);
            } else {
                Class klazz = [self _dynamicActionClass:handlerName];
                if (klazz != nil) {
                    id<HBJSBridgeHandlerProtocol> action = [[klazz alloc] initWithContext:self];
                    if (action) { [action handle:message completion:completion]; continue; }
                }
                HBLogW(@"cann't handle message receive from js: %@", message);
                completion(@{ @"message" : [NSString stringWithFormat:@"cann't handle message receive from js: %@", handlerName] });
            }
        }
    }
}

- (nullable Class)_dynamicActionClass:(NSString *)handlerName {
    Class<HBJSBridgeHandlerProtocol> klazz = [self.messageActions objectForKey:handlerName];
    if (klazz == nil) {
        // the handler didn't registered, using runtime find the correct action to handle message
        NSString *theFirstChar = [[handlerName substringToIndex:1] uppercaseString];
        NSString *theName = [handlerName stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:theFirstChar];
        NSString *className = [NSString stringWithFormat:@"HBJSBridgeHandler_%@", theName];
        klazz = NSClassFromString(className);
        if (klazz == nil) {
            for (NSBundle *bundle in self.actionBundles) {
                NSString *bundleName = [[bundle infoDictionary] objectForKey:@"CFBundleExecutable"];
                klazz = NSClassFromString([NSString stringWithFormat:@"%@.%@", bundleName, className]);
                if (klazz != nil) break;
            }
        }
    }
    return klazz;
}

- (void)_injectJavascriptFile {
    NSString *js = HBJSBridge_JS();
    __weak typeof(self) wSelf = self;
    [self _evaluateJavascript:js handler:^(id result, NSError *error) {
        __strong typeof(wSelf) self = wSelf;
        if (self == nil) return;
        if (error != nil) HBLogW(@"inject js file failed :%@", error);
        else if (self.startupMessageQueue.count > 0) {
            NSArray<HBJBMessage *> *queue = [self.startupMessageQueue copy];
            self.startupMessageQueue = nil;
            for (HBJBMessage *message in queue) {
                [self _dispatchMessage:message];
            }
        }
    }];
}

- (BOOL)_isSchemeMatch:(NSURL *)url {
    return [url.scheme.lowercaseString isEqualToString:kEWJSProtocolScheme];
}

- (BOOL)_isWebViewJavascriptBridgeURL:(NSURL *)url {
    if (![self _isSchemeMatch:url]) return NO;
    return [self _isBridgeLoadedURL:url] || [self _isQueueMessageURL:url];
}

- (BOOL)_isQueueMessageURL:(NSURL *)url {
    return [self _isSchemeMatch:url] && [url.host.lowercaseString isEqualToString:kEWJSQueueHasMessage];
}

- (BOOL)_isBridgeLoadedURL:(NSURL *)url {
    return [self _isSchemeMatch:url] && [url.host.lowercaseString isEqualToString:kHBJSBridgeHasLoaded];
}

- (void)_logUnkownMessage:(NSURL*)url {
    HBLogW(@"HBJSBridge Received unknown command %@", [url absoluteString]);
}

#pragma mark - Public

- (void)reset {
    self->_uniqueId = 0;
    [self->_actions removeAllObjects];
    [self->_startupMessageQueue removeAllObjects];
    [self->_responseCallbacks removeAllObjects];
}

- (void)flushMessageQueue {
    __weak typeof(self) wSelf = self;
    [self.webView evaluateJavaScript:self.flushQueueCommand completionHandler:^(id messageJSON, NSError * _Nullable error) {
        __strong typeof(wSelf) self = wSelf;
        if (self == nil) return;
        if (error) HBLogW(@"flush message queue error :%@", error);
        else [self _flushMessageQueue:messageJSON];
    }];
}

- (void)setWebViewDelegate:(id<WKNavigationDelegate>)delegate {
    _webViewDelegate = delegate;
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    
    if (userContentController != self.webView.configuration.userContentController) return;
    if ([@"flushQueue" isEqualToString:message.name] && message.body) [self _flushMessageQueue:(NSArray<HBJBMessage *> *)message.body];
    else if ([@"injectBridge" isEqualToString:message.name]) [self _injectJavascriptFile];
    else HBLogW(@"HBJSBridge Received unknown script message %@", message);
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    
    if (webView != _webView) return;
    NSURL *url = navigationAction.request.URL;
    if ([self _isWebViewJavascriptBridgeURL:url]) {
        if ([self _isBridgeLoadedURL:url]) [self _injectJavascriptFile];
        else if ([self _isQueueMessageURL:url]) [self flushMessageQueue];
        else [self _logUnkownMessage:url];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    __strong typeof(_webViewDelegate) strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:_cmd])
        [strongDelegate webView:webView decidePolicyForNavigationAction:navigationAction decisionHandler:decisionHandler];
    else
        decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction preferences:(WKWebpagePreferences *)preferences decisionHandler:(void (^)(WKNavigationActionPolicy, WKWebpagePreferences *))decisionHandler API_AVAILABLE(macos(10.15), ios(13.0)) {
    
    if (webView != _webView) return;
    NSURL *url = navigationAction.request.URL;

    if ([self _isWebViewJavascriptBridgeURL:url]) {
        if ([self _isBridgeLoadedURL:url]) [self _injectJavascriptFile];
        else if ([self _isQueueMessageURL:url]) [self flushMessageQueue];
        else [self _logUnkownMessage:url];
        decisionHandler(WKNavigationActionPolicyCancel, [[WKWebpagePreferences alloc] init]);
        return;
    }
    __strong typeof(_webViewDelegate) strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:_cmd])
        [strongDelegate webView:webView decidePolicyForNavigationAction:navigationAction preferences:preferences decisionHandler:decisionHandler];
    else
        decisionHandler(WKNavigationActionPolicyAllow, [[WKWebpagePreferences alloc] init]);
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    
    if (webView != _webView) return;
    __strong typeof(_webViewDelegate) strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:_cmd])
        [strongDelegate webView:webView decidePolicyForNavigationResponse:navigationResponse decisionHandler:decisionHandler];
    else
        decisionHandler(WKNavigationResponsePolicyAllow);
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
    if (webView != _webView) return;
    __strong typeof(_webViewDelegate) strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:_cmd])
        [strongDelegate webView:webView didStartProvisionalNavigation:navigation];
}

- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
    if (webView != _webView) return;
    __strong typeof(_webViewDelegate) strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:_cmd])
        [strongDelegate webView:webView didReceiveServerRedirectForProvisionalNavigation:navigation];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    if (webView != _webView) return;
    __strong typeof(_webViewDelegate) strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:_cmd])
        [strongDelegate webView:webView didFailProvisionalNavigation:navigation withError:error];
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation {
    if (webView != _webView) return;
    __strong typeof(_webViewDelegate) strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:_cmd])
        [strongDelegate webView:webView didCommitNavigation:navigation];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {

    if (webView != _webView) return;
    __strong typeof(_webViewDelegate) strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:_cmd])
        [strongDelegate webView:webView didFinishNavigation:navigation];
}

- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler {
    if (webView != _webView) return;
    __strong typeof(_webViewDelegate) strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:_cmd])
        [strongDelegate webView:webView didReceiveAuthenticationChallenge:challenge completionHandler:completionHandler];
    else
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView API_AVAILABLE(macos(10.11), ios(9.0)) {
    if (webView != _webView) return;
    __strong typeof(_webViewDelegate) strongDelegate = _webViewDelegate;
    if (strongDelegate && [strongDelegate respondsToSelector:_cmd])
        [strongDelegate webViewWebContentProcessDidTerminate:webView];
    else
        [webView reloadFromOrigin];
}

#pragma mark - Getter

- (NSString *)flushQueueCommand { return @"HBJSBridge._fetchQueue();"; }
- (NSString *)checkBridgeCommand { return @"typeof HBJSBridge == \'object\';"; }

+ (NSMutableDictionary<NSString *, Class<HBJSBridgeHandlerProtocol>> *)globalActions {
    static dispatch_once_t onceToken;
    static NSMutableDictionary<NSString *, Class<HBJSBridgeHandlerProtocol>> *kEWJSDynamicClasses;
    dispatch_once(&onceToken, ^{ kEWJSDynamicClasses = [NSMutableDictionary dictionary]; });
    return kEWJSDynamicClasses;
}

@end


@implementation HBJSBridge (JS2N)

- (void)registerHandler:(NSString *)handlerName handler:(HBJBHandler)handler {
    if (handlerName.length <= 0 || handler == NULL) return;
    @synchronized (self) {
        [self.messageHandlers setObject:[handler copy] forKey:handlerName];
    }
}

- (void)removeHandler:(NSString *)handlerName {
    if (handlerName.length <= 0) return;
    @synchronized (self) {
        [self.messageActions removeObjectForKey:handlerName];
        [self.messageHandlers removeObjectForKey:handlerName];
    }
}

- (void)registerHandler:(NSString *)handlerName clazz:(Class)clazz {
    if (handlerName.length <= 0 || clazz == nil) return;
    @synchronized (self) { [self.messageActions setObject:clazz forKey:handlerName]; }
}

- (void)registerActionsPlistPath:(NSString *)plistPath {
    NSArray<NSDictionary *> *actions = [NSArray arrayWithContentsOfFile:plistPath];
    if (![actions isKindOfClass:[NSArray class]] || actions.count <= 0) return;
    
    @synchronized (self) {
        for (NSDictionary *action in actions) {
            if (![action isKindOfClass:[NSDictionary class]]) continue;
            NSString *handlerName = [action objectForKey:kEWJBHandlerKey];
            NSString *className = [action objectForKey:@"class"];
            Class clazz = NSClassFromString(className);
            [self.messageActions setObject:clazz forKey:handlerName];
        }
    }
}

+ (void)registerGlobalHandler:(Class)clazz {
    NSString *name = NSStringFromClass(clazz);
    if ([name containsString:@"_"]) name = [[name componentsSeparatedByString:@"_"] lastObject];
    if (name.length <= 0) return;
    NSString *firstCharacter = [name substringToIndex:1];
    name = [name stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[firstCharacter lowercaseString]];
    [self registerGlobalHandler:name clazz:clazz];
}

+ (void)registerGlobalHandler:(NSString *)handlerName clazz:(Class)clazz {
    if (handlerName.length <= 0) return;
    if (![clazz conformsToProtocol:@protocol(HBJSBridgeHandlerProtocol)]) return;
    [HBJSBridge.globalActions setObject:clazz forKey:handlerName];
}

@end

@implementation HBJSBridge (N2JS)

- (void)disableAsync {
    [self _send:nil callBack:NULL handlerName:kEWJSHandlerDisableAsync];
}

- (void)dispatchEvent:(NSString *)eventName options:(nullable NSDictionary *)options {
    
    if (eventName.length <= 0) return;
    HBJBMessage *message = @{ @"eventName" : eventName, @"options" : options ? : @{} };
    [self _send:message callBack:NULL handlerName:kEWJSHandlerDispatchEvent];
}

- (void)callHandler:(NSString *)handlerName {
    [self callHandler:handlerName data:nil responseCallback:NULL];
}

- (void)callHandler:(NSString *)handlerName data:(nullable id)data {
    [self callHandler:handlerName data:data responseCallback:NULL];
}

- (void)callHandler:(NSString *)handlerName data:(nullable id)data responseCallback:(HBJBResponseCallback)callback {
    [self _send:data callBack:callback handlerName:handlerName];
}

/// Send data to JS
/// @param data the data will send to JS
/// @param callback the callback block after
/// @param handlerName the handler name is registered in JS
- (void)_send:(id)data callBack:(HBJBResponseCallback)callback handlerName:(NSString *)handlerName {
    if (handlerName.length <= 0) {
        [self _log:@"Send2JS failed because the handler is empty" json:@{}];
        return;
    }
    NSMutableDictionary *message = [@{ kEWJBHandlerKey : handlerName } mutableCopy];
    if (data) [message setObject:data forKey:kEWJBDataKey];
    if (callback) {
        NSString *callbackID = [NSString stringWithFormat:@"objc_cb_%ld", ++_uniqueId];
        [self.responseCallbacks setObject:[callback copy] forKey:callbackID];
        [message setObject:callbackID forKey:kEWJBCallbackKey];
    }
    [self _log:@"Send2JS" json:message];
    [self _queueMessage:[message copy]];
}

@end
