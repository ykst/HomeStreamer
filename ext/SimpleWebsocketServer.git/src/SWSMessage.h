//
//  Message.h
//  ReverseStreamer
//
//  Created by Yukishita Yohsuke on 2014/06/09.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>

#include <sys/time.h>

#define MESSAGE_VERSION (0x0101)

// Heads up! Category 0x00 ~ 0x0F is reserved for SWS libary.
typedef NSUInteger MessageCategory;

#define MESSAGE_CATEGORY_SWS_BULK (0x00)

@protocol SWSOnReadMessageDelegate<NSObject>
@required
@end

@class SWSMessage;
@protocol SWSMessageParserDelegate
@required
+ (BOOL)message:(SWSMessage *)message parseForDelegate:(id<SWSOnReadMessageDelegate>)delegate;
@end

@interface SWSMessage : NSObject {
    MessageCategory _category;
    NSUInteger _type;
    struct timeval _timestamp;
    NSData *_payload;
    NSMutableData *_data;
}

@property (nonatomic, readonly) NSData *data;
@property (nonatomic, readonly) MessageCategory category;
@property (nonatomic, readonly) NSUInteger type;
@property (nonatomic, readonly) struct timeval timestamp;
@property (nonatomic, readonly) NSData *payload;

+ (const uint8_t *)getMagic;
+ (NSDictionary *)specification_dic; // TODO: too specific to be here

+ (instancetype)createWithCategory:(MessageCategory)category
                          withType:(NSUInteger)type
                       withPayload:(NSData *)payload;

+ (instancetype)createWithCategory:(MessageCategory)category
                          withType:(NSUInteger)type
                       withPayload:(NSData *)payload
                     withTimeStamp:(struct timeval)timestamp;

+ (instancetype)createWithCategory:(MessageCategory)category
                          withType:(NSUInteger)type
                  withMultiPayload:(NSArray *)payloads
                     withTimeStamp:(struct timeval)timestamp;

+ (instancetype)createMultipartWithCategory:(MessageCategory)category
                                   withType:(NSUInteger)type
                          withFirstPayloads:(NSArray *)payloads
                              withTimeStamp:(struct timeval)timestamp
                    withSecondPayloadLength:(uint32_t)second_length;

+ (instancetype)createFromData:(NSData *)data;

// limitation: each message's length should be less than 64KB, and the number of messages should be less than 256.
// + (instancetype)createBulk:(NSArray *)messages;
// Must override this
+ (NSUInteger)category;

+ (BOOL)parseU8:(NSData *)payload on:(SEL)selector for:(id<SWSOnReadMessageDelegate>)delegate;
+ (BOOL)parseU16:(NSData *)payload on:(SEL)selector for:(id<SWSOnReadMessageDelegate>)delegate;
+ (BOOL)parseU32:(NSData *)payload on:(SEL)selector for:(id<SWSOnReadMessageDelegate>)delegate;
+ (BOOL)parseNoParam:(SEL)selector for:(id<SWSOnReadMessageDelegate>)delegate;

+ (NSData *)makePayloadU8:(uint8_t)dat;
+ (NSData *)makePayloadU16:(uint16_t)dat;
+ (NSData *)makePayloadU32:(uint32_t)dat;

@end




