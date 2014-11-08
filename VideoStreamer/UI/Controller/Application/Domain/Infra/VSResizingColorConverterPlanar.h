//
//  VSResizingColorConverterPlanar.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/04/22.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <ThinGL/TGLShaderWrapper.h>
#import <MobileCV/MCVBufferFreight.h>
#import "VSResizingROI.h"

@interface VSResizingColorConverterPlanar : TGLShaderWrapper

+ (instancetype)create;
- (BOOL)process:(MCVBufferFreight<MCVSubPlanerBufferProtocol> *)src withLut:(MCVBufferFreight *)lut to:(MCVBufferFreight<MCVTriplePlanerBufferProtocol> *)dst;
- (BOOL)setROI:(VSResizingROI *)roi;
@end

