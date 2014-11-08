//
//  ConnectionStateMachine.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/05.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SimpleWebsocketServer/SWSConnectionHandler.h>
#import "ControlMessage.h"
#import "MediaStreamMessage.h"
#import "GlobalEvent.h"

@interface ConnectionHandler : SWSConnectionHandler<ConnectionEventDelegate>

+ (instancetype)createWithConnection:(SWSConnectionState *)connection;

@end
