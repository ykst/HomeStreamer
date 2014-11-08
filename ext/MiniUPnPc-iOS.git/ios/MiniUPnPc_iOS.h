//
//  MiniUPnPc.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/05/08.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MiniUPnPc : NSObject

+ (instancetype)create;

// WARNING!: all the handler blocks are dispatched by private queue
- (void)discoverValidIGD:(dispatch_queue_t)queue withHandler:(void (^)(BOOL found, int upnp_error_code))block;

- (void)getExternalIPAddress:(dispatch_queue_t)queue withHandler:(void (^)(NSString *ip, int upnp_error_code))block;

- (void)setPortForwarding:(uint16_t)lan_port withMinWanPort:(uint16_t)min_wan_port withMaxWanPort:(uint16_t)max_wan_port withQueue:(dispatch_queue_t)queue withHandler:(void (^)(uint16_t port, int upnp_error_code))block; // port 0 -> Error

- (void)removePortForwarding:(uint16_t)wan_port withQueue:(dispatch_queue_t)queue withBlock:(void (^)(BOOL removed_successfully, int upnp_error_code))block;

@property (atomic, readonly) NSString *local_ip;

@end
