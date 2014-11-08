//
//  MCVTimeStampFreightProtocol.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/06.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#include <sys/time.h>
#import <Foundation/Foundation.h>

@protocol MCVTimeStampFreightProtocol <NSObject>

@required
@property (nonatomic, readwrite) struct timeval timestamp;

@end
