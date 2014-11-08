//
//  MainHTTPConnection.m
//  ReverseStreamer
//
//  Created by Yukishita Yohsuke on 2014/06/08.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "SWSHTTPConnection.h"

#import <CocoaHTTPServer/HTTPServer.h>
#import <CocoaHTTPServer/HTTPMessage.h>
#import <CocoaHTTPServer/HTTPResponse.h>
#import <CocoaHTTPServer/HTTPDataResponse.h>
#import <CocoaHTTPServer/HTTPDynamicFileResponse.h>
#import <CocoaHTTPServer/HTTPLogging.h>
#import <CocoaAsyncSocket/GCDAsyncSocket.h>

#import "SWSWebsocket.h"
#import "SWSHTTPConnection.h"
#import "SWSHTTPCachedFileResponse.h"

#import <MDWUtils/NSString+Randomize.h>

#import "SWSAbstractFactory.h"

// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = HTTP_LOG_LEVEL_ERROR; // | HTTP_LOG_FLAG_TRACE;

@interface SWSHTTPConnection() {
    NSString *_websocket_path;
    NSString *_healthcheck_path;
    NSDictionary *_replacement_word_dict;
    NSSet *_replacement_file_set;
}
@end

#define MAX_SOCKET_CONNECTIONS (16)

@implementation SWSHTTPConnection

- (NSString *)_getWebsocketPath
{
    static NSString *__path;
    static dispatch_once_t __once_token;

    dispatch_once(&__once_token, ^{
#ifdef DEBUG
        __path = @"ws";
#else
        __path = [NSString stringWithRandomAlphanum:64];
#endif
    });

    return __path;
}

- (NSString *)_getHealthcheckPath
{
    static NSString *__path;
    static dispatch_once_t __once_token;

    dispatch_once(&__once_token, ^{

#ifdef DEBUG
        __path = @"/health";
#else
        __path = NSPRINTF(@"/health_%@",[NSString stringWithRandomAlphanum:32]);
#endif
    });

    return __path;
}


- (BOOL)_checkMaxConnectionReached
{
    BOOL result = [config.server numberOfWebSocketConnections] >= MAX_SOCKET_CONNECTIONS;

    if (result) {
        DBG("Max connection reached!");
    }

    return result;
}

- (void)startConnection
{
    if ([self _checkMaxConnectionReached]) {
        return;
    }

    _websocket_path = [self _getWebsocketPath];
    _healthcheck_path = [self _getHealthcheckPath];

    [super startConnection];
}

#define SEPARATOR @"$_$"

- (NSDictionary *)setupReplacementWordDictioary
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    [dict addEntriesFromDictionary:[SWSControlMessage specification_dic]];
    [dict addEntriesFromDictionary:[SWSMessage specification_dic]];

    NSString *wsLocation;
    NSString *scheme = [asyncSocket isSecure] ? @"wss" : @"ws";
    NSString *wsHost = [request headerField:@"Host"];

    if (wsHost == nil) {
        NSString *port = [NSString stringWithFormat:@"%hu", [asyncSocket localPort]];
        wsLocation = [NSString stringWithFormat:@"%@://localhost:%@/%@", scheme, port, _websocket_path];
    } else {
        wsLocation = [NSString stringWithFormat:@"%@://%@/%@", scheme, wsHost, _websocket_path];
    }

    [dict addEntriesFromDictionary:@{@"HEALTHCHECK_URL":_healthcheck_path,
                                     @"WEBSOCKET_URL":wsLocation/*,
                                     @"APP_VERSION":[[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"],
                                     @"LOCALIZED_APP_NAME":@"Reverse Streamer",
                                     @"LOCALIZED_TITLE":NSLocalizedString(@"Reverse Streamer", nil) */}];

    return dict;
}

- (NSSet *)setupReplacementFileSet
{
    return [NSSet setWithObjects:
            @"/all.js",
            @"/",
            @"/index.html", nil];
}

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    if ([self _checkMaxConnectionReached]) {
        return nil;
    }

	HTTPLogTrace();

    if (_replacement_file_set == nil) {
        @synchronized(self) {
            if (_replacement_file_set == nil) {
                _replacement_file_set = [self setupReplacementFileSet];
            }
        }
    }
    if ([_replacement_file_set containsObject:path]) {

        if (_replacement_word_dict == nil) {
            @synchronized(self) {
                if (_replacement_word_dict == nil) {
                    _replacement_word_dict = [self setupReplacementWordDictioary];
                }
            }
        }

        return [[HTTPDynamicFileResponse alloc] initWithFilePath:[self filePathForURI:path]
                                                   forConnection:self
                                                       separator:SEPARATOR
                                           replacementDictionary:_replacement_word_dict];
    } else if ([[path substringFromIndex:path.length - 4] isEqualToString:@".png"]) {
        return [[SWSHTTPCachedFileResponse alloc] initWithFilePath:[self filePathForURI:path] forConnection:self];
    } else if ([path isEqualToString:_healthcheck_path]) {
        return [[HTTPDataResponse alloc] initWithData:nil];
    }

	return [super httpResponseForMethod:method URI:path];
}

- (WebSocket *)webSocketForURI:(NSString *)path
{
    if ([self _checkMaxConnectionReached]) {
        return nil;
    }

	if([path isEqualToString:NSPRINTF(@"/%@", _websocket_path])) {
        return [[SWSWebsocket alloc] initWithRequest:request socket:asyncSocket];
    }
        
    return [super webSocketForURI:path];
}
        
@end
