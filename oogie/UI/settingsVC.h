//
//  settingsVC.h
//  oogieCam
//
//  Created by Dave Scruton on 11/21/21
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "sampleCell.h"
#import "soundFX.h"

@protocol settingsVCDelegate;

@interface settingsVC : UIViewController
{
    int viewWid,viewHit,buttonWid,buttonHit;
    int tempo,tune;
    soundFX *sfx;
    int note,oldnote,octave;
    NSArray* noteOffsets;
}
@property (weak, nonatomic) IBOutlet UISlider *tempoSlider;
@property (weak, nonatomic) IBOutlet UISlider *tuneSlider;
@property (weak, nonatomic) IBOutlet UILabel *tempoLabel;
@property (weak, nonatomic) IBOutlet UILabel *tuneLabel;
@property (weak, nonatomic) IBOutlet UIButton *resetButton;
@property (weak, nonatomic) IBOutlet UIButton *okButton;
@property (weak, nonatomic) IBOutlet UISwitch *statsSwitch;

@property (nonatomic, assign) BOOL showStatistics; //for controlling sceneView stats, NOT saved 

@property (nonatomic, unsafe_unretained) id <settingsVCDelegate> delegate;


@end


@protocol settingsVCDelegate <NSObject>
@optional
-(void) settingsVCChanged;
@end


