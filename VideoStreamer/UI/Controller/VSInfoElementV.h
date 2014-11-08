//
//  VSInfoElementV.h
//  
//
//  Created by Yukishita Yohsuke on 2014/04/01.
//
//

#import <UIKit/UIKit.h>

@interface VSInfoElementV : NSObject
+ (instancetype)create;
@property (strong, nonatomic) IBOutlet UIView *view;
@property (weak, nonatomic) IBOutlet UILabel *address_label;
@property (weak, nonatomic) IBOutlet UIView *mark;
@property (weak, nonatomic) IBOutlet UIImageView *sound_on_image;
@property (weak, nonatomic) IBOutlet UILabel *fps_label;
@property (weak, nonatomic) IBOutlet UILabel *kbips_label;

@end
