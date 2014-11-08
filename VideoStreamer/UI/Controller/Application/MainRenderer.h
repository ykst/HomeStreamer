//
//  MainRenderer.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/02/28.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MobileCV/MCVBufferFreight.h>

@interface MainRenderer : NSObject

+ (instancetype)createWithScreenSize:(CGSize)size;

- (BOOL)process:(MCVBufferFreight *)src to:(MCVBufferFreight *)dst;

@end
