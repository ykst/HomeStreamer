//
//  ConnectionState.h
//  ReverseStreamer
//
//  Created by Yukishita Yohsuke on 2014/06/08.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SWSServerState.h"
#import "SWSControlMessage.h"
#import "SWSPerformanceStatistics.h"

@class SWSConnectionHandler;
@class SWSWebsocket;

@protocol SWSConnectionStateDelegate <NSObject>

@required
- (void)connectionOnAuthorized;
- (void)connectionOnFinished;

@end

@interface SWSConnectionState : NSObject<SWSOnReadControlMessageDelegate, SWSServerToConnectionDelegate>

+ (instancetype)createWithSocket:(SWSWebsocket *)socket;

@property (nonatomic, readonly) SWSPerformanceStatistics *performance_statistics;
@property (nonatomic, weak, readwrite) SWSConnectionHandler *handler;
@property (nonatomic, readonly) NSString *host_str;

- (void)readIt:(SWSMessage *)message;
- (void)parseAndReadIt:(NSData *)data;
- (void)sendIt:(SWSMessage *)message;
- (void)sendMultiPart:(SWSMessage *)message withPayload:(NSData *)payload;
@end
