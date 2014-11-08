//
//  PerformanceStatistics.h
//  ReverseStreamer
//
//  Created by Yukishita Yohsuke on 2014/06/09.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SWSPerformanceStatistics : NSObject

//+ (instancetype)sharedManager;
+ (instancetype)create;

- (void)increaseOutputNetworkBytes:(NSUInteger)num_bytes;
- (void)increaseInputNetworkBytes:(NSUInteger)num_bytes;

// NOTE: a little heavy.
- (double)calcCurrentOutputBytesPerSeconds;
- (double)calcCurrentInputBytesPerSeconds;

@end
