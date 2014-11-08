//
//  VSVideoCapture.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/06.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <MobileAL/MALTimeStampFreightProtocol.h>
#import "VSVideoCapture.h"

@interface VSVideoCapture()

@end

@implementation VSVideoCapture

- (void)appendMetaInfo:(MCVBufferFreight<MALTimeStampFreightProtocol> *)freight
{
    NSASSERT([freight respondsToSelector:@selector(setTimestamp:)]);

    struct timeval tv;
    gettimeofday(&tv, NULL);
    [freight setTimestamp:tv];

    if ([_delegate respondsToSelector:@selector(onCapture:)]) {
        [_delegate onCapture:freight];
    }
}
@end
