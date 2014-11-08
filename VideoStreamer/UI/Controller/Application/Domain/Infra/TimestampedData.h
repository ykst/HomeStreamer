//
//  TimestampedData.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on H26/06/18.
//  Copyright (c) 平成26年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TimestampedData : NSObject

@property (nonatomic, readwrite) NSData *data;
@property (nonatomic, readwrite) struct timeval timestamp;

+ (instancetype)createWithPoint:(void *)ptr withLength:(int)length withTimeStamp:(struct timeval)timestamp;
@end
