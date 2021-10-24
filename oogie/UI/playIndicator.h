//         _             ___           _ _           _
//   _ __ | | __ _ _   _|_ _|_ __   __| (_) ___ __ _| |_ ___  _ __
//  | '_ \| |/ _` | | | || || '_ \ / _` | |/ __/ _` | __/ _ \| '__|
//  | |_) | | (_| | |_| || || | | | (_| | | (_| (_| | || (_) | |
//  | .__/|_|\__,_|\__, |___|_| |_|\__,_|_|\___\__,_|\__\___/|_|
//  |_|            |___/
//
//  playIndicator.h
//  testOCR
//
//  Created by Dave Scruton on 1/30/21
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//

#import <UIKit/UIKit.h>


@interface playIndicator : UIView
{
    CGRect cframe;
    UIImageView *spView;
    UILabel *spLabel;
    int animTick;
    NSTimer *animTimer;
    int hvsize;
    int logoSize;
    BOOL spinning;
    int frameNum;
    NSMutableArray *frames;
}
@property (nonatomic, assign) int borderWidth;
@property (nonatomic, strong) UIColor *borderColor;
@property (nonatomic, strong) NSString *message;

-(void) start : (NSString *) ms;
-(void) stop;

@end

