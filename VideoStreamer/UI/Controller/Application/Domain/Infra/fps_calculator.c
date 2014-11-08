//
//  fps_calculator.c
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/06/03.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#include <stdlib.h>
#include <string.h>

#include "fps_calculator.h"

void fps_calculator_init(struct fps_calculator_state *h)
{
    memset(h, 0x00, sizeof(*h));
    h->last_update_mach_time = mach_absolute_time();
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    h->sum_ticks_denom = ((double)timebase.denom / (double)timebase.numer) * 1e9 * (double)FPS_SMA_TABLE_SIZE;
}

void fps_calculator_update(struct fps_calculator_state *h)
{
    h->sum_ticks -= h->tick_table[h->table_idx];

    uint64_t current_mach_time = mach_absolute_time();
    uint64_t current_tick = current_mach_time - h->last_update_mach_time;

    h->last_update_mach_time = current_mach_time;
    h->sum_ticks += current_tick;
    h->tick_table[h->table_idx] = current_tick;
    h->table_idx += 1;

    if (h->table_idx >= FPS_SMA_TABLE_SIZE) {
        h->table_idx = 0;
    }

    h->fps = h->sum_ticks_denom / (double)h->sum_ticks;
}