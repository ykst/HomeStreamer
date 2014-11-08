//
//  fps_calculator.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/06/03.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#ifndef VideoStreamer_fps_calculator_h
#define VideoStreamer_fps_calculator_h

#include <mach/mach_time.h>

#define FPS_SMA_TABLE_SIZE (60)
struct fps_calculator_state {
    double sum_ticks_denom;
    uint64_t last_update_mach_time;
    uint64_t sum_ticks;
    uint64_t tick_table[FPS_SMA_TABLE_SIZE];
    int table_idx;
    float fps;
};

void fps_calculator_init(struct fps_calculator_state *h);
void fps_calculator_update(struct fps_calculator_state *h);
#endif
