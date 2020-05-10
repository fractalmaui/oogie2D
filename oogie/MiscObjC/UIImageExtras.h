#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface UIImage (Extras)
- (UIImage*)imageByScalingAndCroppingForSize:(CGSize)targetSize;
+ (UIImage*)circularScaleAndCropImage:(UIImage*)image frame:(CGRect)frame;

@end
