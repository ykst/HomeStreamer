#import "MainHTTPConnection.h"

#import "Domain/ControlMessage.h"
#import "Domain/MediaStreamMessage.h"

#import <MobileAL/MALRawAudioCapture.h>

@implementation MainHTTPConnection

- (NSDictionary *)setupReplacementWordDictioary
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict addEntriesFromDictionary:[super setupReplacementWordDictioary]];
    [dict addEntriesFromDictionary:[MediaStreamMessage specification_dic]];
    [dict addEntriesFromDictionary:[ControlMessage specification_dic]];
    [dict addEntriesFromDictionary:@{@"MIC_GRANTED" : [MALRawAudioCapture microphoneAccessGranted] ? @"1" : @"0"}];
    [dict addEntriesFromDictionary:@{@"APP_VERSION":[[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"],
                                     @"LOCALIZED_APP_NAME":@"Home Streamer",
                                     @"LOCALIZED_TITLE":NSLocalizedString(@"Home Streamer", nil),
                                     @"LOCALIZED_IMAGE_QUALITY":NSLocalizedString(@"Image Quality", nil),
                                     @"LOCALIZED_BUFFERING":NSLocalizedString(@"Buffer Size", nil),
                                     @"LOCALIZED_CONTRAST_ADJUSTMENT":NSLocalizedString(@"Contrast Adjustment", nil),
                                     @"LOCALIZED_COPYING":NSLocalizedString(@"COPYING", nil),
                                     @"DESC_FOCUS_LOCKED":NSLocalizedString(@"DESC_FOCUS_LOCKED", nil),
                                     @"DESC_FOCUS_AUTO":NSLocalizedString(@"DESC_FOCUS_AUTO", nil),
                                     @"SHARE_TWITTER_URL":NSLocalizedString(@"SHARE_URL", nil),
                                     @"SHARE_TWITTER_COMMENT":NSLocalizedString(@"TWITTER_COMMENT", nil),
                                     @"SHARE_FACEBOOK_URL":NSLocalizedString(@"SHARE_URL", nil),
                                     @"APPSTORE_URL":NSLocalizedString(@"MOBILE_STORE_URL", nil)}];

    return dict;
}

@end
