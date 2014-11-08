//
//  NSObject+SimpleArchiver.m
//  ProcStat
//
//  Created by Yukishita Yohsuke on 2013/11/06.
//  Copyright (c) 2013年 snowlabo. All rights reserved.
//

#import "NSData+Digest.h"
#import "NSObject+SimpleArchiver.h"
#import <objc/runtime.h>

@implementation NSObject(SimpleArchiver)

+ (NSString *)_makeArchivePath:(Class)cls forKey:(NSString *)key
{
    NSString *plain = NSPRINTF(@"_#SA_%@_%@", NSStringFromClass(cls), key);
    NSString *hashed = [[plain dataUsingEncoding:NSUTF8StringEncoding] sha1String];
    NSArray *document_paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                        NSUserDomainMask, YES);
    NSString *documents_path = [document_paths objectAtIndex:0];
    NSString *path = NSPRINTF(@"%@/%@", documents_path, hashed);

    return path;
}

- (BOOL)simpleArchiveForKey:(NSString *)key
{
    NSString *archive_key = [NSObject _makeArchivePath:[self class] forKey:key];

    unsigned count;
    objc_property_t *properties = class_copyPropertyList([self class], &count);

    if (count == 0) {
        FREE(properties);
        return NO;
    }

    NSMutableArray *keys = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count; ++i) {
        objc_property_t property = properties[i];
        keys[i] = [NSString stringWithUTF8String:property_getName(property)];
    }

    FREE(properties);

    NSDictionary *dict = [self dictionaryWithValuesForKeys:keys];

    BOOL ret = [NSKeyedArchiver archiveRootObject:dict toFile:archive_key];
    
    return ret;
}

+ (id)simpleUnarchiveForKey:(NSString *)key
{
    NSString *archive_key = [NSObject _makeArchivePath:[self class] forKey:key];

    NSDictionary *dict = [NSKeyedUnarchiver unarchiveObjectWithFile:archive_key];

    if (!dict) return nil;

    NSObject *obj = [[self class] new];

    // Check existence of keys to avoid fatal crash
    for (NSString *key in dict) {
        if (![key isKindOfClass:[NSString class]] ||
            key.length < 1) {
            WARN(@"Failed to unarchive: invalid archive key");
            return nil;
        }

        if ([obj respondsToSelector:NSSelectorFromString(key)] == NO) {
            WARN(@"Failed to unarchive: selector does not exists: %@", key);
            return nil;
        }
    }

    [obj setValuesForKeysWithDictionary:dict];
    
    return obj;
}
@end
