//
//  VSMainDisplayV.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/14.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "MCVDisplayV.h"

@interface VSMainDisplayV : MCVDisplayV
@property (nonatomic, readwrite) BOOL mirror_mode;
- (void)showSleepSplash;
- (void)clearSleepSplash;
@end
