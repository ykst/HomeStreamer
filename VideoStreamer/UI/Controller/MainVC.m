//
//  MainVC.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/02/28.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <BlocksKit/BlocksKit+UIKit.h>
#import <Reachability/Reachability.h>

#import "MainPipeline.h"
#import "GlobalEvent.h"

#import "ConnectionInfoViewList.h"
#import "MainVC.h"
#import "Application/UPnPService.h"

@interface MainVC () <AVAudioPlayerDelegate> {
    AVAudioPlayer *_start_sound_player;
    MainPipeline *_pipe;
    UIInterfaceOrientation _orig_orientation;
    UIInterfaceOrientation _disappear_orientation;

    UIView *_connection_info_anchor;
    ConnectionInfoViewList *_info_list;
    NSTimer *_statistics_timer;

    NSArray *_org_toolbar_buttons;
    NSMutableArray *_modified_toolbar_buttons;

    BOOL _first_appear;
    UIAlertView *_network_alert;
    BOOL _wifi_available;
    BOOL _appearing;
    BOOL _going_to_info;
    BOOL _need_appstore_review_begging;
    BOOL _ready_appstore_review_begging;

    BOOL _bar_is_visible;
    UIViewController *_setting_vc;

    UIPopoverController *_popover;

    NSString *_last_shown_url;

    // float _prev_brightness;

    UIImage *_light_on_image;
    UIImage *_light_off_image;
}

@end

@implementation MainVC

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self _setup];
    [self _playStartSound];
    [self _start];
}

- (void)_setup
{
    _first_appear = YES;
    _bar_is_visible = YES;

    _light_on_image = [UIImage imageNamed:@"Assets/Images/light_on"];
    _light_off_image = [UIImage imageNamed:@"Assets/Images/light_off"];

    [self _setupButtons]; // must be first to save _prev_brightness
    [self _setupPipeline];
    [self _setupTouchEvents];
    [self _setupInfoListView];

    _wifi_available = YES;
    _going_to_info = NO;
    _need_appstore_review_begging = [GlobalEvent sharedMachine].current_streaming_setting.beg_appstore_review;
    _ready_appstore_review_begging = NO;
    _last_shown_url = nil;

    if (IS_IOS6) {
        [[[self navigationController] navigationBar] setTintColor:[UIColor clearColor]];
        [[self navigationController] navigationBar].alpha = 0.6;
        [[self navigationController] navigationBar].translucent = YES;
    } else {
        [self setNeedsStatusBarAppearanceUpdate];
    }

    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [self.navigationController setToolbarHidden:NO animated:YES];
}

#pragma mark -
#pragma mark Statistics View

- (void)_toggleBars
{
    if (_bar_is_visible) {
        [self _hideBars];
    } else {
        [self _showBars];
    }
}

- (void)_hideBars
{
    if (_bar_is_visible) {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
        [self.navigationController setToolbarHidden:YES animated:YES];
        [_info_list setVisible:NO];
    }

    _bar_is_visible = NO;
}

- (void)_showBars
{
    if (!_bar_is_visible) {
        [self.navigationController setNavigationBarHidden:NO animated:YES];
        [self.navigationController setToolbarHidden:NO animated:YES];
        [_info_list setVisible:YES];
    }
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];

    _bar_is_visible = YES;
}

- (void)_setupTouchEvents
{
    [self.view bk_whenTapped:^{
        [self _toggleBars];

        if (_need_appstore_review_begging && _ready_appstore_review_begging) {
            [self _begAppStoreReview];
        }
    }];
}

- (void)_begAppStoreReview
{
    if (!_ready_appstore_review_begging || !_need_appstore_review_begging) return; // Double check to prevent spamming the user

    _ready_appstore_review_begging = NO;
    _need_appstore_review_begging = NO;
    [[GlobalEvent sharedMachine] neverShowReviewBegging];

    UIAlertView *dialog = [[UIAlertView alloc] bk_initWithTitle:NSLocalizedString(@"REVIEW_BEGGING_TITLE", nil) message:NSLocalizedString(@"REVIEW_BEGGING_CONTENT", nil)];

    [dialog bk_addButtonWithTitle:NSLocalizedString(@"Later", nil) handler:nil];

    [dialog bk_addButtonWithTitle:NSLocalizedString(@"Review", nil) handler:^{
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:NSLocalizedString(@"MOBILE_STORE_URL", nil)]];
    }];

    [dialog show];
}

- (void)_setupInfoListView
{
    NSInteger y_offset = 0;
    CGRect base_frame = _connection_info_base_anchor.frame;

    if (IS_IOS6) {
        y_offset = -30;
    }

    _connection_info_anchor = [[UIView alloc] initWithFrame:CGRectMake(base_frame.origin.x, base_frame.origin.y + y_offset, 1, 1)];

    [self.view addSubview:_connection_info_anchor];

    _info_list = [ConnectionInfoViewList createOnAnchor:_connection_info_anchor];
    [_info_list setVisible:YES];
}

#pragma mark -
#pragma mark Pipeline

- (void)_setupPipeline
{
    _pipe = [MainPipeline createWithMainDisplay:_main_display withDelegate:self];
}

- (void)_switchToobarButtons:(BOOL)camera_switch_enabled
{
    if (camera_switch_enabled) {
        [self setToolbarItems:_org_toolbar_buttons animated:!_first_appear];
    } else {
        [self setToolbarItems:_modified_toolbar_buttons animated:!_first_appear];
    }
}

- (void)pipeline:(MainPipeline *)pipeline frontCameraEnabledState:(BOOL)enabled
{
    if ([NSThread isMainThread]) {
        [self _switchToobarButtons:enabled];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _switchToobarButtons:enabled];
        });
    }
}

- (void)pipelineAudioNotGranted
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSTimer bk_performBlock:^{
            UIAlertView *alert = [[UIAlertView alloc] bk_initWithTitle:NSLocalizedString(@"Microphone Access", nil) message:NSLocalizedString(@"AUDIO_PERMISSION_ALERT", nil)];
            [alert bk_addButtonWithTitle:NSLocalizedString(@"Dismiss", nil) handler:^{}];
            [alert show];
        } afterDelay:0.5f];
    });
}

- (void)pipelineServerCouldNotStart
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *dialog = [[UIAlertView alloc] bk_initWithTitle:NSLocalizedString(@"SERVER_START_FAILED_TITLE", nil) message:NSLocalizedString(@"SERVER_START_FAILED_CONTENT", nil)];

        [dialog bk_addButtonWithTitle:NSLocalizedString(@"Dismiss", nil) handler:nil];

        [dialog show];
    });
}

- (void)pipelineDimScreenRequest
{
    DBG(@"screen dim request");

    [self _dimScreen];

    if ([self _iamFront] && ![self _settingViewIsFront]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _hideBars];
        });
    }
}

- (void)pipelineResetScreenRequest
{
    [self _recoverScreen];
}

- (void)pipelineDidChangeVideoSleepStatus:(BOOL)sleep
{
    _camera_change_button.enabled = !sleep;
}

#pragma mark -
#pragma mark Toolbar 

- (void)_setupButtons
{
    [self _setupBarButtons];
    [self _setupCameraButton];
    [self _setupSettingButton];
    [self _setupInfoButton];
    [self _setupLightButton];
}

- (void)_setupBarButtons
{
    _org_toolbar_buttons = self.toolbarItems;
    _modified_toolbar_buttons = [self.toolbarItems mutableCopy];

    [_modified_toolbar_buttons removeObject:_camera_change_button];
    [_modified_toolbar_buttons removeObject:_leftmost_toolber_margin];
}

- (void)_setupCameraButton
{
    [_camera_change_button bk_initWithImage:_camera_change_button.image
                                      style:_camera_change_button.style
                                    handler:^(id sender) {
        if (!IS_IPHONE && [self _settingViewIsFront]) {
            DBG("guard transition behind the setting panel");
            return;
        }
        if ([_pipe toggleCameraPosition] == YES) {
            DBG(@"camera position switched");
        }
    }];

    if ([GlobalEvent sharedMachine].current_streaming_setting.enable_60fps) {
        [self setToolbarItems:_modified_toolbar_buttons animated:NO];
    }
}

- (void)_setupSettingButton
{
    void (^handler)(UIBarButtonItem *) = ^(UIBarButtonItem *button) {

        if (_need_appstore_review_begging && _ready_appstore_review_begging) {
            [self _begAppStoreReview];
        }

        if (IS_IPHONE) {
            if (_setting_vc) {
                [self.navigationController pushViewController:_setting_vc animated:YES];
            } else {
                if (IS_IOS6) {
                    [self performSegueWithIdentifier:@"setting_modal_ios6" sender:self];
                } else {
                    [self performSegueWithIdentifier:@"setting_modal" sender:self];
                }
            }
        } else {
            if (_setting_vc) {
                if (!_popover) {
                    _popover = [[UIPopoverController alloc] initWithContentViewController:_setting_vc];
                }
                [_popover presentPopoverFromBarButtonItem:_setting_button permittedArrowDirections:UIPopoverArrowDirectionDown animated:YES];
            } else {
                if (IS_IOS6) {
                    [self performSegueWithIdentifier:@"setting_popup_ios6" sender:self];
                } else {
                    [self performSegueWithIdentifier:@"setting_popup" sender:self];
                }
            }
        }
    };

    [_setting_button bk_initWithImage:_setting_button.image style:_setting_button.style handler:handler];
}

- (void)_setupInfoButton
{
    [_info_button bk_initWithImage:_info_button.image style:_info_button.style handler:^(UIBarButtonItem *button){
        if (!IS_IPHONE && [self _settingViewIsFront]) {
            DBG("guard transition behind the setting panel");
            return;
        }

        [self performSegueWithIdentifier:@"info_push" sender:self];

        _going_to_info = YES;
    }];
}

- (void)_dimScreen
{
    dispatch_async(dispatch_get_main_queue(), ^{
        _screen_light_button.image = _light_off_image;
        /*
        _prev_brightness = [UIScreen mainScreen].brightness;
        [UIScreen mainScreen].brightness = 0.0f;
         */
    });
}

- (void)_recoverScreen
{
    // sometimes setting brightness fails, so we are doing pessimistically
    dispatch_async(dispatch_get_main_queue(), ^{
        _screen_light_button.image = _light_on_image;
        /* do not control brightness
        if ([UIScreen mainScreen].brightness < 0.01f) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIScreen mainScreen].brightness = _prev_brightness;
            });
        }
         */
    });
}

- (void)_setupLightButton
{
    UIImage *first_image = [GlobalEvent sharedMachine].current_streaming_setting.playback_enabled ? _light_on_image : _light_off_image;

    // _prev_brightness = [UIScreen mainScreen].brightness;

    [_screen_light_button bk_initWithImage:first_image style:_screen_light_button.style handler:^(UIBarButtonItem *button){

        BOOL playback_enabled = [GlobalEvent sharedMachine].current_streaming_setting.playback_enabled;

        [[GlobalEvent sharedMachine] setPlaybackMode:!playback_enabled];

        if (playback_enabled) {
            [self _dimScreen];
        } else {
            [self _recoverScreen];
        }
    }];
}

- (void)_setTitleToDefaultWhenGoingToSlidableModalViewInIPad
{
    if (_going_to_info) {
        self.title = nil;
    }
}

#pragma mark -
#pragma mark Sound

- (void)_playStartSound
{
    if (_start_sound_player == nil) {
        NSString *soundFilePath = [[NSBundle mainBundle] pathForResource:@"Assets/Sounds/start_record" ofType:@"mp3"];
        NSURL *soundFileURL = [NSURL fileURLWithPath:soundFilePath];
        NSError *err;

        _start_sound_player = [[AVAudioPlayer alloc] initWithContentsOfURL:soundFileURL error:&err];
    }

    [_start_sound_player play];

    _start_sound_player.delegate = self;
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    _start_sound_player = nil;
}

#pragma mark -
#pragma mark Rotation Invariance

static inline int __get_absolute_rotation_mode(UIInterfaceOrientation orientation)
{
    float absolute_rotation = 0;

    if (orientation == UIInterfaceOrientationPortrait) {
        absolute_rotation = 0;
    } else
    if (orientation == UIInterfaceOrientationLandscapeLeft) {
        absolute_rotation = 1;
    } else
    if (orientation == UIInterfaceOrientationLandscapeRight) {
        absolute_rotation = 3;
    } else {
        absolute_rotation = 2;
    }

    return absolute_rotation;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    int to_rotation = __get_absolute_rotation_mode(toInterfaceOrientation);
    int original_rotation =  __get_absolute_rotation_mode(_orig_orientation);
    int rotation_mode = to_rotation - original_rotation;

    float rotation = rotation_mode * M_PI / 2.0;

    // TODO:
    // iPadの180度回転については
    // ジャイロを使って方向を検出した上で二回に分けてアニメーションしないとうまくいかないパターンがある。270度回転？ねぇよ んなもん
    [UIView animateWithDuration:duration animations:^{
        _main_display.transform = CGAffineTransformMakeRotation(rotation);
    }];
}

- (void)_setupFirstAppear
{
    _disappear_orientation = [UIApplication sharedApplication].statusBarOrientation;
    _orig_orientation = [UIApplication sharedApplication].statusBarOrientation;
}

#pragma mark -
#pragma mark Reachability

- (void)_showURL
{
    if (self.isViewLoaded && self.view.window != nil && !(IS_IPHONE && [self _settingViewIsFront])) {

        NSString *url = [[GlobalEvent sharedMachine] generateCurrentURL];

        if (url != nil) {
            if ((_last_shown_url != nil) && ![_last_shown_url isEqualToString:url]) {
                [self _showURLChangeDialog:url];

                if ([GlobalEvent sharedMachine].upnp_enabled) {
                    [[UPnPService sharedService] reassignPinhole:^(BOOL success, int upnp_error_code) {
                        DBG("reassign pinhole[%d] result on %@", upnp_error_code, success ? @"SUCCESS" : @"FAILURE");
                    }];
                }
            }

            _last_shown_url = url;

            self.title = url;
        } else {
            self.title = nil;
        }
    }
}

- (void)_showURLChangeDialog:(NSString *)url
{
    UIAlertView *dialog = [[UIAlertView alloc] bk_initWithTitle:NSLocalizedString(@"URL_CHANGE_TITLE", nil) message:url];

    [dialog bk_addButtonWithTitle:NSLocalizedString(@"Dismiss", nil) handler:nil];

    [dialog show];
}

- (void)_checkReachability
{
    Reachability *reachability = [Reachability reachabilityForInternetConnection];

    if (reachability.isReachableViaWiFi) {
        _wifi_available = YES;
        [_network_alert dismissWithClickedButtonIndex:0 animated:YES];
        _network_alert = nil;
        [self _showURL];
    } else if (_wifi_available != NO && _network_alert == nil) {
        _network_alert = [[UIAlertView alloc] bk_initWithTitle:NSLocalizedString(@"Network Connection", nil) message:NSLocalizedString(@"NETWORK_CONNECTION_ALERT", nil)];
        [_network_alert bk_addButtonWithTitle:NSLocalizedString(@"Dismiss", nil) handler:^{
            _network_alert = nil;
        }];
        [_network_alert show];
        _wifi_available = NO;
        [self _showURL];
    }
}

#pragma mark -
#pragma mark Running State

- (void)_start
{
    [_statistics_timer invalidate];

    _statistics_timer = [NSTimer bk_scheduledTimerWithTimeInterval:1.0f block:^(NSTimer *timer) {
        if (_appearing) {
            [self periodicTask:self];
        }
    } repeats:YES];
}

#ifdef DEBUG
#define CONNECTION_COUNT_THRESHOLD_FOR_BEGGING (1)
#else
#define CONNECTION_COUNT_THRESHOLD_FOR_BEGGING (10)
#endif
- (void)periodicTask:(id)timer
{
    [_info_list updateInfos:[[GlobalEvent sharedMachine] gatherClientStatistics]];

    if (_need_appstore_review_begging && !_ready_appstore_review_begging) {
        uint32_t success_count = [GlobalEvent sharedMachine].current_streaming_setting.successfull_connection_count;

        _ready_appstore_review_begging = success_count > CONNECTION_COUNT_THRESHOLD_FOR_BEGGING;
#ifdef DEBUG
        if (_ready_appstore_review_begging) {
            DBG("Begging ready");
        }
#endif
    }

    [self _checkReachability];

    [[GlobalEvent sharedMachine] periodicTask];
}

- (void)_pause
{
    [_statistics_timer invalidate];
    _statistics_timer = nil;
}

#pragma mark -
#pragma mark View Controller

- (BOOL)_settingViewIsFront
{
    return _setting_vc && _setting_vc.isViewLoaded && _setting_vc.view.window;
}

- (BOOL)_iamFront
{
    return self.isViewLoaded && self.view.window != nil;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[[segue identifier] substringToIndex:8] isEqualToString:@"setting_"]) {
        _setting_vc = [segue destinationViewController];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [self _showURL];

    if (_first_appear) {
        _first_appear = NO;
    }

    _going_to_info = NO;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    _disappear_orientation = [UIApplication sharedApplication].statusBarOrientation;

    if (IS_IPHONE) {
        self.title = nil;
    }

    _appearing = NO;

    [self _setTitleToDefaultWhenGoingToSlidableModalViewInIPad];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    if (_first_appear) {
        [self _setupFirstAppear];
    } else if (_disappear_orientation != [UIApplication sharedApplication].statusBarOrientation) {
        [self willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)[UIApplication sharedApplication].statusBarOrientation duration:0.5f];
    }

    _appearing = YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
