//
//  SettingTVC.h
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/29.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SettingTVC : UITableViewController
@property (strong, nonatomic) IBOutlet UITableView *table_view;
@property (weak, nonatomic) IBOutlet UISlider *quality_slider;
@property (weak, nonatomic) IBOutlet UILabel *quality_label;
@property (weak, nonatomic) IBOutlet UISlider *framerate_slider;
@property (weak, nonatomic) IBOutlet UILabel *framerate_label;
@property (weak, nonatomic) IBOutlet UITextField *password_text;
@property (weak, nonatomic) IBOutlet UIButton *setting_reset_button;
@property (weak, nonatomic) IBOutlet UISwitch *internet_url_switch;
@property (weak, nonatomic) IBOutlet UIButton *share_button;
@property (weak, nonatomic) IBOutlet UISwitch *enable_audio_switch;

@property (weak, nonatomic) IBOutlet UISegmentedControl *url_type_switch;

@end
