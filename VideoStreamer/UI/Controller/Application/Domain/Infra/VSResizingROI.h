//
//  VSResizingROI.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/04/22.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VSResizingROI : NSObject<NSCopying, NSCoding>

@property (nonatomic, readwrite) CGPoint center;
@property (nonatomic, readwrite) CGFloat scale;
@property (nonatomic, readwrite) uint16_t degree;

+ (instancetype)createDefault;

- (void)calcTextureCoord:(GLKVector2[4])coord withAspectRatio:(float)aspect_ratio;

- (void)calcTextureCoordWithXOffset:(GLfloat)x_offset for:(GLKVector2[4])coord withAspectRatio:(float)aspect_ratio;
@end