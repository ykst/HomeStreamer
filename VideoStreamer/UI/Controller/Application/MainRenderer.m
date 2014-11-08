//
//  MainRenderer.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/02/28.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <MobileCV/MCVTextureRenderer.h>
#import "MainRenderer.h"

@interface MainRenderer() {
    MCVTextureRenderer *_texture_renderer;
    TGLFrameBufferObject *_fbo;
    CGSize _screen_size;
}

@end

@implementation MainRenderer

+ (instancetype)createWithScreenSize:(CGSize)size
{
    MainRenderer *obj = [[[self class] alloc] initWithScreenSize:size];

    return obj;
}

- (id)initWithScreenSize:(CGSize)size
{
    self = [super init];
    if (self) {
        _screen_size = size;

        [TGLDevice runPassiveContextSync:^{
            [self _setupSubtasks];
            [self _setupBuffers];
        }];
    }
    return self;
}

- (void)_setupSubtasks
{
    _texture_renderer = [MCVTextureRenderer create];
}

- (void)_setupBuffers
{
    _fbo = [TGLFrameBufferObject createEmptyFrameBuffer];
}

- (BOOL)process:(MCVBufferFreight *)src to:(MCVBufferFreight *)dst
{
    [TGLDevice runPassiveContextSync:^{
        [_fbo bind];

        [dst.plane attachColorFB];

        glViewport(0, 0, dst.plane.size.width, dst.plane.size.height);

        [_texture_renderer process:src];


        [[_fbo class] discardColor];
        [[_fbo class] unbind];
    }];
    
    return YES;
}

@end