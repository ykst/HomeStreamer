//
//  VSHistogramEqualizer.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/14.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <MobileCV/MCVTexturePassthrough.h>
#import "VSResizer.h"
#import "VSHistogramEqualizer.h"

#define MEAN_AVERAGE_SIZE (10)
@interface VSHistogramEqualizer() {
    MCVTexturePassthrough *_shrinker;
    MCVBufferFreight *_work;
    unsigned long _histogram[256];
    unsigned long _cdf[256];

    float _mean_min[MEAN_AVERAGE_SIZE];
    float _mean_max[MEAN_AVERAGE_SIZE];

    uint32_t _cycles;
}

@end

@implementation VSHistogramEqualizer

+ (instancetype)create
{
    VSHistogramEqualizer *obj = [[[self class] alloc] init];

    ASSERT([obj _setup], return nil);

    return obj;
}

- (BOOL)_setup
{
    [TGLDevice runPassiveContextSync:^{
        _shrinker = [MCVTexturePassthrough create];
        _lut = [MCVBufferFreight createWithSize:CGSizeMake(256,1) withInternalFormat:GL_LUMINANCE withSmooth:NO];
        _work = [MCVBufferFreight createWithSize:CGSizeMake(160,120) withInternalFormat:GL_RGBA withSmooth:NO];
    }];

    memset(_mean_min, 0x00, sizeof(_mean_min[0]) * MEAN_AVERAGE_SIZE);
    memset(_mean_max, 0x00, sizeof(_mean_max[0]) * MEAN_AVERAGE_SIZE);

    _cycles = 0;

    [self setNormalLUT];

    return YES;
}
/*
- (BOOL)setROI:(VSResizingROI *)roi
{
    return [_shrinker setROI:roi];
}
 */

- (BOOL)updateLUT:(MCVBufferFreight *)luminance
{
    BENCHMARK("histogram")
    {
        BENCHMARK("hist copy")
        [_shrinker process:luminance to:_work];
        memset(_histogram, 0x00, sizeof(unsigned long) * 256);

        int cnt = _work.size.height * _work.size.width;

        uint8_t *rgba_u8 = [_work.plane lockWritable];

        for (int i = 0; i < cnt; ++i) {
            _histogram[rgba_u8[i * 4]] += 1;
        }

        [_work.plane unlockWritable];

        unsigned long sum = 0;

        for (int i = 0; i < 256; ++i) {
            sum += _histogram[i];
            _cdf[i] = sum;
        }

        int min_luminance = 0;
        int max_luminance = 255;

        for (int i = 0; i < 256; ++i) {
            if (_histogram[i] > 0) {
                min_luminance = i;
                break;
            }
        }

        for (int i = 255; i >= 0; --i) {
            if (_histogram[i] > 0) {
                max_luminance = i;
                break;
            }
        }

        _mean_min[_cycles % MEAN_AVERAGE_SIZE] = min_luminance;
        _mean_max[_cycles % MEAN_AVERAGE_SIZE] = max_luminance;

        ++_cycles;

        float min_luminance_float = min_luminance;
        float max_luminance_float = max_luminance;

        if (_cycles > MEAN_AVERAGE_SIZE) {
            float sum_min = 0;
            float sum_max = 0;
            for (int i = 0; i < MEAN_AVERAGE_SIZE; ++i) {
                sum_min += _mean_min[i];
                sum_max += _mean_max[i];
            }

            min_luminance_float = sum_min / (float)MEAN_AVERAGE_SIZE;
            max_luminance_float = sum_max / (float)MEAN_AVERAGE_SIZE;
        }

        float range = max_luminance_float - min_luminance_float;

        TGL_USE_WRITABLE(_lut.plane, buf)  {
            uint8_t *buf8 = buf;
            for (int i = 0; i < 256; ++i) {
                buf8[i] = MIN(max_luminance_float, floor((_cdf[i] / (float)sum) * range + min_luminance_float));
            }
        };
    }

    _is_normal = NO;

    return YES;
}

- (void)setNormalLUT
{
    TGL_USE_WRITABLE(_lut.plane, buf)  {
        uint8_t *buf8 = buf;
        for (int i = 0; i < 256; ++i) {
            buf8[i] = i;
        }
    };

    _is_normal = YES;
}

@end
