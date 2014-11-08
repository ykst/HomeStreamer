//
//  MCVImageDifference.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/03.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <MobileCV/MCVPassthroughShaderWrapper.h>
#import <MobileCV/MCVBufferFreight.h>

@interface MCVImageDifference : MCVPassthroughShaderWrapper

+ (instancetype)create;

- (BOOL)processIFrame:(MCVBufferFreight *)iframe withPFrame:(MCVBufferFreight *)pframe to:(MCVBufferFreight *)dst;

@end
