//
//  ControlMessage.h
//  ReverseStreamer
//
//  Created by Yukishita Yohsuke on 2014/06/09.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "SWSMessage.h"
#import "SWSServerSettingMaster.h"

#define MESSAGE_CATEGORY_SWS_CTRL (0x01)

@protocol SWSOnReadControlMessageDelegate<SWSOnReadMessageDelegate>

@required
- (BOOL)onHello;
- (BOOL)onPassword:(NSString *)password;
- (BOOL)onWaitingInput;
@end


@interface SWSControlMessage : SWSMessage<SWSMessageParserDelegate>

typedef NS_ENUM(NSUInteger, SWSControlPacketType) {
    SWS_CTRL_BIL_HELLO = 0x10,
    SWS_CTRL_S2C_PASSWORD_REQUIRED = 0x11,
    SWS_CTRL_C2S_PASSWORD = 0x12,
    SWS_CTRL_C2S_WAITING_INPUT = 0x13,
    SWS_CTRL_S2C_WAITING_INPUT = 0x14,
    SWS_CTRL_S2C_RESET = 0xFF,
};

#define SWS_PASSWORD_SEED_CHAR_LEN (32)
+ (NSUInteger)_category;
+ (NSDictionary *)specification_dic;
+ (instancetype)createWithType:(NSUInteger)type withPayload:(NSData *)payload;
+ (instancetype)createHello;
+ (instancetype)createPasswordRequired:(NSString *)seed;
+ (instancetype)createWaitingInput;
+ (instancetype)createReset;
+ (NSString *)password_bridge_str;

+ (BOOL)parsePassword:(NSData *)payload  for:(id<SWSOnReadControlMessageDelegate>)delegate;
@end

