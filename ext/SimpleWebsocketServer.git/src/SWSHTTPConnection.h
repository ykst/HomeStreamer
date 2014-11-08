//
//  MainHTTPConnection.h
//  ReverseStreamer
//
//  Created by Yukishita Yohsuke on 2014/06/08.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CocoaHTTPServer/HTTPConnection.h>

@interface SWSHTTPConnection : HTTPConnection

- (NSDictionary *)setupReplacementWordDictioary; // override this
- (NSSet *)setupReplacementFileSet; // override this
@end
