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
-(NSArray*) addTextRow : (UIView*) parent : (int) tag : (NSString*) label :
                (int) yoff : (int) width : (int) ysize ;
//11/25 new
- (void) buildEnvelope256 : (float)attack : (float)decay : (float)sustain : (float)slevel : (float)release : (float*)results;
-(UIImage *) makeADSRImage : (int) bwid : (int) bhit : (float *)env256;

-(NSMutableDictionary*) configureViewFromVC : (BOOL) reset : (NSDictionary*) pDict : (NSArray*) allP :
                    (NSArray*) allPick : (NSArray*) allSlid : (NSArray*) allText :
                    (NSArray*)noResetParams : (NSDictionary*)pickerChoices;
-(NSNumber*) getNumberForParam : (NSDictionary*)pDict : (NSString*)pname;

-(NSMutableDictionary*) randomizeFromVC  : (NSArray*) allP :
                    (NSArray*) allPick : (NSArray*) allSlid :
                    (NSArray*)noRandomizeParams;

@end


