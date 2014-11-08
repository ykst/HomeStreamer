//
//  VSPlanarImageFreight.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/04/22.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <MobileCV/MCVBufferFreight.h>
#import <MobileAL/MALTimeStampFreightProtocol.h>

@interface VSPlanarImageFreight : MCVBufferFreight<MCVTriplePlanerBufferProtocol, MALTimeStampFreightProtocol> {
@protected
    struct timeval _timestamp;
}

@property (nonatomic, readwrite) struct timeval timestamp;
@property (nonatomic, readonly) int lumina_rowlength;
@property (nonatomic, readonly) int chroma_rowlength;

+ (instancetype)create420WithSize:(CGSize)size withSmooth:(BOOL)smooth;

- (BOOL)resize:(CGSize)size;

@end