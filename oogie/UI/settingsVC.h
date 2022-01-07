//
//            _   _   _               __     ______
//   ___  ___| |_| |_(_)_ __   __ _ __\ \   / / ___|
//  / __|/ _ \ __| __| | '_ \ / _` / __\ \ / / |
//  \__ \  __/ |_| |_| | | | | (_| \__ \\ V /| |___
//  |___/\___|\__|\__|_|_| |_|\__, |___/ \_/  \____|
//                            |___/
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
    int liveMarkers;
    int haltAudio;
    int promptForDeletes;
    NSArray* noteOffsets;
}

@property (weak, nonatomic) IBOutlet UILabel *versionLabel;
@property (weak, nonatomic) IBOutlet UIView *headerView;

@property (weak, nonatomic) IBOutlet UISlider *tempoSlider;
@property (weak, nonatomic) IBOutlet UISlider *tuneSlider;
@property (weak, nonatomic) IBOutlet UILabel *tempoLabel;
@property (weak, nonatomic) IBOutlet UILabel *tuneLabel;
@property (weak, nonatomic) IBOutlet UIButton *resetButton;
@property (weak, nonatomic) IBOutlet UIButton *okButton;
@property (weak, nonatomic) IBOutlet UISwitch *statsSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *liveMarkersSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *haltAudioSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *verboseSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *promptForDeletesSwitch;

@property (nonatomic, assign) BOOL showStatistics; //for controlling sceneView stats, NOT saved 
@property (nonatomic, assign) BOOL verbose;        //12/9 debug output switch , pull for delivery!

@property (nonatomic, unsafe_unretained) id <settingsVCDelegate> delegate;


@end


@protocol settingsVCDelegate <NSObject>
@optional
-(void) settingsVCChanged;
-(void) didDismissSettingsVC;
-(void) didResetSettingsVC;
@end


