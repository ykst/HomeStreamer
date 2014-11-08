//
//  VSResizer.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/05/14.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "TGLShaderWrapper.h"
#import <MobileCV/MCVBufferFreight.h>
#import "VSResizingROI.h"

@interface VSResizer : TGLShaderWrapper
+ (instancetype)create;
- (BOOL)process:(MCVBufferFreight *)src to:(MCVBufferFreight *)dst;
- (BOOL)setROI:(VSResizingROI *)roi;
@end
