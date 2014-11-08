//
//  NSData+Digest.m
//  ProcStat
//
//  Created by Yukishita Yohsuke on 2013/11/06.
//  Copyright (c) 2013年 snowlabo. All rights reserved.
//

#import "NSData+Digest.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSData(Digest)
+ (NSData *) utf8Data: (NSString *) string
{
    const char* utf8str = [string UTF8String];
    NSData* data = [NSData dataWithBytes: utf8str length: strlen(utf8str)];
    return data;
}

- (NSData *) sha1Digest
{
    unsigned char result[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1([self bytes], (unsigned)[self length], result);
    return [NSData dataWithBytes:result length:CC_SHA1_DIGEST_LENGTH];
}

- (NSData *) md5Digest
{
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5([self bytes], (unsigned)[self length], result);
    return [NSData dataWithBytes:result length:CC_MD5_DIGEST_LENGTH];
}

- (NSString *) sha1String
{
    return [[self sha1Digest] hexString];
}

- (NSString *)hexString
{
    unsigned int i;
    static const char *hexstr[16] = { "0", "1", "2", "3",
        "4", "5", "6", "7",
        "8", "9", "a", "b",
        "c", "d", "e", "f" };
    const char *dataBuffer = (char *)[self bytes];
    NSMutableString *stringBuffer = [NSMutableString stringWithCapacity:([self length] * 2)];
    for (i=0; i<[self length]; i++) {
        uint8_t t1, t2;
        t1 = (0x00f0 & (dataBuffer[i])) >> 4;
        t2 =  0x000f & (dataBuffer[i]);
        [stringBuffer appendFormat:@"%s", hexstr[t1]];
        [stringBuffer appendFormat:@"%s", hexstr[t2]];
    }

    return stringBuffer;
}
@end