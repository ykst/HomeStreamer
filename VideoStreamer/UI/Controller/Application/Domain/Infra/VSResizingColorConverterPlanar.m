//
//  VSResizingColorConverterPlanar.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/04/22.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "VSResizingColorConverterPlanar.h"

#import <GLKit/GLKit.h>
#import <ThinGL/TGLDevice.h>
#import <ThinGL/TGLProgram.h>
#import <ThinGL/TGLVertexArrayObject.h>
#import <ThinGL/TGLVertexBufferObject.h>
#import <ThinGL/TGLFrameBufferObject.h>

@interface VSResizingColorConverterPlanar() {
    VSResizingROI *_roi;
    BOOL _roi_dirty;
}

@property (nonatomic) GLint attribute_position;
@property (nonatomic) GLint attribute_input_texture_coordinate1;
@property (nonatomic) GLint attribute_input_texture_coordinate2;
@property (nonatomic) GLint attribute_input_texture_coordinate3;
@property (nonatomic) GLint attribute_input_texture_coordinate4;

@property (nonatomic) GLint uniform_source_tex;
@property (nonatomic) GLint uniform_lut_tex;
@property (nonatomic) GLint uniform_mode;
@end

@implementation VSResizingColorConverterPlanar

+ (instancetype)create
{
    VSResizingColorConverterPlanar *obj = [[[self class] alloc] init];

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
    extern char resizing_planar_ccv_vs_glsl[];
    extern char resizing_planar_ccv_fs_glsl[];

    [self setupShaderWithVS:NSSTR(resizing_planar_ccv_vs_glsl) withFS:NSSTR(resizing_planar_ccv_fs_glsl)];

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
                                                 .attribute = _attribute_input_texture_coordinate1,
                                                 .counts = 2,
                                                 .type = GL_FLOAT,
                                                 .elems = 4,
                                                 .ptr = NULL
                                             },
                                             {
                                                 .attribute = _attribute_input_texture_coordinate2,
                                                 .counts = 2,
                                                 .type = GL_FLOAT,
                                                 .elems = 4,
                                                 .ptr = NULL
                                             },
                                             {
                                                 .attribute = _attribute_input_texture_coordinate3,
                                                 .counts = 2,
                                                 .type = GL_FLOAT,
                                                 .elems = 4,
                                                 .ptr = NULL
                                             },
                                             {
                                                 .attribute = _attribute_input_texture_coordinate4,
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

- (BOOL)process:(MCVBufferFreight<MCVSubPlanerBufferProtocol> *)src withLut:(MCVBufferFreight *)lut to:(MCVBufferFreight<MCVTriplePlanerBufferProtocol> *)dst
{
    BENCHMARK("resizing ccv")
    [TGLDevice runPassiveContextSync:^{
        [_program use];

        if (_roi_dirty) {
            GLKVector2 texture_coord[4] = {};
            const float aspect_ratio = dst.size.height / dst.size.width;
            const float skip_unit = MAX(src.size.width, src.size.height) / MAX(dst.size.width, dst.size.height);

            [_roi calcTextureCoordWithXOffset:0 for:texture_coord withAspectRatio:aspect_ratio];
            [_vbo subDataOfAttribute:_attribute_input_texture_coordinate1 withPointer:texture_coord withElems:4];

            [_roi calcTextureCoordWithXOffset:(skip_unit / src.size.width) for:texture_coord withAspectRatio:aspect_ratio];
            [_vbo subDataOfAttribute:_attribute_input_texture_coordinate2 withPointer:texture_coord withElems:4];

            [_roi calcTextureCoordWithXOffset:((skip_unit * 2.0f) / src.size.width) for:texture_coord withAspectRatio:aspect_ratio];
            [_vbo subDataOfAttribute:_attribute_input_texture_coordinate3 withPointer:texture_coord withElems:4];

            [_roi calcTextureCoordWithXOffset:((skip_unit * 3.0f) / src.size.width) for:texture_coord withAspectRatio:aspect_ratio];
            [_vbo subDataOfAttribute:_attribute_input_texture_coordinate4 withPointer:texture_coord withElems:4];

            _roi_dirty = NO;
        }

        TGL_BINDBLOCK(_fbo) {
            // Y plane
            [src.plane setUniform:_uniform_source_tex onUnit:0];

            if (lut != nil) {
                [lut.plane setUniform:_uniform_lut_tex onUnit:1];
                glUniform1i(_uniform_mode, 0);
            } else {
                glUniform1i(_uniform_mode, 1);
            }

            glViewport(0, 0, dst.size.width / 4, dst.size.height);

            [dst.plane attachColorFB];


            //glUniform1f(_uniform_x_step, 2.0f / src.size.width);

            [_vao bind];
            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);GLASSERT;

            // U plane
            [src.subplane setUniform:_uniform_source_tex onUnit:2];
            [dst.subplane1 attachColorFB];
            glViewport(0, 0, dst.size.width / 8, dst.size.height / 2);
            glUniform1i(_uniform_mode, 2);
            //glUniform1f(_uniform_x_step, 2.0f / src.size.width);

            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);GLASSERT;

            // V plane
            [dst.subplane2 attachColorFB];

            glUniform1i(_uniform_mode, 3);

            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);GLASSERT;

            [[_vao class] unbind];
            
            [[_fbo class] discardColor];
        }
    }];
    
    return YES;
}
@end