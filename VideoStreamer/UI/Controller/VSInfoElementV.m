//
//  VSInfoElementV.m
//  
//
//  Created by Yukishita Yohsuke on 2014/04/01.
//
//

#import "VSInfoElementV.h"

@implementation VSInfoElementV

+ (instancetype)create
{
    VSInfoElementV *obj = [[[self class] alloc] init];

    ASSERT([obj _setup], return nil);

    return obj;
}

- (BOOL)_setup
{
    [[NSBundle mainBundle] loadNibNamed:@"VSInfoElementV" owner:self options:nil];

    _mark.layer.cornerRadius = _mark.bounds.size.width / 2;
    _view.layer.cornerRadius = _view.bounds.size.height / 2;
    _sound_on_image.layer.cornerRadius = _sound_on_image.bounds.size.height / 2;
    _sound_on_image.hidden = YES;
    _fps_label.text = nil;
    _kbips_label.text = nil;

    return YES;
}

@end
