//
//  MainHTTPServer.h
//  ReverseStreamer
//
//  Created by Yukishita Yohsuke on 2014/06/08.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <CocoaHTTPServer/HTTPServer.h>

#define SWS_DEFAULT_DOCROOT (@"Assets/Web")

@interface SWSHTTPServer : HTTPServer

+ (instancetype)create;
+ (instancetype)createWithDocRoot:(NSString *)rel_path;
- (BOOL)startServerWithPort:(uint16_t)port;
- (BOOL)startServer;

@end
