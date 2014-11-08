//
//  NoOuterInit.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/05.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>

// XXX: experimantal
@protocol NoOuterInit <NSObject>
@optional
- (id) __unavailable init;
+ (id) __unavailable new;
@end
