//
//  NSObject+SimpleArchiver.h
//  ProcStat
//
//  Created by Yukishita Yohsuke on 2013/11/06.
//  Copyright (c) 2013年 snowlabo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject(SimpleArchiver)

// Save to {HOME}/Document/{SHA1(Salt + Class + key)}
- (BOOL)simpleArchiveForKey:(NSString *)key;
// return nil when nothing is found
+ (id)simpleUnarchiveForKey:(NSString *)key;

@end
