//                             _       ____     _ _
//   ___  __ _ _ __ ___  _ __ | | ___ / ___|___| | |
//  / __|/ _` | '_ ` _ \| '_ \| |/ _ \ |   / _ \ | |
//  \__ \ (_| | | | | | | |_) | |  __/ |__|  __/ | |
//  |___/\__,_|_| |_| |_| .__/|_|\___|\____\___|_|_|
//                      |_|
//  Created by Dave Scruton on 8/27/20
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "playIndicator.h"


#define GCIMAGESIZE 96

@interface sampleCell : UITableViewCell
{
    playIndicator *pli;
    int viewWid,viewHit;
    int cellHit;
}

-(void) setPlayButtonHidden : (BOOL) hidden;
//@property (nonatomic, strong) UIImageView *swatch;
@property (nonatomic, strong) UILabel *title;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UILabel *sizeLabel;
@property (nonatomic, strong) UILabel *headerLabel;
@property (nonatomic, strong) UIButton *playButton;



@end
