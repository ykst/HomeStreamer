//
//  VSPlanarImageFreight.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/04/22.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "VSPlanarImageFreight.h"

@interface VSPlanarImageFreight() {
    TGLMappedTexture2D *_subplane1;
    TGLMappedTexture2D *_subplane2;

    CGSize _lumina_plane_size;
    CGSize _chroma_plane_size;
}
@end

@implementation VSPlanarImageFreight
@synthesize subplane1 = _subplane1;
@synthesize subplane2 = _subplane2;

static inline CGSize __calc_lumina_plane_size(CGSize resolution_size)
{
    return CGSizeMake(((int)(resolution_size.width / 4) & ~31) + 32, resolution_size.height);
}

static inline CGSize __calc_chroma_plane_size(CGSize resolution_size)
{
    //return CGSizeMake(resolution_size.width / 8, resolution_size.height / 2);
    return CGSizeMake(((int)(resolution_size.width / 8) & ~31) + 32, resolution_size.height / 2);
}

+ (instancetype)create420WithSize:(CGSize)size withSmooth:(BOOL)smooth
{
    // Debug check
    VSPlanarImageFreight *obj = [[self class] createWithSize:__calc_lumina_plane_size(size) withInternalFormat:GL_RGBA withSmooth:smooth];

    ASSERT([obj _setupWithSize:size withSmooth:smooth], return nil);

    return obj;
}

- (BOOL)_setupWithSize:(CGSize)size withSmooth:(BOOL)smooth
{
    NSASSERT(((int)size.width) % 8 == 0);
    NSASSERT(((int)size.height) % 8 == 0);

    _size = size;
    _lumina_plane_size = __calc_lumina_plane_size(size);
    _chroma_plane_size = __calc_chroma_plane_size(size);
    _lumina_rowlength = _lumina_plane_size.width * 4;
    _chroma_rowlength = _chroma_plane_size.width * 4;

    ASSERT(_subplane1 = [TGLMappedTexture2D createWithSize:_chroma_plane_size withInternalFormat:GL_RGBA withSmooth:smooth], return NO);

    ASSERT(_subplane2 = [TGLMappedTexture2D createWithSize:_chroma_plane_size withInternalFormat:GL_RGBA withSmooth:smooth], return NO);

    return YES;
}

- (BOOL)resize:(CGSize)size
{
    ASSERT([self _setupWithSize:size withSmooth:self.smooth], return  NO);
    ASSERT([super resize:_lumina_plane_size], return NO);

    _size = size;

    return YES;
}

@end
