//
//  genOogie.h
//  oogieCam
//
//  Created by Dave Scruton on 9/15/20.
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "oogieStyles.h"

@interface genOogie : NSObject

+ (id)sharedInstance;

- (instancetype)init;

-(NSArray*) addPickerRow : (UIView*) parent : (int) tag : (NSString*) label :
                (int) yoff : (int) width : (int) ysize;
-(NSArray*) addPickerSliderRow : (UIView*) parent : (int) ptag : (int) stag : (NSString*) label :
                        (int) yoff : (int) width : (int) ysize;
-(NSArray*) addSliderRow : (UIView*) parent : (int) tag : (NSString*) label :
                (int) yoff : (int) width : (int) ysize :
                (float) smin : (float) smax;
@end


