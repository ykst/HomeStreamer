//
//  NSString+Randomize.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/07.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Randomize)

+ (instancetype)stringWithRandomAlphanum:(NSUInteger)length;
@end
