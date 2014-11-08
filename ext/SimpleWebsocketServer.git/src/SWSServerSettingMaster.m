//
//  SettingMaster.m
//  ReverseStreamer
//
//  Created by Yukishita Yohsuke on 2014/06/09.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <MDWUtils/NSObject+SimpleArchiver.h>
#import <MDWUtils/NSString+Crypto.h>

#import "SWSServerSettingMaster.h"

@interface SWSServerSetting()
@property (atomic, readwrite) NSString *password_sha1;
@end

@implementation SWSServerSetting

- (id)copyWithZone:(NSZone *)zone
{
    SWSServerSetting *copied = [[self class] new];

    copied.password_sha1 = _password_sha1;

    return copied;
}
@end

@interface SWSServerSettingMaster() {
    SWSServerSetting *_default_setting;
}
@end

@implementation SWSServerSettingMaster

+ (instancetype)sharedMaster
{
    static SWSServerSettingMaster *__instance;
    static dispatch_once_t __once_token;

    dispatch_once(&__once_token, ^{
        __instance = [[[self class] alloc] init];
        [__instance _setup];
    });

    return __instance;
}

- (BOOL)_setup
{
    _default_setting = [self _makeDefaultSetting];

    return YES;
}

- (SWSServerSetting *)_makeDefaultSetting
{
    SWSServerSetting *default_setting = [SWSServerSetting new];

    // set set set..

    return default_setting;
}

- (NSString *)_genArchiveKey
{
    return @"user_setting_sws_server"; // TODO: generate archive key from the property list
}


#pragma mark -
#pragma mark Setting change without side effect
- (SWSServerSetting *)changePasswordByPlain:(NSString *)plain_str of:(SWSServerSetting *)setting
{
    SWSServerSetting *new_setting = [setting copy];

    if (plain_str.length == 0) {
        new_setting.password_sha1 = @"";
    } else {
        new_setting.password_sha1 = [plain_str sha1String];
    }

    return new_setting;
}

#pragma mark -
#pragma mark Persistency
- (BOOL)save:(SWSServerSetting *)to_save
{
    return [to_save simpleArchiveForKey:[self _genArchiveKey]];
}

- (SWSServerSetting *)_load
{
    return [SWSServerSetting simpleUnarchiveForKey:[self _genArchiveKey]];
}

- (SWSServerSetting *)loadOrDefault
{
    SWSServerSetting *ret = [self _load];

    if (!ret) {
        ret = self.default_setting;
    }

    return ret;
}
@end
