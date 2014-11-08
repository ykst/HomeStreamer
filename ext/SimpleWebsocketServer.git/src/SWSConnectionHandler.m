//
//  SWSConnectionHandler.m
//  Pods
//
//  Created by Yukishita Yohsuke on H26/06/13.
//
//

#import "SWSConnectionState.h"
#import "SWSConnectionHandler.h"

@implementation SWSConnectionHandler 

+ (instancetype)createWithConnection:(SWSConnectionState *)connection
{
    SWSConnectionHandler *obj = [[[self class] alloc] init];

    connection.handler = obj;

    return obj;
}

- (void)connectionOnAuthorized
{
    DBG(@"authorized connection");
    // override
}

- (void)connectionOnFinished;
{
    // override
    DBG(@"connection finished");
}

- (void)teardown
{
    DBG(@"teardown");
}

@end
