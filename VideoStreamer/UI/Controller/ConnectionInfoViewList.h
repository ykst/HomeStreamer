//
//  ConnectionInfoList.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/04/02.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ConnectionInfo.h"

@interface ConnectionInfoViewList : NSObject

+ (instancetype)createOnAnchor:(UIView *)anchor;

- (void)updateInfos:(NSArray *)infos; // [(ConnectionInfo *)]
- (void)setVisible:(BOOL)visible;
@end
