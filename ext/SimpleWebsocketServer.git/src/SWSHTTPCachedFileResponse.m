//
//  HTTPCachedFileResponse.m
//  ReverseStreamer
//
//  Created by Yukishita Yohsuke on 2014/06/08.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "SWSHTTPCachedFileResponse.h"

@implementation SWSHTTPCachedFileResponse
- (NSDictionary *)httpHeaders
{
    // virtually infinite cache
    return @{@"Cache-Control":@"max-age=31536000, public"};
}
@end
