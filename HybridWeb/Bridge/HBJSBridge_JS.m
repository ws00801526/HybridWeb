//
//  HBJSBridge_JS.m
//  HybridWeb
//
//  Created by XMFraker on 2020/4/7.
//

#import "HBJSBridge_JS.h"

NSString *__nonnull HBJSBridge_JS(void) {
    
#define __ewjs_tostring__(x) #x
    static NSString * preprocessorJSCode = @__ewjs_tostring__((function() {
        
        if (window.HBJSBridge) return;
        
        if (!window.onerror) {
            window.onerror = function(msg, url, line) {
                console.log("HBJSBridge: ERROR:" + msg + "@" + url + ":" + line);
            }
        }
        
        window.HBJSBridge = {
        register: registerHandler,
        call: callHandler,
        _fetchQueue: _fetchQueue,
        _handleMessageFromObjC: _dispatchMessageFromObjC,
        _handleEventFromObjC: _dispatchEventFromObjC
        };
        
        var sendMessageQueue = [];
        var messageHandlers = {};
        
        var CUSTOM_PROTOCOL_SCHEME = 'https';
        var QUEUE_HAS_MESSAGE = '__ewjb_queue_message__';
        
        var responseCallbacks = {};
        var uniqueId = 1;
        var dispatchWithTimeoutSafety = true;
        
        function registerHandler(handlerName, handler) {
            messageHandlers[handlerName] = handler;
        }
        
        function callHandler(handlerName, data, responseCallback) {
            
            // methods using for ignore the data, you can just callHandler(name, callBack)
            if (arguments.length == 2 && typeof data == 'function') {
                responseCallback = data;
                data = null;
            }
            return _doSend({ handlerName: handlerName, data: data }, responseCallback);
        }
                
        function _doSend(message, responseCallback) {
            
            var callbackId = null;
            if (responseCallback) {
                // save callback in JS side, will be used while Native callback
                callbackId = 'cb_' + (uniqueId++) + '_' + new Date().getTime();
                responseCallbacks[callbackId] = responseCallback;
                message['callbackId'] = callbackId;
            }
            // using webkit.messageHandlers, some url using CSP will block the iframe.
            message && window.webkit.messageHandlers.flushQueue.postMessage([message]);
            return callbackId;
            // save message into queue, waiting for Native flush it
            // sendMessageQueue.push(message);
            // messagingFrame.src = CUSTOM_PROTOCOL_SCHEME + ':' + QUEUE_HAS_MESSAGE;
        }
        
        function _fetchQueue() {
            var messageQueue = sendMessageQueue;
            sendMessageQueue = [];
            return messageQueue;
        }
        
        // 处理从Native端传来的消息
        function _dispatchMessageFromObjC(messageJSON) {
            if (dispatchWithTimeoutSafety) {
                window.setTimeout(_doDispatchMessageFromObjC, 0);
            } else {
                _doDispatchMessageFromObjC();
            }
            
            function _doDispatchMessageFromObjC() {
                var message = JSON.parse(messageJSON);
                var messageHandler;
                var responseCallback;
                
                // 如果消息中有responseId 则认为是JS->Native->Callback 回调
                if (message.responseId) {
                    responseCallback = responseCallbacks[message.responseId];
                    if (!responseCallback) {
                        return;
                    }
                    responseCallback(message.responseData);
                    delete responseCallbacks[message.responseId];
                } else { // 否则则认为是Native主动调起JS端进行通信
                    if (message.callbackId) {
                        // 此处将responseId主动记录下来, 并生成JS端的callback方法, 给到JS调用
                        // 内部处理使用_doSend将消息发送给Native
                        var callbackResponseId = message.callbackId;
                        responseCallback = function(responseData) {
                            _doSend({
                            handlerName: message.handlerName,
                            responseId: callbackResponseId,
                            responseData: responseData
                            });
                        };
                    }
                    
                    var handler = messageHandlers[message.handlerName];
                    if (!handler) {
                        console.log("HBJSBridge: WARNING: no handler for message from ObjC:", message);
                    } else {
                        handler(message.data, responseCallback);
                    }
                }
            }
        }
        
        function _dispatchEventFromObjC(event) {
            if (dispatchWithTimeoutSafety) {
                window.setTimeout(_doDispatchEventFromObjC, 0);
            } else {
                _doDispatchEventFromObjC();
            }
            
            function _doDispatchEventFromObjC() {
                var eventName = event && event.eventName;
                if (eventName) {
                    var options = event && event.options;
                    var theEvent = new CustomEvent(eventName, { detail : options || {} });
                    window.document.dispatchEvent(theEvent);
                }
            }
        }
        
        func _disableAsync(event) {
            var enabled = event && event.options.enabled
            dispatchWithTimeoutSafety = enabled || false
        }

        registerHandler("_disableAsync", _disableAsync);
        registerHandler("_dispatchEventFromObjC", _dispatchEventFromObjC);
        
        // dispatch ready event
        window.setTimeout(_dispatchReadyEvent, 0);
        function _dispatchReadyEvent() {
            var readyEvent = document.createEvent('Events');
            readyEvent.initEvent('HBJSBridgeReady');
            window.document.dispatchEvent(readyEvent);
            // fulsh messages called before bridge ready
            window.HBJSBridge.call('HBJSBridgeReady');
        }
    })();); // END preprocessorJSCode
#undef __ewjs_tostring__
    return preprocessorJSCode;
}
