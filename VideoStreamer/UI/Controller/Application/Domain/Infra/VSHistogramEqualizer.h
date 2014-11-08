//
//  VSHistogramEqualizer.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/14.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MobileCV/MCVBufferFreight.h>
#import "VSResizingROI.h"

@interface VSHistogramEqualizer : NSObject

@property (nonatomic, readonly) MCVBufferFreight *lut;
@property (nonatomic, readonly) BOOL is_normal;
+ (instancetype)create;

- (BOOL)updateLUT:(MCVBufferFreight *)luminance;
- (void)setNormalLUT;
// - (BOOL)setROI:(VSResizingROI *)roi;

@end
