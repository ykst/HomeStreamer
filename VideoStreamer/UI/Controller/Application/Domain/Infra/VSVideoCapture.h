//
//  VSVideoCapture.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/06.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "MCVVideoCapture.h"
#import "MCVTimeStampFreightProtocol.h"

@protocol VSVideoCaptureDelegate <NSObject>

- (void)onCapture:(MCVBufferFreight<MALTimeStampFreightProtocol> *)freight;

@end

@interface VSVideoCapture : MCVVideoCapture
@property (nonatomic, readwrite, weak) id<VSVideoCaptureDelegate>delegate;
@end
