//
//  VSResizingROI.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/04/22.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <GLKit/GLKit.h>

#import "VSResizingROI.h"


@implementation VSResizingROI

+ (instancetype)createDefault
{
    VSResizingROI *obj = [[[self class] alloc] init];

    obj.center = CGPointMake(0.5, 0.5);
    obj.scale = 1.0;
    obj.degree = 0;

    return obj;
}

- (id)copyWithZone:(NSZone *)zone
{
    VSResizingROI *copied = [[self class] new];

    copied.center = _center;
    copied.scale = _scale;
    copied.degree = _degree;

    return copied;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        self.center = [decoder decodeCGPointForKey:@"center"];
        self.scale = [decoder decodeFloatForKey:@"scale"];
        self.degree = [decoder decodeIntegerForKey:@"degree"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeCGPoint:_center forKey:@"center"];
    [encoder encodeFloat:_scale forKey:@"scale"];
    [encoder encodeInteger:_degree forKey:@"degree"];
}

static inline GLKVector2 __mat3_vec2_multiply(GLKMatrix3 mat3, GLfloat x, GLfloat y)
{
    return GLKVector2Make(mat3.m00 * x + mat3.m01 * y + mat3.m02,
                          mat3.m10 * x + mat3.m11 * y + mat3.m12);
}


- (void)calcTextureCoordWithXOffset:(GLfloat)x_offset
                                for:(GLKVector2 [4])coord
                    withAspectRatio:(float)aspect_ratio
{
    BOOL landscape_mode = aspect_ratio < 1.0f;
    GLfloat rad = (_degree * M_PI) / 180.0;

    if (landscape_mode) {
        GLKMatrix3 transpose = GLKMatrix3Make(1, 0, _center.x,
                                              0, 1, _center.y * aspect_ratio,
                                              0, 0, 1);
        GLKMatrix3 rotation = GLKMatrix3RotateZ(GLKMatrix3Identity, rad);
        GLKMatrix3 scale = GLKMatrix3Make(1 * _scale, 0, 0,
                                          0, aspect_ratio * _scale, 0,
                                          0, 0, 1);
        GLKMatrix3 centering = GLKMatrix3Make(1, 0, -0.5 + x_offset,
                                              0, 1, -0.5,
                                              0, 0, 1);
        GLKMatrix3 affine_m3x3 =
        GLKMatrix3Multiply(centering,
                           GLKMatrix3Multiply(scale,
                                              GLKMatrix3Multiply(rotation,
                                                                 transpose)));

        coord[0] = __mat3_vec2_multiply(affine_m3x3, 0, 0);
        coord[1] = __mat3_vec2_multiply(affine_m3x3, 1, 0);
        coord[2] = __mat3_vec2_multiply(affine_m3x3, 0, 1);
        coord[3] = __mat3_vec2_multiply(affine_m3x3, 1, 1);

        for (int i = 0; i < 4; ++i) {
            coord[i].y = coord[i].y / aspect_ratio;
        }
    } else {
        GLKMatrix3 transpose = GLKMatrix3Make(1, 0, 1.0 - _center.y,
                                              0, 1, _center.x / aspect_ratio,
                                              0, 0, 1);
        GLKMatrix3 rotation = GLKMatrix3RotateZ(GLKMatrix3Identity, rad);
        GLKMatrix3 scale = GLKMatrix3Make(1 * _scale, 0, 0,
                                          0, _scale / aspect_ratio, 0,
                                          0, 0, 1);
        GLKMatrix3 centering = GLKMatrix3Make(1, 0, -0.5,
                                              0, 1, -0.5 + x_offset * aspect_ratio,
                                              0, 0, 1);
        GLKMatrix3 affine_m3x3 =
        GLKMatrix3Multiply(centering,
                           GLKMatrix3Multiply(scale,
                                              GLKMatrix3Multiply(rotation,
                                                                 transpose)));

        coord[0] = __mat3_vec2_multiply(affine_m3x3, 1, 0);
        coord[1] = __mat3_vec2_multiply(affine_m3x3, 1, 1);
        coord[2] = __mat3_vec2_multiply(affine_m3x3, 0, 0);
        coord[3] = __mat3_vec2_multiply(affine_m3x3, 0, 1);

        for (int i = 0; i < 4; ++i) {
            coord[i].y = coord[i].y * aspect_ratio;
        }
    }
}

- (void)calcTextureCoord:(GLKVector2[4])coord withAspectRatio:(float)aspect_ratio
{
    [self calcTextureCoordWithXOffset:0 for:coord withAspectRatio:aspect_ratio];
}
@end
