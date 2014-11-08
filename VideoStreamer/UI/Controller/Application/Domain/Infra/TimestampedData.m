//
//  TimestampedData.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on H26/06/18.
//  Copyright (c) 平成26年 monadworks. All rights reserved.
//

#import "TimestampedData.h"

@implementation TimestampedData

+ (instancetype)createWithPoint:(void *)ptr withLength:(int)length withTimeStamp:(struct timeval)timestamp
{
    TimestampedData *obj = [[[self class] alloc] init];

    if (ptr != NULL) {
        obj.data = [NSData dataWithBytesNoCopy:ptr length:length freeWhenDone:YES];
    } else {
        obj.data = nil;
    }

    obj.timestamp = timestamp;

    return obj;
}

@end
