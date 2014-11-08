//
//  NSData+Digest.h
//  ProcStat
//
//  Created by Yukishita Yohsuke on 2013/11/06.
//  Copyright (c) 2013年 snowlabo. All rights reserved.
//
// Acknowledgement: http://blog.heartofsword.net/archives/542

#import <Foundation/Foundation.h>

@interface NSData(Digest)
+ (NSData *) utf8Data: (NSString *) string;
- (NSData *) sha1Digest;
- (NSData *) md5Digest;
- (NSString *) hexString;
- (NSString *) sha1String;
@end
