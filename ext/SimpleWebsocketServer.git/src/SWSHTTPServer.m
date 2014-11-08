//
//  MainHTTPServer.m
//  ReverseStreamer
//
//  Created by Yukishita Yohsuke on 2014/06/08.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "SWSHTTPServer.h"
#import "SWSAbstractFactory.h"

#define MIN_LOCAL_PORT (49152)
#define MAX_LOCAL_PORT (65535)
#define SERVER_START_MAX_RETRY_COUNT (10)

@implementation SWSHTTPServer

+ (instancetype)create
{
    return [[self class] createWithDocRoot:SWS_DEFAULT_DOCROOT];
}

+ (instancetype)createWithDocRoot:(NSString *)rel_path
{
    SWSHTTPServer *obj = [[[self class] alloc] init];
    
    ASSERT([obj _setupWithDocRoot:rel_path], return nil);
    
    return obj;
}

- (BOOL)_setupWithDocRoot:(NSString *)rel_path
{
    [self setConnectionClass:[SWSAbstractFactory sharedFactory].http_connection_class];
    
    NSString *web_path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Assets/Web"];
    NSLog(@"Setting document root: %@", web_path);
    
    [self setDocumentRoot:web_path];
    
    return YES;
}

- (BOOL)startServerWithPort:(uint16_t)listen_port
{
    NSError *error;
    
    [self setPort:listen_port];
    
    if([self start:&error])	{
        DBG("Server started on port %d", [self listeningPort]);
        return YES;
    }
    
    WARN(@"Error starting HTTP Server: %@", error);
    
    return NO;
}

- (BOOL)startServer
{
    if ([self startServerWithPort:80] == YES) return YES;
    if ([self startServerWithPort:8080] == YES) return YES;
    
    for (int i = 0; i < SERVER_START_MAX_RETRY_COUNT; ++i) {
        uint16_t random_port = (arc4random() % (MAX_LOCAL_PORT - MIN_LOCAL_PORT)) + MIN_LOCAL_PORT;
        if ([self startServerWithPort:random_port] == YES) return YES;
    }
    
    ERROR("Failed to start server");
    
    return NO;
}

@end
