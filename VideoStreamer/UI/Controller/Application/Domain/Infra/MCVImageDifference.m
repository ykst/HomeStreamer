//
//  MCVImageDifference.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/03.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "MCVImageDifference.h"

@interface MCVImageDifference() {
    GLint _uniform_iframe_tex;
    GLint _uniform_pframe_tex;
}

@end

@implementation MCVImageDifference

+ (instancetype)create
{
    MCVImageDifference *obj = [[[self class] alloc] init];

    [TGLDevice runPassiveContextSync:^{
        [obj _setupShader];
    }];

    return obj;
}

- (void)_setupShader
{
    extern char image_difference_fs_glsl[];

    [super setupShaderWithFS:NSSTR(image_difference_fs_glsl)];
}

- (BOOL)processIFrame:(MCVBufferFreight *)iframe withPFrame:(MCVBufferFreight *)pframe to:(MCVBufferFreight *)dst
{
    BENCHMARK("image diff")
    [TGLDevice runPassiveContextSync:^{
        [_program use];

        [_fbo bind];
        glViewport(0, 0, dst.size.width, dst.size.height);

        [dst.plane attachColorFB];

        [iframe.plane setUniform:_uniform_iframe_tex onUnit:0];
        [pframe.plane setUniform:_uniform_pframe_tex onUnit:1];

        TGL_BINDBLOCK(_vao) {
            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        };

        [[_fbo class] discardColor];
        [[_fbo class] unbind];
        
        [[_program class] unuse];
    }];

    return YES;
}

@end
