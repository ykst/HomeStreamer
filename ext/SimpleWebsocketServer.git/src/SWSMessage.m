//
//  Message.m
//  ReverseStreamer
//
//  Created by Yukishita Yohsuke on 2014/06/09.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#include <objc/message.h>
#import "SWSMessage.h"
#import "NSData+View.h"

#define MESSAGE_MAGIC_BYTES_LENGTH (4)
#define MESSAGE_HEADER_LENGTH (MESSAGE_MAGIC_BYTES_LENGTH + 16)

@implementation SWSMessage

+ (const uint8_t *)getMagic
{
    // TODO: 別にuint32_tでもいいかなって
    static uint8_t __magic[MESSAGE_MAGIC_BYTES_LENGTH];
    static dispatch_once_t __once_token;
    dispatch_once(&__once_token, ^{
        for (int i = 0; i < MESSAGE_MAGIC_BYTES_LENGTH; ++i) {
#if DEBUG
            __magic[i] = 0xFF;
#else
            __magic[i] = arc4random(); // __get_random_alpha_numeric();
#endif
        }

        // __magic[MESSAGE_MAGIC_BYTES_LENGTH] = '\0';
    });

    return __magic;
}

+ (NSDictionary *)specification_dic
{
    const uint8_t *magic = [SWSMessage getMagic];

    return @{@"MESSAGE_MAGIC_BYTES_1":@(magic[0]),
             @"MESSAGE_MAGIC_BYTES_2":@(magic[1]),
             @"MESSAGE_MAGIC_BYTES_3":@(magic[2]),
             @"MESSAGE_MAGIC_BYTES_4":@(magic[3]),
             @"MESSAGE_VERSION":@(MESSAGE_VERSION),
             @"MESSAGE_HEADER_LENGTH":@(MESSAGE_HEADER_LENGTH),
             };
}

+ (instancetype)createWithCategory:(MessageCategory)category
                          withType:(NSUInteger)type
                       withPayload:(NSData *)payload
{
    struct timeval timestamp;
    gettimeofday(&timestamp, NULL);

    NSArray *payloads = (payload == nil) ? @[] : @[payload];

    return [[self class] createWithCategory:category
                                   withType:type
                           withMultiPayload:payloads
                              withTimeStamp:timestamp];
}

+ (instancetype)createWithCategory:(MessageCategory)category
                          withType:(NSUInteger)type
                       withPayload:(NSData *)payload
                     withTimeStamp:(struct timeval)timestamp
{
    NSArray *payloads = (payload == nil) ? @[] : @[payload];

    return [[self class] createWithCategory:category
                                   withType:type
                           withMultiPayload:payloads
                              withTimeStamp:timestamp];
}

+ (instancetype)createWithCategory:(MessageCategory)category
                          withType:(NSUInteger)type
                  withMultiPayload:(NSArray *)payloads
                     withTimeStamp:(struct timeval)timestamp
{
    SWSMessage *obj = [[[self class] alloc] init];

    [obj _setupDataWithHeader:category withType:type withTimeStamp:timestamp withPayloads:payloads];

    return obj;
}

+ (instancetype)createMultipartWithCategory:(MessageCategory)category
                                   withType:(NSUInteger)type
                          withFirstPayloads:(NSArray *)payloads
                              withTimeStamp:(struct timeval)timestamp
                    withSecondPayloadLength:(uint32_t)second_length
{
    SWSMessage *obj = [[[self class] alloc] init];

    [obj _setupDataWithHeader:category withType:type withTimeStamp:timestamp withPayloads:payloads withExtraLength:second_length];

    return obj;
}

/* future work
+ (instancetype)createBulk:(NSArray *)messages
{
    int total_length = 0;

    ASSERT(messages.count > 0 && messages.count < 256, return nil);

    for (SWSMessage *message in messages) {
        NSASSERT([message isKindOfClass:[SWSMessage class]]);
        int length = message.data.length;
        ASSERT(length < 0x10000, return nil);

        total_length += message.data.length;
    }

    ASSERT(total_length > 0, return nil);

    uint8_t *buf = malloc(total_length + messages.count * 2);

    ASSERT(buf != NULL, return nil);

    int byte_offset = 0;


    for (SWSMessage *message in messages) {
        NSASSERT([message isKindOfClass:[SWSMessage class]]);
        memcpy(&buf[byte_offset], )
    }
}
 */

+ (NSUInteger)category
{
    NSASSERT(!"must be overriden");
    
    return 0;
}

- (void)_setupDataWithHeader:(MessageCategory)category
                    withType:(NSUInteger)type
               withTimeStamp:(struct timeval)timestamp
                withPayloads:(NSArray *)payloads
{
    [self _setupDataWithHeader:category withType:type withTimeStamp:timestamp withPayloads:payloads withExtraLength:0];
}

- (void)_setupDataWithHeader:(MessageCategory)category
                    withType:(NSUInteger)type
               withTimeStamp:(struct timeval)timestamp
                withPayloads:(NSArray *)payloads
             withExtraLength:(uint32_t)extra_length
{
    uint32_t payload_length = 0;

    for (NSData *payload in payloads) {
        payload_length += payload.length;
    }

    _data = [NSMutableData dataWithLength:(MESSAGE_HEADER_LENGTH + payload_length)];

    const uint8_t *magic_bytes = [SWSMessage getMagic];
    const uint32_t total_length = MESSAGE_HEADER_LENGTH + payload_length + extra_length;

    // FIXME: old-fashion bullshit
    uint8_t header[MESSAGE_HEADER_LENGTH] = {
        // u8[4] Magic bytes
        magic_bytes[0],
        magic_bytes[1],
        magic_bytes[2],
        magic_bytes[3],
        (total_length >> 24) & 0xFF,
        (total_length >> 16) & 0xFF,
        (total_length >> 8) & 0xFF,
        (total_length) & 0xFF,
        // u16 version,
        (MESSAGE_VERSION >> 8) & 0xFF,
        (MESSAGE_VERSION) & 0xFF,
        // u8 Payload category
        category & 0xFF,
        // u8 Payload type
        type & 0xFF,
        // u32 Server time second
        (timestamp.tv_sec >> 24) & 0xFF,
        (timestamp.tv_sec >> 16) & 0xFF,
        (timestamp.tv_sec >> 8) & 0xFF,
        (timestamp.tv_sec) & 0xFF,
        // u32 Server time microsecond
        (timestamp.tv_usec >> 24) & 0xFF,
        (timestamp.tv_usec >> 16) & 0xFF,
        (timestamp.tv_usec >> 8) & 0xFF,
        (timestamp.tv_usec) & 0xFF,
    };

    [_data replaceBytesInRange:NSMakeRange(0, MESSAGE_HEADER_LENGTH) withBytes:header length:MESSAGE_HEADER_LENGTH];

    _timestamp = timestamp;
    _category = category;
    _type = type;

    [self _setupPayloads:payloads];
}

- (void)_setupPayloads:(NSArray *)payloads
{
    if (payloads != nil) {
        NSUInteger payload_offset = MESSAGE_HEADER_LENGTH;

        for (NSData *payload in payloads) {
            NSUInteger payload_length = payload.length;

            [_data replaceBytesInRange:NSMakeRange(payload_offset, payload_length) withBytes:payload.bytes length:payload_length];

            payload_offset += payload_length;
        }

        _payload = [NSData dataWithBytesNoCopy:(void *)&(_data.bytes[MESSAGE_HEADER_LENGTH]) length:(payload_offset - MESSAGE_HEADER_LENGTH) freeWhenDone:NO];
    } else {
        _payload = nil;
    }
}

static inline BOOL __validate_header(NSData *data)
{
    const uint8_t *magic_bytes = [SWSMessage getMagic];

    const uint8_t *buf8 = data.bytes;

    // magic
    for (int i = 0; i < MESSAGE_MAGIC_BYTES_LENGTH; ++i) {
        EXPECT(buf8[i] == magic_bytes[i], return NO);
    }

    // length
    EXPECT(data.length == [data uint32At:4], return NO);

    // version
    EXPECT(buf8[8] == ((MESSAGE_VERSION >> 8) & 0xFF), return NO);
    EXPECT(buf8[9] == ((MESSAGE_VERSION >> 0) & 0xFF), return NO);

    // category
    return YES;
}

+ (instancetype)createFromData:(NSData *)data
{
    EXPECT(data.length >= MESSAGE_HEADER_LENGTH, return nil);
    EXPECT(__validate_header(data), return nil);

    SWSMessage *obj = [[[self class] alloc] init];

    ASSERT([obj _setupFromData:data], return nil);

    return obj;
}

// FIXME: too many copies ('A`)
- (BOOL)_setupFromData:(NSData *)data
{
    _category = [data uint8At:10];
    _type = [data uint8At:11];
    _timestamp.tv_sec = [data uint32At:12];
    _timestamp.tv_usec = [data uint32At:16];
    _data = [data mutableCopy];

    if (data.length > MESSAGE_HEADER_LENGTH) {
        const uint8_t *buf8 = data.bytes;
        // slightly dangerous
        _payload = [NSData dataWithBytes:(void *)(&buf8[MESSAGE_HEADER_LENGTH]) length:(data.length - MESSAGE_HEADER_LENGTH)];
    } else {
        _payload = nil;
    }
    
    return YES;
}

#pragma mark -
#pragma mark Basic Payload Baker
+ (NSData *)makePayloadU8:(uint8_t)dat
{
    uint8_t payload[1] = {
        dat
    };

    return [NSData dataWithBytes:payload length:1];
}

+ (NSData *)makePayloadU16:(uint16_t)dat
{
    uint8_t payload[2] = {
        dat >> 8,
        dat & 0xFF
    };

    return [NSData dataWithBytes:payload length:2];
}

+ (NSData *)makePayloadU32:(uint32_t)dat
{
    uint8_t payload[4] = {
        dat >> 24,
        (dat >> 16) & 0xFF,
        (dat >> 8) & 0xFF,
        dat & 0xFF
    };

    return [NSData dataWithBytes:payload length:4];
}

#pragma mark -
#pragma mark Basic Parser
+ (BOOL)parseU8:(NSData *)payload on:(SEL)selector for:(id<SWSOnReadMessageDelegate>)delegate
{
    NSASSERT([delegate respondsToSelector:selector]);
    EXPECT(payload.length == 1, return NO);

    uint8_t value = [payload uint8At:0];

    EXPECT(objc_msgSend(delegate, selector, value), return NO);

    return YES;
}

+ (BOOL)parseU16:(NSData *)payload on:(SEL)selector for:(id<SWSOnReadMessageDelegate>)delegate
{
    NSASSERT([delegate respondsToSelector:selector]);
    EXPECT(payload.length == 1, return NO);

    uint16_t value = [payload uint16At:0];

    EXPECT(objc_msgSend(delegate, selector, value), return NO);

    return YES;
}

+ (BOOL)parseU32:(NSData *)payload on:(SEL)selector for:(id<SWSOnReadMessageDelegate>)delegate
{
    NSASSERT([delegate respondsToSelector:selector]);
    EXPECT(payload.length == 1, return NO);

    uint32_t value = [payload uint32At:0];

    EXPECT(objc_msgSend(delegate, selector, value), return NO);

    return YES;
}

+ (BOOL)parseNoParam:(SEL)selector for:(id<SWSOnReadMessageDelegate>)delegate
{
    NSASSERT([delegate respondsToSelector:selector]);
    EXPECT([delegate respondsToSelector:selector], return NO);

    objc_msgSend(delegate, selector);

    return YES;
}
@end