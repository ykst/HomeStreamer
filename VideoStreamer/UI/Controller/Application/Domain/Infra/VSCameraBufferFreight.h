//
//  VSCameraBufferFreight.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/06.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <MobileAL/MALTimeStampFreightProtocol.h>
#import <MobileCV/MCVCameraBufferFreight.h>


@interface VSCameraBufferFreight : MCVCameraBufferFreight<MALTimeStampFreightProtocol> {
    @protected
    struct timeval _timestamp;
}

@end
