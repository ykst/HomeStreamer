//
//  SWSAbstractFactory.h
//  ReverseStreamer
//
//  Created by Yukishita Yohsuke on H26/06/12.
//  Copyright (c) 平成26年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SWSHTTPConnection.h"
#import "SWSHTTPServer.h"
#import "SWSWebsocket.h"
#import "SWSServerState.h"
#import "SWSConnectionState.h"
#import "SWSMessage.h"

@class SWSPerformanceStatistics;
@class SWSConnectionHandler;

@interface SWSAbstractFactory : NSObject {
    @protected
    NSMutableArray *_message_classes;
}

+ (instancetype)sharedFactory;

@property (nonatomic, copy) SWSConnectionHandler *(^generateConnectionHandler)(SWSConnectionState *connection);

@property (nonatomic, copy) Class http_connection_class;

- (void)registerMessageClass:(Class)message_class;

- (BOOL)forwardData:(NSData *)data forDelegate:(id<SWSOnReadMessageDelegate>)delegate;
- (BOOL)forwardMessage:(SWSMessage *)message forDelegate:(id<SWSOnReadMessageDelegate>)delegate;
@end
