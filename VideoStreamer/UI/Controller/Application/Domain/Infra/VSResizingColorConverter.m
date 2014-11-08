//
//  VSResizingColorConverter.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/12.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "VSResizingColorConverter.h"

#import <GLKit/GLKit.h>
#import <ThinGL/TGLDevice.h>
#import <ThinGL/TGLProgram.h>
#import <ThinGL/TGLVertexArrayObject.h>
#import <ThinGL/TGLVertexBufferObject.h>
#import <ThinGL/TGLFrameBufferObject.h>

@interface VSResizingColorConverter() {
    VSResizingROI *_roi;
    BOOL _roi_dirty;
}

@property (nonatomic) GLint attribute_position;
@property (nonatomic) GLint attribute_inputTextureCoordinate;

@property (nonatomic) GLint uniform_luminanceTexture;
@property (nonatomic) GLint uniform_chrominanceTexture;
@property (nonatomic) GLint uniform_colorConversionMatrix;
@property (nonatomic) GLint uniform_luminance_lut_tex;

@end

@implementation VSResizingColorConverter

+ (instancetype)create
{
    VSResizingColorConverter *obj = [[[self class] alloc] init];

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
    extern char resizing_ccv_fs_glsl[];

    [self setupShaderWithVS:NSSTR(passthrough_1tex_vs_glsl) withFS:NSSTR(resizing_ccv_fs_glsl)];

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

    /*
     // BT.601, which is the standard for SDTV.
     const GLfloat kColorConversion601[] = {
     1.164,  1.164, 1.164,
     0.0, -0.392, 2.017,
     1.596, -0.813,   0.0,
     };

     // BT.709, which is the standard for HDTV.
     const GLfloat kColorConversion709[] = {
     1.164,  1.164, 1.164,
     0.0, -0.213, 2.112,
     1.793, -0.533,   0.0,
     };
     CFTypeRef colorAttachments = CVBufferGetAttachment(cameraFrame, kCVImageBufferYCbCrMatrixKey, NULL);
     if (colorAttachments == kCVImageBufferYCbCrMatrix_ITU_R_601_4) {
     _preferredConversion = kColorConversion601;
     }
     else {
     _preferredConversion = kColorConversion709;
     }
     */

    const GLfloat kColorConversion601[] = {
        1.164,  1.164, 1.164,
        0.0, -0.213, 2.112,
        1.793, -0.533,   0.0,
    };

    [_program use];
    glUniformMatrix3fv(_uniform_colorConversionMatrix, 1, GL_FALSE, kColorConversion601);
    [TGLProgram unuse];

    _fbo = [TGLFrameBufferObject createEmptyFrameBuffer];
}

- (BOOL)setROI:(VSResizingROI *)roi
{
    _roi = roi;
    _roi_dirty = YES;
    // TODO: validation

    return YES;
}

- (BOOL)process:(MCVBufferFreight<MCVSubPlanerBufferProtocol> *)src withLut:(MCVBufferFreight *)lut to:(MCVBufferFreight *)dst
{
    BENCHMARK("resizing ccv")
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

            [src.plane setUniform:_uniform_luminanceTexture onUnit:2];
            [src.subplane setUniform:_uniform_chrominanceTexture onUnit:3];
            [lut.plane setUniform:_uniform_luminance_lut_tex onUnit:4];

            TGL_BINDBLOCK(_vao) {
                glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);GLASSERT;
            }
            
            [[_fbo class] discardColor];
        }
    }];
    
    return YES;
}
@end
