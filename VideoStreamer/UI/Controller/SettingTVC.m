//
//  SettingTVC.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/29.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <BlocksKit/BlocksKit+UIKit.h>
#import <SimpleWebsocketServer/SWSServerState.h>
#import <MobileAL/MALRawAudioCapture.h>

#import "Application/Domain/GlobalEvent.h"
#import "SettingTVC.h"
#import "Application/UPnPService.h"

@interface SettingTVC () {
    GlobalEvent *_global_event;
    BOOL _dummy_password_set;
    BOOL _video_on;
    int _upnp_retry_count;
    UIActivityIndicatorView * _upnp_indicator;
    BOOL _show_60fps_notice_dialog;
    UIColor *_default_framelimit_slider_tint;
    CGSize _org_content_size;
}

@end

static BOOL __upnp_enabled_state = NO;
static BOOL __upnp_processing = NO;
static BOOL __upnp_last_switch_state = NO;

@implementation SettingTVC

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self _localizeTableview:_table_view];
    [self _setup];
}

- (void)_setup
{
    _global_event = [GlobalEvent sharedMachine];

    [self _setupPasswordField];
    [self _setupImageQualitySlider];
    [self _setupFramerateLimitSlider];
    [self _setupEnableAudioButton];
    [self _setupResetButton];
    [self _setupUPnPComponents];
    [self _setupMdnsSwitch];
}

- (void)_registerControlEventOnce:(UIControl *)control withBlock:(void (^)(id))block forControlEvents:(UIControlEvents)events
{
    if ([control bk_hasEventHandlersForControlEvents:events]) {
        [control bk_removeEventHandlersForControlEvents:events];
    }
    
    [control bk_addEventHandler:block forControlEvents:events];
}

- (void)_registerValueChangeEventOnce:(UIControl *)control withBlock:(void (^)(id))block
{
    [self _registerControlEventOnce:control withBlock:block forControlEvents:UIControlEventValueChanged];
}

#pragma mark -
#pragma mark PASSWORD

#define DUMMY_PASSWORD_STRING @"********************"

- (void)_setupPasswordField
{
    if ([SWSServerState sharedMachine].current_setting.password_sha1.length > 0) {
        _password_text.text = DUMMY_PASSWORD_STRING;
        _dummy_password_set = YES;
    } else {
        _password_text.text = @"";
        _dummy_password_set = NO;
    }

    _password_text.bk_didBeginEditingBlock = ^(UITextField *field) {
        if (_dummy_password_set) {
            _password_text.text = @"";
            _dummy_password_set = NO;
        }
    };

    _password_text.bk_didEndEditingBlock = ^(UITextField *field) {
        [[SWSServerState sharedMachine] changePassword:field.text];
    };

    _password_text.bk_shouldReturnBlock = ^(UITextField *field) {
        [field resignFirstResponder];
        return YES;
    };
}

#pragma mark -
#pragma mark VIDEO SETTING

- (void)_reflectSliderValue:(float)value forLabel:(UILabel *)label
{
    label.text = NSPRINTF(@"%d", (int)(value * 100.0f + 0.5f));
}

- (void)_setupSlider:(UISlider *)slider withInitialValue:(float)initial_value forLabel:(UILabel *)label withDidChangeBlock:(void (^)(float curved_value))done_block withCurve:(float (^)(float))curve_block
{
    __block uint64_t hold_time = 0;
    __block BOOL holding = NO;
    __block BOOL guarding = NO;
    __block float hold_value = slider.value;

    [self _registerControlEventOnce:slider withBlock:^(UISlider *slider) {
        if (guarding) {
            slider.value = hold_value;
            DBG(@"slow result %.2f", hold_value);

        }
        holding = NO;
        guarding = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            done_block((curve_block != nil) ? curve_block(slider.value) : slider.value);
        });
    } forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside)];


    [self _registerValueChangeEventOnce:slider withBlock:^(UISlider *slider) {
        if (!holding) {
            holding = YES;
            guarding = NO;
            hold_time = mach_absolute_time();
            hold_value = slider.value;
        } else {
            mach_timebase_info_data_t base;
            mach_timebase_info(&base);

            uint64_t const nsec = (mach_absolute_time() - hold_time) * base.numer / base.denom;

            if (guarding) {
                const float delta = slider.value - hold_value;

                if (nsec > 500e6) {
                    // offset the value by 1 unit in the slow mode.
                    hold_value = hold_value + (delta > 0.0f ? 1.0f : (delta < 0.0f ? -1.0f : 0)) * 0.01f;

                    slider.value = hold_value;

                    DBG(@"slow change %.2f", hold_value);

                    hold_time = mach_absolute_time();
                } else {
                    slider.value = hold_value;
                    return;
                }
            } else {
                hold_time = mach_absolute_time();

                // If slider was held for 0.2 sec, slow the further changes in value.
                // Because the user may be trying to adjust exact value at here,
                // and value can be easily changed when the finger was released from the screen.
                // We want to avoid that annoying experience.
                if (nsec > 200e6) {
                    if (!guarding) {
                        hold_value = slider.value;
                        guarding = YES;
                    }
                }
            }
        }

        [self _reflectSliderValue:(curve_block != nil) ? curve_block(slider.value) : slider.value forLabel:label];
    }];

    slider.value = initial_value;

    [self _reflectSliderValue:(curve_block != nil) ? curve_block(slider.value) : slider.value forLabel:label];
}

- (void)_reflectImageQualityValue
{
    [_global_event changeImageQuality:(int)(_quality_slider.value * 100.0f + 0.5f)];
}

- (void)_setupImageQualitySlider
{
    [self _setupSlider:_quality_slider
      withInitialValue:(_global_event.current_streaming_setting.quality / 100.0f)
              forLabel:_quality_label
    withDidChangeBlock:^(float _){
        [self _reflectImageQualityValue];
    } withCurve:nil];
}

- (void)_reflectFramerateLimitValue:(float)value
{
    [_global_event changeFramerateLimit:(int)(value * 100.0f + 0.5f)];
}

- (void)_showHighspeedSettingNoticeDialog
{
    if (!_show_60fps_notice_dialog) return;

    UIAlertView *dialog = [[UIAlertView alloc] bk_initWithTitle:NSLocalizedString(@"Setting Change", nil) message:NSLocalizedString(@"HIGHSPEED_MODE_NOTICE", nil)];

    [dialog bk_addButtonWithTitle:NSLocalizedString(@"Never show this again", nil) handler:^{
        [_global_event neverShow60fpsNotice];
        _show_60fps_notice_dialog = NO;
    }];

    [dialog bk_addButtonWithTitle:NSLocalizedString(@"Dismiss", nil) handler:nil];

    [dialog show];
}

- (void)_enable60fpsMode
{
    ASSERT(!IS_IOS6, return);

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([_global_event set60FpsMode:YES] == YES) {
            [self _showHighspeedSettingNoticeDialog];
            [UIView animateWithDuration:0.5 animations:^{
                _framerate_slider.tintColor = [UIColor redColor];
            }];
        } else {
            DBG(@"Cannot set 60fps mode");
            [_framerate_slider setValue:0.3 animated:YES];
            [self _reflectFramerateLimitValue:0.3];
        };
    });
}

- (void)_disable60fpsMode
{
    ASSERT(!IS_IOS6, return);

    dispatch_async(dispatch_get_main_queue(), ^{
        [_global_event set60FpsMode:NO];
        [UIView animateWithDuration:0.5 animations:^{
            _framerate_slider.tintColor = _default_framelimit_slider_tint;
        }];
    });
}

#define FPS_SLIDER_PIVOT (0.3)
#define FPS_SLIDER_PIVOT_MARGIN (0.05)

- (void)_setupFramerateLimitSlider
{
    BOOL support_60fps = [_global_event support60Fps];

    float min_value = _framerate_slider.minimumValue;
    float max_value = _framerate_slider.maximumValue;

    _show_60fps_notice_dialog = _global_event.current_streaming_setting.show_60fps_notice;

    if (support_60fps) {
        _framerate_slider.maximumValue = 0.6f;
    } else {
        _framerate_slider.maximumValue = 0.3f;
    }

    _framerate_slider.minimumValue = 0.01f;

    if (!IS_IOS6) {
        if (_default_framelimit_slider_tint == nil) {
            _default_framelimit_slider_tint = _framerate_slider.tintColor;
        }

        if (_global_event.current_streaming_setting.framerate_limit > 30) {
            _framerate_slider.tintColor = [UIColor redColor];
        } else {
            _framerate_slider.tintColor = _default_framelimit_slider_tint;
        }
    }

    [self _setupSlider:_framerate_slider
      withInitialValue:(_global_event.current_streaming_setting.framerate_limit / 100.0f)
              forLabel:_framerate_label
    withDidChangeBlock:^(float value){
        int prev_value = _global_event.current_streaming_setting.framerate_limit;
        [self _reflectFramerateLimitValue:value];
        int current_value = _global_event.current_streaming_setting.framerate_limit;

        if (!IS_IOS6) {
            if (prev_value <= 30 && current_value > 30) {
                [self _enable60fpsMode];
            } else if (prev_value > 30 && current_value <= 30) {
                [self _disable60fpsMode];
            }
        }
    } withCurve:^(float org_value) {
        if (!support_60fps) return org_value;

        // Snap to 30fps
        float set_value = org_value;
        const float lower_threshold = FPS_SLIDER_PIVOT - FPS_SLIDER_PIVOT_MARGIN;
        const float higher_threshold = FPS_SLIDER_PIVOT + FPS_SLIDER_PIVOT_MARGIN;

        if (set_value < lower_threshold) {
            set_value = (set_value - min_value) * ((FPS_SLIDER_PIVOT - min_value) / (lower_threshold - min_value)) + min_value;
        } else if (set_value > higher_threshold) {
            set_value = (set_value - higher_threshold) * (max_value - FPS_SLIDER_PIVOT) / (max_value - higher_threshold) + FPS_SLIDER_PIVOT;
        } else {
            set_value = FPS_SLIDER_PIVOT;
        }

        return set_value;
    }];
}

- (void)_setupEnableAudioButton
{
    if ([MALRawAudioCapture microphoneAccessGranted]) {
        _enable_audio_switch.on = _global_event.current_streaming_setting.use_audio ;

        [self _registerValueChangeEventOnce:_enable_audio_switch withBlock:^(UISwitch *sw) {
            if (![MALRawAudioCapture microphoneAccessGranted]) {
                // TODO: say something
                sw.on = NO;
            } else {
                [_global_event changeUseAudio:sw.on];
            }
        }];
    } else {
        _enable_audio_switch.on = NO;
        _enable_audio_switch.userInteractionEnabled = NO;
    }
}

#pragma mark -
#pragma mark INITIALIZE

- (void)_setupResetButton
{
    [_setting_reset_button bk_whenTapped:^{
        UIAlertView *dialog = [[UIAlertView alloc] bk_initWithTitle:NSLocalizedString(@"Confirm", nil) message:NSLocalizedString(@"RESET_SETTING_CONFIRM", nil)];

        [dialog bk_addButtonWithTitle:NSLocalizedString(@"OK", nil) handler:^{
            if (__upnp_enabled_state) {
                [self _cleanupPinhole];
                [self _animateShareButtonWithHidden:YES];
            }
            [_global_event resetToDefaultSetting];
            [self _setup];
        }];

        [dialog bk_addButtonWithTitle:NSLocalizedString(@"Cancel", nil) handler:nil];

        [dialog show];
    }];
}

#pragma mark -
#pragma mark UPNP

- (void)_showExternalURLSuccessDialog:(NSString *)external_url
{
    UIAlertView *dialog = [[UIAlertView alloc] bk_initWithTitle:NSLocalizedString(@"Internet URL", nil) message:external_url]; // Localize

    [dialog bk_addButtonWithTitle:NSLocalizedString(@"OK", nil) handler:nil];

    if (self.isViewLoaded && self.view.window) {
        [dialog bk_addButtonWithTitle:NSLocalizedString(@"Send URL", nil) handler:^{
            [self _showActivityView:external_url];
        }];
    }

    [dialog show];
}

- (void)_showUpnpFailedConfigure:(NSString *)title
{
    UIAlertView *dialog = [[UIAlertView alloc] bk_initWithTitle:title message:NSLocalizedString(@"UPNP_FAILED_CONFIGURE", nil)];

    [dialog bk_addButtonWithTitle:NSLocalizedString(@"Dismiss", nil) handler:nil];

    [dialog show];
}

- (void)_showUPnPDeviceNotFound:(NSString *)title
{
    UIAlertView *dialog = [[UIAlertView alloc] bk_initWithTitle:title message:NSLocalizedString(@"UPNP_NOT_AVAILABLE", nil)];

    [dialog bk_addButtonWithTitle:NSLocalizedString(@"Dismiss", nil) handler:nil];

    [dialog show];
}

- (NSString *)_genUPnPErrorString:(UPnPServiceErrorCode)error_code withIntError:(int)upnp_error_code
{
    NSString *error_type = nil;

    switch (error_code) {
        case UPNPSERVICE_ERROR_CONFIGURE:
            error_type = @"ECONFIG";
            break;
        case UPNPSERVICE_ERROR_NO_EXTERNAL_IP:
            error_type = @"EADDR";
            break;
        case UPNPSERVICE_ERROR_NO_IGD:
            error_type = @"EDEVICE";
            break;
        case UPNPSERVICE_SUCCESS:
            error_type = @"ESUCCESS";
            break;
        default:
            error_type = @"EUNKNOWN";
            break;
    }
    return NSPRINTF(@"%@ (%@:%d)", NSLocalizedString(@"UPnP Error", nil), error_type, upnp_error_code);
}

- (UIActivityIndicatorView *)_showUPnPIndicator
{
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    int box_size = 120;

    CGRect box = CGRectMake(- 75,
                            _internet_url_switch.bounds.size.height / 2 - box_size / 2,
                            box_size, box_size);
    indicator.frame = box;

    [_internet_url_switch addSubview:indicator];

    [indicator startAnimating];

    return indicator;
}

- (void)_startUPnPProcessing
{
    __upnp_processing = YES;
    _setting_reset_button.userInteractionEnabled = NO;
    _share_button.userInteractionEnabled = NO;
    _internet_url_switch.userInteractionEnabled = NO;
    __upnp_last_switch_state = _internet_url_switch.on;
    [_upnp_indicator removeFromSuperview];
    _upnp_indicator = [self _showUPnPIndicator];
}

- (void)_endUPnPProcessing
{
    _internet_url_switch.userInteractionEnabled = YES;
    _setting_reset_button.userInteractionEnabled = YES;
    __upnp_processing = NO;
    [_upnp_indicator removeFromSuperview];
    _upnp_indicator = nil;
}

- (void)_getExternalURL
{
    [self _startUPnPProcessing];

    [[UPnPService sharedService] getExternalURL:^(NSString *url, UPnPServiceErrorCode error_code, int upnp_error_code) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _endUPnPProcessing];

            switch (error_code) {
                case UPNPSERVICE_SUCCESS:
                    _internet_url_switch.on = YES;
                    _global_event.upnp_enabled = YES;
                    __upnp_enabled_state = YES;
                    [self _animateShareButtonWithHidden:NO];
                    [self _showExternalURLSuccessDialog:url];
                    break;
                case UPNPSERVICE_ERROR_NO_IGD:
                    _internet_url_switch.on = NO;
                    __upnp_enabled_state = NO;
                    _global_event.upnp_enabled = NO;
                    [self _animateShareButtonWithHidden:YES];
                    [self _showUPnPDeviceNotFound:[self _genUPnPErrorString:error_code withIntError:upnp_error_code]];
                    break;
                case UPNPSERVICE_ERROR_CONFIGURE: // Fallthrough
                case UPNPSERVICE_ERROR_NO_EXTERNAL_IP:
                    _internet_url_switch.on = NO;
                    __upnp_enabled_state = NO;
                    _global_event.upnp_enabled = NO;
                    [self _animateShareButtonWithHidden:YES];
                    [self _showUpnpFailedConfigure:[self _genUPnPErrorString:error_code withIntError:upnp_error_code]];
                    break;
                default:
                    break;
            }
        });
    }];
}

- (void)_cleanupPinhole
{
    _internet_url_switch.on = NO;

    [self _startUPnPProcessing];

    [[UPnPService sharedService] cleanupPinhole:^(BOOL success, int upnp_error_code) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _endUPnPProcessing];

            __upnp_enabled_state = NO;
            _global_event.upnp_enabled = NO;
            [self _animateShareButtonWithHidden:YES];

            DBG("Portforwarding removal[%d]: %@", upnp_error_code, success ? @"SUCCESS" : @"FAILED");
        });
    }];
}

- (void)_animateShareButtonWithHidden:(BOOL)hidden
{
    _share_button.userInteractionEnabled = !hidden;

    [UIView animateWithDuration:0.2f animations:^{
        _share_button.alpha = hidden ? 0.0f : 1.0f;
    }];
}

- (void)_showActivityView:(NSString *)text
{
    UIActivityViewController *activityView = [[UIActivityViewController alloc] initWithActivityItems:@[text] applicationActivities:nil];

    [self presentViewController:activityView animated:YES completion:^{
        DCHECK;
    }];
}

- (void)_setupInternetURLSwitch
{
    if (__upnp_processing) {
        _internet_url_switch.on = __upnp_last_switch_state;
    } else {
        _internet_url_switch.on = __upnp_enabled_state;
    }

    [self _registerValueChangeEventOnce:_internet_url_switch withBlock:^(UISwitch *sw) {
        if (__upnp_processing) return;

        if (sw.on) {
            [self _getExternalURL];
        } else {
            [self _cleanupPinhole];
        }
    }];
}

- (void)_setupUPnPRefreshButton
{
    _share_button.alpha = __upnp_enabled_state ? 1.0f : 0.0f;
    _share_button.userInteractionEnabled = __upnp_enabled_state;

    [_share_button bk_whenTapped:^{
        [self _getExternalURL];
    }];
}

- (void)_setupUPnPComponents
{
    [self _setupUPnPRefreshButton];
    [self _setupInternetURLSwitch];
}

- (void)_setupMdnsSwitch
{
    _url_type_switch.selectedSegmentIndex = _global_event.current_streaming_setting.url_display_mdns ? 1 : 0;

    [self _registerValueChangeEventOnce:_url_type_switch withBlock:^(UISegmentedControl *sender) {
        [_global_event changeURLType:(sender.selectedSegmentIndex == 1)];
    }];
}

#pragma mark -
#pragma mark VIEW CONTROLLER

- (void)_localizeTableview:(UITableView *)table_view
{
    for (int i = 0; i < table_view.numberOfSections; ++i) {
        for (int j = 0; j < [table_view numberOfRowsInSection:i]; ++j) {
            NSIndexPath *path = [NSIndexPath indexPathForRow:j inSection:i];
            UITableViewCell *cell = [table_view cellForRowAtIndexPath:path];
            [self _localizeSubviews:cell.contentView];
        }
    }
}

- (void)_localizeSubviews:(UIView *)view
{
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            label.text = NSLocalizedString(label.text, nil);
        } else if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            [button setTitle:NSLocalizedString([button titleForState:UIControlStateNormal], nil) forState:UIControlStateNormal];
        }

        [self _localizeSubviews:subview];
    }
}

typedef NS_ENUM(NSUInteger, SettingSection) {
    SECTION_SECURITY = 0,
    SECTION_STREAMING = 1,
    SECTION_RESET = 2
};

- (void)_showAudioNotGrantedDialog
{
    UIAlertView *alert = [[UIAlertView alloc] bk_initWithTitle:NSLocalizedString(@"Microphone Access", nil) message:NSLocalizedString(@"AUDIO_PERMISSION_ALERT", nil)];
    [alert bk_addButtonWithTitle:NSLocalizedString(@"Dismiss", nil) handler:^{}];
    [alert show];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.section == SECTION_STREAMING &&
       indexPath.row == 2 &&
       ![MALRawAudioCapture microphoneAccessGranted]) {
        cell.alpha = 0.3f;

        _enable_audio_switch.userInteractionEnabled = NO;

        [cell bk_whenTapped:^{
            [self _showAudioNotGrantedDialog];
        }];
    }
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return NSLocalizedString([super tableView:tableView titleForHeaderInSection:section], nil);
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (IS_IOS6) {
        self.navigationController.navigationItem.leftBarButtonItem.enabled = YES;
        self.navigationController.navigationItem.rightBarButtonItem.enabled = YES;
    }

    if (IS_IPHONE && IS_IOS6) {
        self.table_view.contentSize = CGSizeMake(self.table_view.frame.size.width, 484 /* _org_content_size.height */);// scrollview in iOS6 for different orientations is utterly broken
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    if (IS_IPHONE) {
        [self.navigationController setNavigationBarHidden:NO animated:YES];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

@end
