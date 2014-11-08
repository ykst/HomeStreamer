//
//  MCVJPEGEncoder.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/03.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MobileCV/MCVBufferFreight.h>
#import <MobileAL/MALByteFreight.h>
#import <MobileAL/MALTimeStampFreightProtocol.h>
#import "VSPlanarImageFreight.h"
#import "TimestampedData.h"
@interface MCVJPEGEncoder : NSObject

+ (instancetype)create;

- (TimestampedData *)process420P:(VSPlanarImageFreight *)src
    withQuality:(int)quality; // quality = [1,100]; higher is better

@end
