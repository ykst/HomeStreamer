//
//  PerformanceStatistics.m
//  ReverseStreamer
//
//  Created by Yukishita Yohsuke on 2014/06/09.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#include <mach/mach_time.h>

#import "SWSPerformanceStatistics.h"

struct record_spec {
    uint64_t tick; // mach_absolute_time()
    uint64_t bytes;
};

static uint64_t __ticks_for_second = 0;
static mach_timebase_info_data_t __mach_timebase = {};

#define RECORD_LENGTH 64

@interface SWSPerformanceStatistics() {
    struct record_spec _output_network_records[RECORD_LENGTH];
    int _output_network_record_idx;

    struct record_spec _input_network_records[RECORD_LENGTH];
    int _input_network_record_idx;
}

@end

@implementation SWSPerformanceStatistics

+ (instancetype)sharedManager
{
    static SWSPerformanceStatistics *__instance;
    static dispatch_once_t __once_token;
    dispatch_once(&__once_token, ^{
        __instance = [[[self class] alloc] init];
        [__instance _setup];
    });
    return __instance;
}

+ (instancetype)create
{
    SWSPerformanceStatistics *obj = [[[self class] alloc] init];

    ASSERT([obj _setup], return nil);

    return obj;
}

#define CLEAR_RECORD(array) memset(array, 0x00, sizeof(array[0]) * RECORD_LENGTH);
- (BOOL)_setup
{
    _output_network_record_idx = 0;
    _output_network_record_idx = 0;

    CLEAR_RECORD(_output_network_records);
    CLEAR_RECORD(_input_network_records);

    mach_timebase_info(&__mach_timebase);

    __ticks_for_second = ((double)__mach_timebase.denom / (double)__mach_timebase.numer) * 1e9;

    return YES;
}

static inline void __set_record(struct record_spec *records, uint64_t value, int *p_idx)
{
    struct record_spec *p_record = &records[*p_idx];

    p_record->bytes = value;
    p_record->tick = mach_absolute_time();

    *p_idx = (*p_idx >= RECORD_LENGTH - 1) ? 0 : (*p_idx + 1);
}

- (void)increaseInputNetworkBytes:(NSUInteger)num_bytes
{
    @synchronized(self) {
        __set_record(_input_network_records, num_bytes, &_input_network_record_idx);
    }
}

- (void)increaseOutputNetworkBytes:(NSUInteger)num_bytes
{
    @synchronized(self) {
        __set_record(_output_network_records, num_bytes, &_output_network_record_idx);
    }
}

static inline double __calc_bytes_per_sec(struct record_spec *records, uint64_t current_tick)
{
    uint64_t tick_second_ago = current_tick - __ticks_for_second;
    uint64_t accum_bytes = 0;
    uint64_t min_tick = UINT64_MAX;

    for (int i = 0; i < RECORD_LENGTH; ++i) {
        struct record_spec *p_record = &records[i];
        uint64_t tick = p_record->tick;

        if (tick >= tick_second_ago && tick <= current_tick) {
            accum_bytes += p_record->bytes;
            min_tick = MIN(min_tick, tick);
        } else if (tick < tick_second_ago) {
            min_tick = tick_second_ago;
        }
    }

    if (accum_bytes == 0) return 0.0f;

    return (double)accum_bytes / (double)((current_tick - min_tick) / ((double)__ticks_for_second));
}

- (double)calcCurrentOutputBytesPerSeconds
{
    uint64_t current_tick = mach_absolute_time();

    double ret;

    @synchronized(self) {
        ret = __calc_bytes_per_sec(_output_network_records, current_tick);
    }

    return ret;
}

- (double)calcCurrentInputBytesPerSeconds
{
    uint64_t current_tick = mach_absolute_time();

    double ret;

    @synchronized(self) {
        ret = __calc_bytes_per_sec(_input_network_records, current_tick);
    }
    
    return ret;
}

@end
