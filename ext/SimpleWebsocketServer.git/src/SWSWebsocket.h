//
//  MainWebsocket.h
//  ReverseStreamer
//
//  Created by Yukishita Yohsuke on 2014/06/08.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CocoaHTTPServer/WebSocket.h>

#import "SWSConnectionState.h"

@interface SWSWebsocket : WebSocket

- (void)takeMessage:(SWSMessage *)message;
- (NSString *)hostName;
// prohibit raw network operation
- (void) __unavailable sendBuffer:(NSData *)msg;
- (void) __unavailable sendMessage:(NSData *)msg;
- (void) __unavailable start;
- (void) __unavailable stop;
- (void)sendData:(NSData *)msg;
- (void)sendBigOne:(NSData *)header withPayload:(NSData *)payload;
- (void)disconnectNow;
@end
