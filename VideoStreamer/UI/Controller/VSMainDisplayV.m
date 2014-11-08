//
//  VSMainDisplayV.m
//  VideoStreamer
//
//  Created by Yukishita Yohsuke on 2014/03/14.
//  Copyright (c) 2014年 monadworks. All rights reserved.
//

#import "VSMainDisplayV.h"

@interface VSMainDisplayV() {
    GLKMatrix3 _screen_orientation_affine;
    GLKMatrix3 _aspect_keep_affine;
    CGSize _known_texture_size;
    UIView *_sleep_splash;
}
@end

@implementation VSMainDisplayV

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

static float __get_screen_scale()
{
    static float __main_screen_scale = -1.0f;

    if (__main_screen_scale < 0.0f) {
        CGFloat scale = 1.0f;
        if (IS_IPHONE) {
            scale = [UIScreen mainScreen].scale;
        } else{
            scale = MIN([UIScreen mainScreen].scale, 1.0);
        }
        __main_screen_scale = (float)scale;
    }

    return __main_screen_scale;
}

static inline CGSize __landscape_size(CGSize size)
{
    if (size.width < size.height) {
        return CGSizeMake(size.height, size.width);
    }
    return size;
}

static inline CGSize __portrate_size(CGSize size)
{
    if (size.width > size.height) {
        return CGSizeMake(size.height, size.width);
    }
    return size;
}

// override
- (void)_init
{
    self.opaque = YES;
    self.hidden = NO;
    self.contentMode = UIViewContentModeCenter;

    CAEAGLLayer *eagl_layer = (CAEAGLLayer *)self.layer;

    eagl_layer.contentsScale = __get_screen_scale();

    CGRect main_bounds = [UIScreen mainScreen].bounds;

    GLKMatrix3 affine_by_orientation = GLKMatrix3Make(-1, 0, 1, 0, 1, 0, 0, 0, 1);

    switch([UIApplication sharedApplication].statusBarOrientation) {
        case UIInterfaceOrientationLandscapeLeft:
            main_bounds.size = __landscape_size(main_bounds.size);
            affine_by_orientation = GLKMatrix3Make(-1, 0, 1,
                                                   0, 1, 0,
                                                   0, 0, 1);
            break;
        case UIInterfaceOrientationLandscapeRight:
            main_bounds.size = __landscape_size(main_bounds.size);
            affine_by_orientation = GLKMatrix3Make(1, 0, 0,
                                                   0, -1, 1,
                                                   0, 0, 1);
            break;
        case UIInterfaceOrientationPortrait:
            affine_by_orientation = GLKMatrix3Make(0, -1, 1,
                                                   -1, 0, 1,
                                                   0, 0, 1);
            main_bounds.size = __portrate_size(main_bounds.size);
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            affine_by_orientation = GLKMatrix3Make(0, 1, 0,
                                                   1, 0, 0,
                                                   0, 0, 1);
            main_bounds.size = __portrate_size(main_bounds.size);
            break;
        default:break;
    }

    _screen_orientation_affine = affine_by_orientation;

    eagl_layer.bounds = main_bounds;
    eagl_layer.opaque = YES;
    eagl_layer.drawableProperties = @{
                                      kEAGLDrawablePropertyRetainedBacking:@(NO),
                                      kEAGLDrawablePropertyColorFormat:kEAGLColorFormatRGBA8
                                      };

    [TGLDevice runMainThreadSync:^{
        _fbo = [TGLFrameBufferObject createOnEAGLStorage:[TGLDevice currentContext] withLayer:eagl_layer];
        _drawer = [MCVTextureRenderer create];

        [_drawer setAffineMatrix:affine_by_orientation];
    }];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
}

static inline GLKMatrix3 __calc_aspect_keep_afine(CGSize screen_landscape_size, CGSize texture_size, bool is_mirror)
{
    // a priori: camera input is always rastered along landscape
    float width_screen_ratio = screen_landscape_size.width / texture_size.width;
    float height_screen_ratio = screen_landscape_size.height / texture_size.height;

    float height_texture_scale = 1.0f;
    float height_texture_offset = 0.0f;

    float width_texture_scale = 1.0f;
    float width_texture_offset = 0.0f;

    if (height_screen_ratio > width_screen_ratio) {
        float texture_aspect = texture_size.width / texture_size.height;
        float screen_aspect = screen_landscape_size.width / screen_landscape_size.height;

        width_texture_scale = screen_aspect / texture_aspect;
        width_texture_offset = (1.0f - width_texture_scale) / 2.0f;
    } else {
        float texture_aspect = texture_size.height / texture_size.width;
        float screen_aspect = screen_landscape_size.height / screen_landscape_size.width;

        height_texture_scale = screen_aspect / texture_aspect;
        height_texture_offset = (width_texture_scale - 1.0f) / 2.0f;
    }

    if (is_mirror) {
        height_texture_scale = - height_texture_scale;
        height_texture_offset = 1.0 - height_texture_offset;
    }

    return GLKMatrix3Make(width_texture_scale, 0, width_texture_offset,
                          0, height_texture_scale, height_texture_offset,
                          0, 0, 1);
}

- (BOOL)drawBuffer:(MCVBufferFreight *)freight
{
    if (freight.size.width != _known_texture_size.width ||
        freight.size.height != _known_texture_size.height) {

        _aspect_keep_affine = __calc_aspect_keep_afine(__landscape_size(self.layer.bounds.size), freight.size, _mirror_mode);

        [TGLDevice runMainThreadSync:^{
            [_drawer setAffineMatrix:GLKMatrix3Multiply( _screen_orientation_affine, _aspect_keep_affine)];
        }];

        _known_texture_size = freight.size;
    }

    return [super drawBuffer:freight];
}

- (void)showSleepSplash
{
    @synchronized(self) {
        // TODO: 回転しても確実に全面を覆えるようにちょっとサボっている。
        CGFloat max_length = MAX(self.frame.size.width, self.superview.frame.size.height);

        if (!_sleep_splash) {
            _sleep_splash = [[UIView alloc] initWithFrame:CGRectMake(-max_length, -max_length, max_length * 4, max_length * 4)];;

            _sleep_splash.backgroundColor = [UIColor blackColor];
            _sleep_splash.opaque = YES;
            _sleep_splash.alpha = 0;

            [self addSubview:_sleep_splash];

            [UIView animateWithDuration:0.5f animations:^{
                _sleep_splash.alpha = 1;
            }];
        }
    }
}

- (void)clearSleepSplash
{
    @synchronized(self) {
        if (_sleep_splash != nil) {
            UIView *old_view = _sleep_splash;

            _sleep_splash = nil;

            [UIView animateWithDuration:0.5f animations:^{
                old_view.alpha = 0;
            } completion:^(BOOL finished) {
                if (finished) {
                    [old_view removeFromSuperview];
                }
            }];
        }
    }
}

@end
