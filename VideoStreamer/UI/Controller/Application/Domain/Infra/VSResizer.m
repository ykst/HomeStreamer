//
//  VSResizer.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/05/14.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "VSResizer.h"

#import <ThinGL/TGLDevice.h>
#import <ThinGL/TGLProgram.h>
#import <ThinGL/TGLVertexArrayObject.h>
#import <ThinGL/TGLVertexBufferObject.h>
#import <ThinGL/TGLFrameBufferObject.h>

@interface VSResizer() {
    VSResizingROI *_roi;
    BOOL _roi_dirty;
}

@property (nonatomic) GLint attribute_position;
@property (nonatomic) GLint attribute_inputTextureCoordinate;

@property (nonatomic) GLint uniform_inputTexture;

@end

@implementation VSResizer

+ (instancetype)create
{
    VSResizer *obj = [[[self class] alloc] init];

    [TGLDevice runPassiveContextSync:^{
        [obj _setup];
    }];

    return obj;
}

- (void)_setup
{
    _roi = [VSResizingROI createDefault];
    _roi_dirty = YES;

    [self _setupShader];
}

- (void)_setupShader
{
    extern char passthrough_1tex_vs_glsl[];
    extern char passthrough_1tex_fs_glsl[];

    [self setupShaderWithVS:NSSTR(passthrough_1tex_vs_glsl) withFS:NSSTR(passthrough_1tex_fs_glsl)];

    _vao = [TGLVertexArrayObject create];

    [_vao bind];

    _vbo = [TGLVertexBufferObject createVBOWithUsage:GL_DYNAMIC_DRAW
                                      withAutoOffset:YES
                                         withCommand:(struct gl_vbo_object_command []){
                                             {
                                                 .attribute = _attribute_position,
                                                 .counts = 2,
                                                 .type = GL_FLOAT,
                                                 .elems = 4,
                                                 .ptr = (GLfloat [8]) {
                                                     -1, -1,
                                                     1, -1,
                                                     -1, 1,
                                                     1, 1
                                                 }
                                             },
                                             {
                                                 .attribute = _attribute_inputTextureCoordinate,
                                                 .counts = 2,
                                                 .type = GL_FLOAT,
                                                 .elems = 4,
                                                 .ptr = NULL
                                             },
                                             {}
                                         }];

    [[_vao class] unbind]; // save the state

    _fbo = [TGLFrameBufferObject createEmptyFrameBuffer];
}

- (BOOL)setROI:(VSResizingROI *)roi
{
    _roi = roi;
    _roi_dirty = YES;
    // TODO: validation

    return YES;
}

- (BOOL)process:(MCVBufferFreight *)src to:(MCVBufferFreight *)dst
{
    BENCHMARK("vs resizer")
    [TGLDevice runPassiveContextSync:^{
        [_program use];

        if (_roi_dirty) {
            GLKVector2 texture_coord[4] = {};
            float aspect_ratio = dst.size.height / dst.size.width;
            [_roi calcTextureCoord:texture_coord withAspectRatio:aspect_ratio];
            [_vbo subDataOfAttribute:_attribute_inputTextureCoordinate withPointer:texture_coord withElems:4];
            _roi_dirty = NO;
        }

        TGL_BINDBLOCK(_fbo) {
            glViewport(0, 0, dst.size.width, dst.size.height);

            [dst.plane attachColorFB];
            [src.plane setUniform:_uniform_inputTexture onUnit:0];

            TGL_BINDBLOCK(_vao) {
                glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);GLASSERT;
            }
            
            [[_fbo class] discardColor];
        }
    }];
    
    return YES;
}
@end