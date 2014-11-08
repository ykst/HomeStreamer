//
//  ServerState.h
//  ReverseStreamer
//
//  Created by Yukishita Yohsuke on 2014/06/08.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SWSServerSettingMaster.h"

@class SWSConnectionHandler;


@protocol SWSServerToConnectionDelegate <NSObject>

@required
@property (nonatomic, readwrite, weak) SWSConnectionHandler *handler;

@required
// NOTE: Since connections' delegates are retained by NSMutableSet, clients must remove themselves explicitly using this.
- (void)detachDelegateFromServerState;
- (void)doPeriodicTask; // for periodic connection check
- (void)die;

@end


@interface SWSServerState : NSObject

@property (nonatomic, readwrite) uint16_t server_port;
@property (atomic, readonly) SWSServerSetting *current_setting;

+ (instancetype)sharedMachine;

#pragma mark -
#pragma mark Connections

- (NSUInteger)numConnections;

- (void)attachConnectionDelegate:(id<SWSServerToConnectionDelegate>)delegate;
- (void)detachChildDelegate:(id<SWSServerToConnectionDelegate>)delegate;
- (void)iterateHandlers:(void (^)(SWSConnectionHandler *))block;
- (BOOL)authorizePassword:(NSString *)password_digest withSeed:(NSString *)seed;
- (void)disconnectAll;
#pragma mark -
#pragma mark Setting Change
- (void)changePassword:(NSString *)plain_text;

#pragma mark -
#pragma mark Start/Stop
- (void)periodicTask;

@end
