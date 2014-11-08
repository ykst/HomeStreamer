//
//  NSString+Crypto.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/29.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Crypto)
- (NSString *)sha1String;
- (NSString *)md5String;
@end
