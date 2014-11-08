//
//  MainVC.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/02/28.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <GLKit/GLKit.h>
#import "VSMainDisplayV.h"
#import "Application/MainPipeline.h"

@interface MainVC : GLKViewController<MainPipelineStateDelegate>

@property (strong, nonatomic) IBOutlet VSMainDisplayV *main_display;
@property (strong, nonatomic) IBOutlet GLKView *underlying_view;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *camera_change_button;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *setting_button;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *leftmost_toolber_margin;
@property (weak, nonatomic) IBOutlet UIView *connection_info_base_anchor;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *info_button;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *screen_light_button;

@end
