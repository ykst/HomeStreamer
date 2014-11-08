//
//  MCVJPEGEncoder.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/03.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#include "libturbojpeg/turbojpeg.h"
// #include "../libjpeg-turbo/turbojpeg.h" // XXX: add to header search path
#import "MCVJPEGEncoder.h"

@interface MCVJPEGEncoder() {
    tjhandle _compressor;
    size_t _last_jpeg_size;
}
@end

@implementation MCVJPEGEncoder

+ (instancetype)create
{
    MCVJPEGEncoder *obj = [[[self class] alloc] init];

    ASSERT([obj _setup], return nil);

    return obj;
}

- (BOOL)_setup
{
    ASSERT(_compressor = tjInitCompress(), return NO);

    _last_jpeg_size = 0;

    return YES;
}

- (void)dealloc
{
    if (_compressor) {
        tjDestroy(_compressor);
        _compressor = NULL;
    }
}

#if 0
- (BOOL)process:(MCVBufferFreight *)src
             to:(MALByteFreight *)dst
    withQuality:(int)quality
{
    EXPECT(quality > 0 && quality <= 100, quality = 50);

    int width = src.plane.size.width;
    int height = src.plane.size.height;
    long unsigned int jpeg_size = 0;
    unsigned char *compressed_tjbuf = NULL;

    BENCHMARK("turbo compress") {

        ASSERT(tjCompress2(_compressor,
                           [src.plane lockWritable],
                           width,
                           0,
                           height,
                           TJPF_RGBA,
                           &compressed_tjbuf,
                           &jpeg_size,
                           TJSAMP_420,
                           quality,
                           TJFLAG_FASTDCT) == 0, { [src.plane unlockWritable]; return NO;});
    }

    [src.plane unlockWritable];

    ASSERT(compressed_tjbuf, return NO);

    [dst feedPreallocBytes:compressed_tjbuf withLength:jpeg_size];

#ifdef ENABLE_BENCHMARK
    DUMPD(jpeg_size);
#endif

    return YES;
}
#endif

- (TimestampedData *)process420P:(VSPlanarImageFreight *)src withQuality:(int)quality
{
    EXPECT(quality > 0 && quality <= 100, quality = 50);

    int width = src.size.width;
    int height = src.size.height;

    // libjpeg performs realloc and memcopy while dumping output buffer
    // when the given buffer ran out of length.
    // so, we give double of the last buffer size at start to compromise the
    // penalty and memory pressure
    long unsigned int jpeg_size = _last_jpeg_size * 2;
    unsigned char *compressed_tjbuf = (unsigned char *)malloc(jpeg_size);

    void *y_buf = [src.plane lockWritable];
    void *u_buf = [src.subplane1 lockWritable];
    void *v_buf = [src.subplane2 lockWritable];

    BENCHMARK("turbo compress planar") {
        ASSERT(tjCompress2_420P(_compressor,
                           y_buf,
                           u_buf,
                           v_buf,
                           src.lumina_rowlength,
                           src.chroma_rowlength,
                           width,
                           0,
                           height,
                           TJPF_RGBA,
                           &compressed_tjbuf,
                           &jpeg_size,
                           TJSAMP_420,
                           quality,
                           TJFLAG_FASTDCT) == 0, {
            [src.plane unlockWritable];
            [src.subplane1 unlockWritable];
            [src.subplane2 unlockWritable];
            return nil;
        });
    }
    [src.plane unlockWritable];
    [src.subplane1 unlockWritable];
    [src.subplane2 unlockWritable];

    ASSERT(compressed_tjbuf, return nil);

    _last_jpeg_size = jpeg_size;

#ifdef ENABLE_BENCHMARK
    DUMPD(jpeg_size);
#endif

    return [TimestampedData createWithPoint:compressed_tjbuf withLength:jpeg_size withTimeStamp:src.timestamp];
}

@end
