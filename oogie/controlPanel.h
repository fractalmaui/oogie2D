//                   _             _ ____                  _
//    ___ ___  _ __ | |_ _ __ ___ | |  _ \ __ _ _ __   ___| |
//   / __/ _ \| '_ \| __| '__/ _ \| | |_) / _` | '_ \ / _ \ |
//  | (_| (_) | | | | |_| | | (_) | |  __/ (_| | | | |  __/ |
//   \___\___/|_| |_|\__|_|  \___/|_|_|   \__,_|_| |_|\___|_|
//
//  OogieCam controlPanel
//  
//  Created by Dave Scruton on 6/19/20.
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
//#import "flurryAnalytics.h"
//#import "miniHelp.h"
//#import "obPopup.h"
#import "genOogie.h"
#import "oogieStyles.h"
#import "soundFX.h"
@protocol controlPanelDelegate;

@interface controlPanel : UIView <UIGestureRecognizerDelegate,UITextFieldDelegate,UITextViewDelegate,
                            UIPickerViewDelegate,UIPickerViewDataSource>
{
    int viewWid,viewHit,buttonWid,buttonHit;
    UIScrollView *scrollView;
    UIButton *resetButton;
    UIButton *proButton; //hides pro controls
    UIButton *helpButton;
    UIButton *diceButton;
    UIButton *goLeftButton;
    UIButton *goRightButton;
    
    UIButton *loNotebutton;
    UIButton *hiNotebutton;
    UIButton *dismissButton;

    // 10/1 new data structs
    NSArray *allParams;
    NSArray *sliderNames;
    NSArray *pickerNames;
    NSArray *textFieldNames;
    NSMutableArray *allSliders;
    NSMutableArray *allPickers;
    NSMutableArray *allTextFields;
    
    NSArray *keySigs;
    NSArray *monoPoly;
    NSArray *musicalKeys;
    NSArray *vibratoWaves;
    NSArray *colorChannels;

    UIView *header,*footer;
    UILabel *titleLabel;

    int diceRolls;  //9/9 for analytics
    int resets;     //9/9 for analytics
//    int sChanges[MAX_CONTROL_SLIDERS]; //count the changes!
//    int pChanges[MAX_CONTROL_PICKERS];
    
    //flurryAnalytics *fanal; //8/3
    //obPopup *obp; //onboarding popup panel
    //miniHelp *mhelp;
    soundFX *sfx; //8/27 for sample silencer
    
    UILongPressGestureRecognizer *undoLPGesture;
    BOOL diceUndo;
    BOOL rollingDiceNow,resettingNow;
    genOogie *goog;  //9/15
}


@property (nonatomic, unsafe_unretained) id <controlPanelDelegate> delegate; // receiver of completion messages
@property(nonatomic,assign)   BOOL wasEdited;
// 9/1/21 soundpack / patch arrays
@property (nonatomic, strong) NSArray *spNames;
@property (nonatomic, strong) NSArray *paNames;
@property (nonatomic, strong) NSDictionary *paramDict;


-(void) setupView:(CGRect)frame;
- (void) configureView;
- (void)updateSessionAnalytics;


@end

@protocol controlPanelDelegate <NSObject>
@optional
-(void) didSetControlValue  : (int) which : (float) newVal : (NSString*) pname : (NSString*) pvalue : (BOOL)undoable;
-(void) didSelectRight ;
-(void) didSelectLeft ;  
-(void) controlNeedsProMode ;
-(void) didSelectControlDice ; //4/28
-(void) didSelectControlReset ; //7/11
-(void) didSelectControlDismiss ; //9/24
-(void) updateControlModeInfo : (NSString*) infostr ; //5/19

@end

