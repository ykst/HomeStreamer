//
//  MainWebsocket.m
//  ReverseStreamer
//
//  Created by Yukishita Yohsuke on 2014/06/08.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import <pthread.h>
#import "SWSConnectionState.h"
#import "SWSConnectionHandler.h"
#import "SWSAbstractFactory.h"
#import "SWSWebsocket.h"

@interface SWSWebsocket() {
    SWSConnectionState *_connection_state;
    SWSConnectionHandler *_connection_handler;
    pthread_mutex_t _lock;
    BOOL _lock_init;
}

@end

@implementation SWSWebsocket

- (void)didOpen
{
    DBG("open");

    [super didOpen];

    if (!_lock_init) { // we don't believe didOpen is called only once
        pthread_mutex_init(&_lock, NULL);
        _lock_init = YES;
    }

    _connection_state = [SWSConnectionState createWithSocket:self];
    _connection_handler = [SWSAbstractFactory sharedFactory].generateConnectionHandler(_connection_state);
}

- (void)didReceiveMessage:(NSString *)msg
{
    WARN(@"unexpected text message: '%@'", msg);
}

- (void)didReceiveData:(NSData *)data
{
    [_connection_state parseAndReadIt:data];
}

- (void)_close
{
    pthread_mutex_lock(&_lock);

    if (_connection_state != nil) {
        [_connection_state detachDelegateFromServerState];

        _connection_state = nil;
        _connection_handler = nil;
    }

    pthread_mutex_unlock(&_lock);

    [super didClose];
}

- (void)didClose
{
    DBG("close");

    [self _close];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)error
{
    if (error != nil) {
        ERROR(@"Socket Error: %@", error.description);
    }

    [self didClose];
}

- (void)takeMessage:(SWSMessage *)message;
{
    [_connection_state readIt:message];
}

- (NSString *)hostName
{
    return NSPRINTF(@"%@:%d", asyncSocket.connectedHost, asyncSocket.connectedPort);
}

#pragma mark -
#pragma mark ConnectionStateMachineActionDelegate

- (void)sendData:(NSData *)data
{
    pthread_mutex_lock(&_lock);

    if (_connection_state != nil) {
        [super sendBuffer:data];
    }

    pthread_mutex_unlock(&_lock);
}

- (void)sendBigOne:(NSData *)header withPayload:(NSData *)payload
{
    pthread_mutex_lock(&_lock);

    if (_connection_state != nil) {
        [super sendBigBuffer:header withPayload:payload];
    }

    pthread_mutex_unlock(&_lock);
}

- (void)disconnectNow
{
    DBG("disconnection requested");
    [_connection_handler teardown];
    [self _close];
}

- (void)dealloc
{
    pthread_mutex_destroy(&_lock);
}

@end
