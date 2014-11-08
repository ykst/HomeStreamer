//
//  ConnectionInfoList.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/04/02.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "ConnectionInfoViewList.h"
#import "VSInfoElementV.h"
#include <objc/runtime.h>

#define BACKGROUND_ALPHA (0.5f)
#define ANIMATION_SEC (0.2f)

@interface VSInfoElementV(ConnectionInfoList)
@property (nonatomic, readwrite) BOOL updated;
@end

@implementation VSInfoElementV(ConnectionInfoList)

static char ConnectionInfoListKey = 0;

@dynamic updated;

- (BOOL)updated {
    return [objc_getAssociatedObject(self, &ConnectionInfoListKey) boolValue];
}

- (void)setUpdated:(BOOL)updated  {
    objc_setAssociatedObject(self, &ConnectionInfoListKey, @(updated), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@interface ConnectionInfoViewList() {
    NSMutableArray *_views;
    BOOL _visible;
    NSInteger _base_offset;
    UIView * __weak _anchor;
}
@end

@implementation ConnectionInfoViewList

+ (instancetype)createOnAnchor:(UIView *)anchor
{
    ConnectionInfoViewList *obj = [[[self class] alloc] init];

    ASSERT([obj _setupOnAnchor:anchor], return nil);

    return obj;
}

- (BOOL)_setupOnAnchor:(UIView *)anchor
{
    _anchor = anchor;
    _views = [NSMutableArray array];
    _base_offset = IS_IOS6 ? 0 : 0;

    return YES;
}

- (void)_updateInfoElem:(VSInfoElementV *)elem with:(ConnectionInfo *)info
{
    elem.kbips_label.text = NSPRINTF(@"%d", (int)(info.bytes_per_second / 1000.0));
    elem.sound_on_image.hidden = !info.audio_enabled;
    elem.fps_label.text = NSPRINTF(@"%d", (int)(info.client_fps + 0.5f));
    elem.updated = YES;
}

- (void)_addInfoElem:(ConnectionInfo *)info
{
    VSInfoElementV *new_elem = [VSInfoElementV create];

    ASSERT(new_elem != nil, return);

    CGRect goal_frame = CGRectMake(0, _base_offset + _views.count * 25, new_elem.view.frame.size.width, new_elem.view.frame.size.height);
    CGRect init_frame = CGRectMake(-400, _base_offset + _views.count * 25, new_elem.view.frame.size.width, new_elem.view.frame.size.height);

    new_elem.view.frame = init_frame;
    new_elem.view.alpha = _visible ? BACKGROUND_ALPHA : 0.0f;

    new_elem.address_label.text = info.host;
    [self _updateInfoElem:new_elem with:info];
    [_anchor addSubview:new_elem.view];

    [UIView animateWithDuration:ANIMATION_SEC animations:^{
        new_elem.view.frame = goal_frame;
    }];
    [_views addObject:new_elem];
}

- (void)_removeInfoElem:(VSInfoElementV *)elem
{
    UIView *view_to_remove = elem.view;
    CGRect goal_frame = CGRectMake(100, view_to_remove.frame.origin.y, view_to_remove.frame.size.width, view_to_remove.frame.size.height);

    [UIView animateWithDuration:ANIMATION_SEC animations:^{
        view_to_remove.frame = goal_frame;
        view_to_remove.alpha = 0.0f;
    } completion:^(BOOL finished) {
        if (finished) {
            [view_to_remove removeFromSuperview];
        }
    }];
    
    [_views removeObject:elem];

    int count = _views.count;
    for (int i = 0; i < count; ++i) {
        VSInfoElementV *move_elem = _views[i];
        CGRect goal_frame = CGRectMake(0, _base_offset + i * 25, move_elem.view.frame.size.width, move_elem.view.frame.size.height);
        [UIView animateWithDuration:ANIMATION_SEC animations:^{
            move_elem.view.frame = goal_frame;
        }];
    }
}

- (void)updateInfos:(NSArray *)infos
{
    for (VSInfoElementV *elem in _views) {
        elem.updated = NO;
    }

    for (ConnectionInfo *info in infos) {
        VSInfoElementV *found_view = nil;
        for (VSInfoElementV *view in _views) {
            if ([view.address_label.text isEqualToString:info.host]) {
                found_view = view;
                break;
            }
        }

        if (found_view != nil) {
            [self _updateInfoElem:found_view with:info];
        } else {
            [self _addInfoElem:info];
        }
    }

    NSMutableArray *remove_list = nil;
    for (VSInfoElementV *elem in _views) {
        if (!elem.updated) {
            if (remove_list == nil) {
                remove_list = [NSMutableArray arrayWithObject:elem];
            } else {
                [remove_list addObject:elem];
            }
        }
    }

    for (VSInfoElementV *elem in remove_list) {
        [self _removeInfoElem:elem];
    }
}

- (void)setVisible:(BOOL)visible
{
    _visible = visible;

    CGFloat goal_alpha = visible ? BACKGROUND_ALPHA : 0.0f;

    for (VSInfoElementV *elem in _views) {
        [UIView animateWithDuration:ANIMATION_SEC animations:^{
            elem.view.alpha = goal_alpha;
        }];
    }
}

@end
