//
//         _            ____                  _
//   _ __ (_)_ __   ___|  _ \ __ _ _ __   ___| |
//  | '_ \| | '_ \ / _ \ |_) / _` | '_ \ / _ \ |
//  | |_) | | |_) |  __/  __/ (_| | | | |  __/ |
//  | .__/|_| .__/ \___|_|   \__,_|_| |_|\___|_|
//  |_|     |_|
//
//  OogieCam pipePanel
//  
//  Created by Dave Scruton on 9/12/20.
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "genOogie.h"
#import "oogieStyles.h"
#import "soundFX.h"
@protocol pipePanelDelegate;

@interface pipePanel : UIView <UIGestureRecognizerDelegate,UITextFieldDelegate,UITextViewDelegate,
                            UIPickerViewDelegate,UIPickerViewDataSource>
{
    int viewWid,viewHit,buttonWid,buttonHit;
    UIScrollView *scrollView;
    UIButton *resetButton;
    UIButton *proButton; //hides pro controls
    UIButton *helpButton;
    UIButton *diceButton;
    UITextField *lastSelectedTextField; //10/29

    UIImageView *dataImageView;

    UIButton *loNotebutton;
    UIButton *hiNotebutton;
    UIButton *dismissButton;
    UIButton *deleteButton;
    UIView   *header,*footer;
    UILabel  *titleLabel;

    // 10/1 new data structs
    NSArray *allParams;
    NSArray *sliderNames;
    NSArray *pickerNames;
    NSArray *textFieldNames;
    NSMutableArray *allSliders;
    NSMutableArray *allPickers;
    NSMutableArray *allTextFields;

    NSArray *icParams;
    NSArray *opParams;
    NSArray *inputChanParams;
    NSArray *invertParams;

    int diceRolls;  //9/9 for analytics
    int resets;     //9/9 for analytics
// ANALYTICS   int sChanges[MAX_PIPE_SLIDERS]; //count the changes!
//    int pChanges[MAX_PIPE_PICKERS];
    
    //flurryAnalytics *fanal; //8/3
    //obPopup *obp; //onboarding popup panel
    //miniHelp *mhelp;
    soundFX *sfx; //8/27 for sample silencer
    
    UILongPressGestureRecognizer *undoLPGesture;
    BOOL diceUndo;
    BOOL rollingDiceNow,resettingNow;
    genOogie *goog;  //9/15
    NSTimer *animTimer;
    
}

@property (nonatomic, unsafe_unretained) id <pipePanelDelegate> delegate; // receiver of completion messages

@property (nonatomic, assign) BOOL wasEdited;
@property (nonatomic, strong) NSDictionary *paramDict;
@property (nonatomic, strong) NSArray *outputNames;

- (void) setupView:(CGRect)frame;
- (void) configureView;
- (void) updateSessionAnalytics;
- (void) startAnimation;
- (void) stopAnimation;
- (void) setDataImage:(UIImage*) i;

@end

@protocol pipePanelDelegate <NSObject>
@optional
-(void) didSetPipeValue  : (float) newVal : (NSString*) pname : (NSString*) pvalue : (BOOL)undoable;
-(void) didSelectPipeDice ;
-(void) didSelectPipeReset ;
-(void) didSelectPipeDismiss ; //9/24
-(void) needPipeDataImage ; //10/24
//-(void) updateControlModeInfo : (NSString*) infostr ; //5/19
-(void) didSelectPipeDelete ; //10/21
-(void) didStartTextEntry : (NSString*) pname; //10/30
-(void) didChangeTextEntry : (NSString*) pname;

@end

