//
//  MiniUPnPc.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/05/08.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "MiniUPnPc_iOS.h"

#include "upnpcommands.h"
#include "upnperrors.h"
#include "miniupnpc.h"

@interface MiniUPnPc() {
    struct UPNPDev * _devlist;
    struct UPNPUrls _urls;
    struct IGDdatas _data;
}
@end

@implementation MiniUPnPc

+ (instancetype)create
{
    MiniUPnPc *obj = [[[self class] alloc] init];

    ASSERT([obj _setup], return nil);

    return obj;
}

- (void)setPortForwarding:(uint16_t)lan_port withMinWanPort:(uint16_t)min_wan_port withMaxWanPort:(uint16_t)max_wan_port withQueue:(dispatch_queue_t)queue withHandler:(void (^)(uint16_t, int))block
{
    [self _execQueue:queue withBlock:^{
        const int port_range = max_wan_port - min_wan_port;

        uint16_t eport = (port_range <= 0) ? min_wan_port : ((arc4random() % port_range) + min_wan_port);

        int result = UPNP_AddPortMapping(_urls.controlURL, _data.first.servicetype,
                                         [NSPRINTF(@"%d", eport) UTF8String],
                                         [NSPRINTF(@"%d", lan_port) UTF8String],
                                         [_local_ip UTF8String],
                                         "home-streamer",
                                         protofix("TCP"), 0, "0");

        if (result == UPNPCOMMAND_SUCCESS) {
            block(eport, result);
        } else {
            block(0, result);
        }
    }];
}

- (void)removePortForwarding:(uint16_t)wan_port withQueue:(dispatch_queue_t)queue withBlock:(void (^)(BOOL, int))block
{
    [self _execQueue:queue withBlock:^{
        int result = UPNP_DeletePortMapping(_urls.controlURL,
                                            _data.first.servicetype,
                                            [NSPRINTF(@"%d", wan_port) UTF8String],
                                            protofix("TCP"), 0);

        DBG("UPNP_DeletePortMapping() returned : %d\n", result);

        block(result == UPNPCOMMAND_SUCCESS, result);
    }];
}

/* protofix() checks if protocol is "UDP" or "TCP"
 * returns NULL if not */
const char * protofix(const char * proto)
{
	static const char proto_tcp[4] = { 'T', 'C', 'P', 0};
	static const char proto_udp[4] = { 'U', 'D', 'P', 0};
	int i, b;
	for(i=0, b=1; i<4; i++)
		b = b && (   (proto[i] == proto_tcp[i])
		          || (proto[i] == (proto_tcp[i] | 32)) );
	if(b)
		return proto_tcp;
	for(i=0, b=1; i<4; i++)
		b = b && (   (proto[i] == proto_udp[i])
		          || (proto[i] == (proto_udp[i] | 32)) );
	if(b)
		return proto_udp;
	return 0;
}

- (void)_execQueue:(dispatch_queue_t)queue withBlock:(void (^)())block
{
    dispatch_async(queue, ^{
        @synchronized(self) {
            block();
        }
    });
}

- (void)getExternalIPAddress:(dispatch_queue_t)queue withHandler:(void (^)(NSString *, int))block
{
    [self _execQueue:queue withBlock:^{
        char externalIPAddress[40] = {};

        int result = UPNP_GetExternalIPAddress(_urls.controlURL,
                                  _data.first.servicetype,
                                  externalIPAddress);

        NSString *ip = nil;

        if (externalIPAddress[0]) {
            DBG("ExternalIPAddress = %s\n", externalIPAddress);
            ip = NSSTR(externalIPAddress);
        }
        
        block(ip, result);
    }];
}

- (void)discoverValidIGD:(dispatch_queue_t)queue withHandler:(void (^)(BOOL, int))block
{
    [self _execQueue:queue withBlock:^{
        const char * multicastif = 0;
        const char * minissdpdpath = 0;
        int ipv6 = 0;
        int error = 0;
        const int delay_msec = 2000;

        _devlist = upnpDiscover(delay_msec,
                                multicastif,
                                minissdpdpath,
                                0/*sameport*/,
                                ipv6,
                                &error);

        ASSERT(_devlist, ({ block(NO, -1); return; }));

        struct UPNPUrls urls = {};
        struct IGDdatas data = {};

        char lanaddr[64] = {};

        int validation_result = UPNP_GetValidIGD(_devlist, &urls, &data, lanaddr, sizeof(lanaddr));

        switch(validation_result) {
            case 1:
                DBG("Found valid IGD : %s\n", urls.controlURL);
                break;
            case 2:
                DBG("Found a (not connected?) IGD : %s\n", urls.controlURL);
                DBG("Trying to continue anyway\n");
                break;
            case 3:
                DBG("UPnP device found. Is it an IGD ? : %s\n", urls.controlURL);
                DBG("Trying to continue anyway\n");
                break;
            default:
                DBG("Found device (igd ?) : %s\n", urls.controlURL);
                DBG("Trying to continue anyway\n");
        }
        
        DBG("Local LAN ip address : %s\n", lanaddr);

        _local_ip = NSSTR(lanaddr);

        _urls = urls;
        _data = data;

        block(validation_result == 1, validation_result);
    }];
}

- (void)dealloc
{
    @synchronized(self) {
        if (_devlist != NULL) {
            freeUPNPDevlist(_devlist);
            _devlist = NULL;
        }
    };
}

- (BOOL)_setup
{
    return YES;
}
@end
