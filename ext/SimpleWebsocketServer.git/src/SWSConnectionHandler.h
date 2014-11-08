//
//  SWSConnectionHandler.h
//  Pods
//
//  Created by Yukishita Yohsuke on H26/06/13.
//
//

#import <Foundation/Foundation.h>

#import "SWSMessage.h"
#import "SWSConnectionState.h"
//@class SWSConnectionState;
//@protocol SWSConnectionStateDelegate;

@interface SWSConnectionHandler : NSObject <SWSOnReadMessageDelegate, SWSConnectionStateDelegate> // Abstract
+ (instancetype)createWithConnection:(SWSConnectionState *)connection;

- (void)teardown; // called on close. override it!

@end
