//
//  UPnPService.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/05/30.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <MiniUPnPc-iOS/MiniUPnPc_iOS.h>
#import "UPnPService.h"
#import "Domain/GlobalEvent.h"

#define MIN_WAN_PORT (49152)
#define MAX_WAN_PORT (65535)
#define UPNP_MAX_RETRY_COUNT (3)

@interface UPnPService() {
    dispatch_queue_t _queue;
    MiniUPnPc *_upnp;
    NSString *_external_ip;
    int _upnp_retry_count;
}
@end

@implementation UPnPService

+ (instancetype)create
{
    UPnPService *obj = [[[self class] alloc] init];

    ASSERT([obj _setup], return nil);

    return obj;
}

+ (instancetype)sharedService
{
    static UPnPService * __instance;
    static dispatch_once_t __once_token;
    dispatch_once(&__once_token, ^{
        __instance = [[self class] create];
    });
    return __instance;
}

- (BOOL)_setup
{
    _queue = dispatch_queue_create("com.monadworks.home-streamer.upnp-service", 0);
    _upnp = [MiniUPnPc create];

    return YES;
}

- (void)_upnpHandlePortForwardingResult:(uint16_t)port withBlock:(void (^)(NSString *, UPnPServiceErrorCode, int))block doRetry:(BOOL)retry withUPnPError:(int)upnp_error_code

{
    __weak id weak_self = self;

    if (port != 0) {
        [[GlobalEvent sharedMachine] saveUpnpExternalPort:port];

        NSString *external_url = NSPRINTF(@"http://%@:%d", _external_ip, port);

        block(external_url, UPNPSERVICE_SUCCESS, upnp_error_code);
    } else {
        [[GlobalEvent sharedMachine] saveUpnpExternalPort:0];

        ++_upnp_retry_count;

        if (retry && _upnp_retry_count < UPNP_MAX_RETRY_COUNT) {
            [_upnp setPortForwarding:[GlobalEvent sharedMachine].server_port withMinWanPort:MIN_WAN_PORT withMaxWanPort:MAX_WAN_PORT withQueue:_queue withHandler:^(uint16_t port, int upnp_error_code) {
                [weak_self _upnpHandlePortForwardingResult:port withBlock:block doRetry:retry withUPnPError:upnp_error_code];
            }];
        } else {
            _upnp_retry_count = 0;

            block(nil, UPNPSERVICE_ERROR_CONFIGURE, upnp_error_code);
        }
    }
}

- (void)_upnpGetExternalAddress:(void (^)(NSString *, UPnPServiceErrorCode, int))block doRetry:(BOOL)retry
{
    uint16_t saved_port = [GlobalEvent sharedMachine].current_streaming_setting.upnp_external_port;

    uint16_t min_port = MIN_WAN_PORT;
    uint16_t max_port = MAX_WAN_PORT;

    if (saved_port != 0) {
        min_port = saved_port;
        max_port = saved_port;
    }

    __weak id weak_self = self;

    [_upnp setPortForwarding:[GlobalEvent sharedMachine].server_port withMinWanPort:min_port withMaxWanPort:max_port withQueue:_queue withHandler:^(uint16_t port, int upnp_error_code) {
        [weak_self _upnpHandlePortForwardingResult:port withBlock:block doRetry:retry withUPnPError:upnp_error_code];
    }];
}

- (void)_upnpFound:(void (^)(NSString *, UPnPServiceErrorCode, int))block doRetry:(BOOL)retry
{
    [_upnp getExternalIPAddress:_queue withHandler:^(NSString *ip, int upnp_error_code) {
        _external_ip = ip;

        if (_external_ip != nil) {
            DBG("External IP: %@", _external_ip);

            [self _upnpGetExternalAddress:block doRetry:retry];
        } else {
            block(nil, UPNPSERVICE_ERROR_NO_EXTERNAL_IP, upnp_error_code);
        }
    }];
}

- (void)getExternalURL:(void (^)(NSString *, UPnPServiceErrorCode, int))block
{
    @synchronized(self) {
        _upnp_retry_count = 0;

        [_upnp discoverValidIGD:_queue withHandler:^(BOOL found, int upnp_error_code) {
            if (found) {
                [self _upnpFound:block doRetry:YES];
            } else {
                block(nil, UPNPSERVICE_ERROR_NO_IGD, upnp_error_code);
            }
        }];
    }
}

- (void)reassignPinhole:(void (^)(BOOL, int))block
{
    @synchronized(self) {
        _upnp_retry_count = 0;

        [_upnp discoverValidIGD:_queue withHandler:^(BOOL found, int upnp_error_code) {
            if (found) {
                [self _upnpFound:^(NSString *url, UPnPServiceErrorCode error_code, int upnp_error_code){
                    block(error_code == UPNPSERVICE_SUCCESS, upnp_error_code);
                } doRetry:NO];
            } else {
                block(NO, upnp_error_code);
            }
        }];
    }
}
- (void)cleanupPinhole:(void (^)(BOOL, int))block
{
    uint16_t port = [GlobalEvent sharedMachine].current_streaming_setting.upnp_external_port;

    if (port != 0) {
        [_upnp removePortForwarding:port withQueue:_queue withBlock:^(BOOL removed_successfully, int upnp_error_code) {
            DBG("Portforwarding removal: %@", removed_successfully ? @"SUCCESS" : @"FAILED");
            block(removed_successfully, upnp_error_code);
        }];
    } else {
        block(NO, 0);
    }
}

@end
