//
//  VSResizingColorConverter.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/12.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <ThinGL/TGLShaderWrapper.h>
#import <MobileCV/MCVBufferFreight.h>
#import "VSResizingROI.h"

@interface VSResizingColorConverter : TGLShaderWrapper

+ (instancetype)create;
- (BOOL)process:(MCVBufferFreight<MCVSubPlanerBufferProtocol> *)src withLut:(MCVBufferFreight *)lut to:(MCVBufferFreight *)dst;
- (BOOL)setROI:(VSResizingROI *)roi;
@end

