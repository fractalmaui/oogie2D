//               _       _    __     __ ____
//   _ __   __ _| |_ ___| |__ \ \   / // ___|
//  | '_ \ / _` | __/ __| '_ \ \ \ / /| |
//  | |_) | (_| | || (__| | | | \ V / | |___
//  | .__/ \__,_|\__\___|_| |_|  \_/   \____|
//  |_|
//
//  patchVC.h
//  oogie2D
//
//  Created by Dave Scruton on 12/13/21.
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//

#import <UIKit/UIKit.h>
#import "soundFX.h"
#import "patchPanel.h"
#import "edits.h"

@protocol patchVCDelegate;

 

@interface patchVC : UIViewController <UIPickerViewDelegate,UIPickerViewDataSource,patchPanelDelegate>
{
    patchPanel *paPanel;
    int note,oldnote,octave;
    int viewWid,viewHit;

    soundFX *sfx;
    NSArray* noteOffsets;
    NSString *patchName;
    edits *paramEdits;

}

@property (weak, nonatomic) IBOutlet UILabel *headerView;

@property (weak, nonatomic) IBOutlet UIPickerView *patchPicker;
@property (weak, nonatomic) IBOutlet UIPickerView *packPicker;
@property (weak, nonatomic) IBOutlet UIView *editView;
@property (weak, nonatomic) IBOutlet UIButton *resetButton;
@property (weak, nonatomic) IBOutlet UIButton *okButton;

@property (nonatomic, strong) NSArray *spNames;  //incoming data from parent...
@property (nonatomic, strong) NSArray *paNames;
@property (nonatomic, strong) NSArray *sampleNames;

@property (nonatomic, strong) NSDictionary *paramDict;
@property (nonatomic, strong) NSDictionary *patLookups;


@property (nonatomic, unsafe_unretained) id <patchVCDelegate> delegate;

-(void)configureView;
-(void) setPatchAndPackPickersFor: (NSString*)patchName : (NSString*)packName;


@end

@protocol patchVCDelegate <NSObject>
@optional
-(void) patchVCChangedWorkPatch;
-(void) patchVCChangedWorkPatch : (NSString*) pname : (float) newVal : (NSString*) newValString;
-(void) patchVCDidSetPatch : (NSString*) paname ;
-(void) patchVCDidSetPack  : (NSString*) spname ;
-(void) didDismissPatchVC;
-(void) didResetPatchVC;
-(void) patchVCDidAppear;
@end


 
