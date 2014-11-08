//
//  NSData+View.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/04.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (View)

- (uint32_t)uint32At:(NSUInteger)byte_offset;
- (uint32_t)uint24At:(NSUInteger)byte_offset;
- (uint16_t)uint16At:(NSUInteger)byte_offset;
- (uint8_t)uint8At:(NSUInteger)byte_offset;

@end
