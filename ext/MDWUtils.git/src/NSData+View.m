//
//  NSData+View.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/04.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "NSData+View.h"

@implementation NSData (View)

- (uint32_t)uint32At:(NSUInteger)byte_offset
{
    ASSERT(byte_offset <= self.length - sizeof(uint32_t), return 0);

    const uint8_t *buf8 = self.bytes;
    const uint8_t *p = &buf8[byte_offset];

    return (p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3];
}

- (uint32_t)uint24At:(NSUInteger)byte_offset
{
    ASSERT(byte_offset <= self.length - sizeof(uint8_t) * 3, return 0);

    const uint8_t *buf8 = self.bytes;
    const uint8_t *p = &buf8[byte_offset];

    return (p[0] << 16) | (p[1] << 8) | p[2];
}

- (uint16_t)uint16At:(NSUInteger)byte_offset
{
    ASSERT(byte_offset <= self.length - sizeof(uint16_t), return 0);

    const uint8_t *buf8 = self.bytes;
    const uint8_t *p = &buf8[byte_offset];

    return (p[0] << 8) | p[1];
}

- (uint8_t)uint8At:(NSUInteger)byte_offset
{
    ASSERT(byte_offset <= self.length - sizeof(uint8_t), return 0);

    const uint8_t *buf8 = self.bytes;

    return buf8[byte_offset];
}
@end
