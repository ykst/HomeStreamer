//
//  ControlMessage.m
//  ReverseStreamer
//
//  Created by Yukishita Yohsuke on 2014/06/09.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#include <objc/message.h>
#include <CommonCrypto/CommonCrypto.h>
#import <MDWUtils/NSString+Randomize.h>
#import <MDWUtils/NSData+View.h>
#import "SWSControlMessage.h"

@implementation SWSControlMessage
// FIXME: delegate to service layer
+ (NSDictionary *)specification_dic
{
    return @{
         @"MESSAGE_CATEGORY_SWS_CTRL":@(MESSAGE_CATEGORY_SWS_CTRL),
         @"SWS_PASSWORD_BRIDGE_STR":[[self class] password_bridge_str],
         @"SWS_CTRL_BIL_HELLO":@(SWS_CTRL_BIL_HELLO),
         @"SWS_CTRL_S2C_PASSWORD_REQUIRED":@(SWS_CTRL_S2C_PASSWORD_REQUIRED),
         @"SWS_CTRL_C2S_PASSWORD":@(SWS_CTRL_C2S_PASSWORD),
         @"SWS_CTRL_C2S_WAITING_INPUT":@(SWS_CTRL_C2S_WAITING_INPUT),
         @"SWS_CTRL_S2C_WAITING_INPUT":@(SWS_CTRL_S2C_WAITING_INPUT),
         @"SWS_CTRL_S2C_RESET":@(SWS_CTRL_S2C_RESET)
    };
}

+ (NSString *)password_bridge_str
{
    static NSString *ret;
    static dispatch_once_t __once_token;
    dispatch_once(&__once_token, ^{
        ret = [NSString stringWithRandomAlphanum:32];
    });
    return ret;
}

+ (instancetype)createWithType:(NSUInteger)type withPayload:(NSData *)payload
{
    return [[self class] createWithCategory:MESSAGE_CATEGORY_SWS_CTRL withType:type withPayload:payload];
}

+ (NSUInteger)_category
{
    return MESSAGE_CATEGORY_SWS_CTRL;
}

#pragma mark -
#pragma mark Message Factory

+ (instancetype)createHello
{
    return [[self class] createWithType:SWS_CTRL_BIL_HELLO withPayload:nil];
}

+ (instancetype)createPasswordRequired:(NSString *)seed
{
    ASSERT(seed.length == SWS_PASSWORD_SEED_CHAR_LEN, return nil);

    NSData *payload = [NSData dataWithBytes:[seed UTF8String] length:seed.length];

    return [[self class] createWithType:SWS_CTRL_S2C_PASSWORD_REQUIRED withPayload:payload];
}

+ (instancetype)createWaitingInput
{
    return [[self class] createWithType:SWS_CTRL_S2C_WAITING_INPUT withPayload:nil];
}

+ (instancetype)createReset
{
    return [[self class] createWithType:SWS_CTRL_S2C_RESET withPayload:nil];
}

+ (BOOL)parsePassword:(NSData *)payload for:(id<SWSOnReadControlMessageDelegate>)delegate
{
    NSASSERT([delegate respondsToSelector:@selector(onPassword:)]);

    EXPECT(payload.length == CC_SHA1_DIGEST_LENGTH, return NO);

    NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];

    const uint8_t *digest = payload.bytes;

    for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];

    EXPECT([delegate onPassword:output], return NO);

    return YES;
}

#pragma mark -
#pragma mark Message Parse Action Delegate
+ (BOOL)message:(SWSMessage *)message parseForDelegate:(id<SWSOnReadControlMessageDelegate>)delegate
{
    switch (message.type) {
        case SWS_CTRL_BIL_HELLO:
            NSASSERT([delegate respondsToSelector:@selector(onHello)]);
            EXPECT([[self class] parseNoParam:@selector(onHello) for:delegate], return NO);
            break;
        case SWS_CTRL_C2S_PASSWORD:
            EXPECT([[self class] parsePassword:message.payload for:delegate], return NO);
            break;
        case SWS_CTRL_C2S_WAITING_INPUT:
            NSASSERT([delegate respondsToSelector:@selector(onWaitingInput)]);
            EXPECT([[self class] parseNoParam:@selector(onWaitingInput) for:delegate], return NO);
            break;
        default:
            return NO;
    }

    return YES;
}
@end
