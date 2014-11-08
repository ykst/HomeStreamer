//
//  UPnPService.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/05/30.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UPnPService : NSObject

typedef NS_ENUM(NSInteger, UPnPServiceErrorCode) {
    UPNPSERVICE_SUCCESS = 0,
    UPNPSERVICE_ERROR_NO_IGD,
    UPNPSERVICE_ERROR_NO_EXTERNAL_IP,
    UPNPSERVICE_ERROR_CONFIGURE,
};

+ (instancetype)sharedService;

- (void)getExternalURL:(void (^)(NSString *url, UPnPServiceErrorCode error_code, int upnp_error_code))block;
- (void)reassignPinhole:(void (^)(BOOL success, int upnp_error_code))block;
- (void)cleanupPinhole:(void (^)(BOOL success, int upnp_error_code))block;

@end
