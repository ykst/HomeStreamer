//
//  InfoVC.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/04/27.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import <BlocksKit/UIWebView+BlocksKit.h>
#import <BlocksKit/NSTimer+BlocksKit.h>
#import <BlocksKit/UIAlertView+BlocksKit.h>
#import "InfoVC.h"

//#define DEBUG_LOCAL_SUPPORT_WEB

@interface InfoVC () {
    UIWebView *_webview;
    UIActivityIndicatorView *_indicator;
    UIView *_indicator_background;
    BOOL _loading;
}

@end

@implementation InfoVC

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
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.

    if (_webview) {
        [_webview reload];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self _setupWebview];
}

- (void)viewDidAppear:(BOOL)animated
{
    [self _setupNavigationBar];
}

- (CGFloat)_calcToolbarHeight
{
    CGSize toolbar_size = self.navigationController.navigationBar.frame.size;

    return MIN(toolbar_size.height, toolbar_size.width);
}

- (void)_setupNavigationBar
{
#if defined(DEBUG_LOCAL_SUPPORT_WEB)
    self.title = @"****** DEBUG *******";
#else
    self.title = NSLocalizedString(@"Help", nil);
#endif
    if (IS_IOS6) {
        [[[self navigationController] navigationBar] setTintColor:[UIColor clearColor]];
        [[self navigationController] navigationBar].alpha = 0.6;
        [[self navigationController] navigationBar].translucent = YES;
    } else {
        [[self navigationController] navigationBar].translucent = YES;
    }
}


#pragma mark -
#pragma mark WEBVIEW

- (void)_setupWebview
{
    CGFloat bar_offset = self.navigationController.navigationBar.frame.size.height;

    if (!IS_IOS6) {
        CGRect statusbar_frame = [[UIApplication sharedApplication] statusBarFrame];

        // wow, it's dirty!
        bar_offset += MIN(statusbar_frame.size.height, statusbar_frame.size.width);
    }

    CGRect bounds = CGRectMake(self.view.bounds.origin.x,
                               self.view.bounds.origin.y + bar_offset,
                               self.view.bounds.size.width,
                               self.view.bounds.size.height - bar_offset - [self _calcToolbarHeight]);

    _loading = NO;
    if (_webview) {
        [_webview removeFromSuperview];
    }
    _webview = [[UIWebView alloc] initWithFrame:bounds];

#if defined(DEBUG_LOCAL_SUPPORT_WEB) && defined(DEBUG)
    NSString *url=NSLocalizedString(@"SUPPORT_URL_LOCAL", nil);
    self.title = @"****** DEBUG *******";
#else
    NSString *url=NSLocalizedString(@"SUPPORT_URL", nil);
#endif
    NSURL *nsurl=[NSURL URLWithString:url];
    NSURLRequest *nsrequest = [NSURLRequest requestWithURL:nsurl cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15.0f];

    [_webview loadRequest:nsrequest];
    _webview.scrollView.bounces = NO;
    _webview.delegate = self;
    [self.view addSubview:_webview];
}

- (void)webViewDidStartLoad:(UIWebView *)webview
{
    _loading = YES;

    [NSTimer bk_scheduledTimerWithTimeInterval:0.5 block:^(NSTimer *timer) {
        if (_loading && !_indicator) {
            _indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
            int box_size = 80;

            CGRect box = CGRectMake(webview.bounds.size.width / 2 - box_size / 2,
                                    webview.bounds.size.height / 2 - box_size / 2,
                                    box_size, box_size);
            _indicator.frame = box;
            _indicator_background = [[UIView alloc] initWithFrame:box];
            _indicator_background.layer.cornerRadius = 10;
            _indicator_background.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.0];

            [webview addSubview:_indicator_background];
            [webview addSubview:_indicator];
            [_indicator startAnimating];

            [UIView animateWithDuration:0.2 animations:^{
                _indicator_background.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
            }];
        }
    } repeats:NO];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self _endLoading];
}

- (void)webView:(UIWebView *)webview didFailLoadWithError:(NSError *)error
{
    [self _endLoading];

    UIAlertView *alert = [[UIAlertView alloc] bk_initWithTitle:NSLocalizedString(@"Network Error", nil) message:NSPRINTF(@"%@ (%@)", error.localizedDescription, error.userInfo[@"NSErrorFailingURLStringKey"])];
    [alert bk_addButtonWithTitle:@"OK" handler:^{}];
    [alert show];
}

- (void)_endLoading
{
    if (_indicator && _loading) {
        [UIView animateWithDuration:0.2 animations:^{
            _indicator_background.alpha = 0;
        } completion:^(BOOL finished) {
            if (finished) {
                [_indicator stopAnimating];
                [_indicator removeFromSuperview];
                [_indicator_background removeFromSuperview];
                _indicator = nil;
                _indicator_background = nil;
            }
        }];
    }
    _loading = NO;
}

#pragma mark -
#pragma mark VIEW CONTROLLER

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

    if (_webview != nil) {
        [_webview stopLoading];
        [_webview.layer removeAllAnimations];
        [_webview loadHTMLString: @"" baseURL: nil]; //
        [_webview removeFromSuperview];

#ifdef DEBUG
        DUMPD([[NSURLCache sharedURLCache] currentMemoryUsage]);
#endif
        [[NSURLCache sharedURLCache] removeAllCachedResponses];

        _webview.delegate = nil;
        _webview = nil;
    }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [UIView animateWithDuration:duration animations:^{
        CGRect frame = self.view.frame;
        CGFloat width = frame.size.width;
        CGFloat height = frame.size.height;

        if (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
            toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {

            _webview.frame = CGRectMake(_webview.frame.origin.x, _webview.frame.origin.y, MAX(width, height), MIN(width, height) - [self _calcToolbarHeight] -  _webview.frame.origin.y);
        } else {
            _webview.frame = CGRectMake(_webview.frame.origin.x, _webview.frame.origin.y, MIN(width, height), MAX(width, height) - [self _calcToolbarHeight] -  _webview.frame.origin.y);
        }
    }];
}

- (void)dealloc
{
    
}

@end
