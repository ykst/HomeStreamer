//
//  SettingMaster.h
//  ReverseStreamer
//
//  Created by Yukishita Yohsuke on 2014/06/09.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SWSServerSetting : NSObject<NSCopying>
@property (atomic, readonly) NSString *password_sha1;
@end

@interface SWSServerSettingMaster : NSObject
@property (nonatomic, readonly) SWSServerSetting *default_setting;

+ (instancetype)sharedMaster;

#pragma mark -
#pragma mark Setting change
- (SWSServerSetting *)changePasswordByPlain:(NSString *)plain_str of:(SWSServerSetting *)setting;

#pragma mark -
#pragma mark Persisitency
- (SWSServerSetting *)loadOrDefault;
- (BOOL)save:(SWSServerSetting *)to_save;

@end
