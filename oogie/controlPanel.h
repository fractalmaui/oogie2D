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

#define MAX_CONTROL_SLIDERS 17  //2/19 add delay 3sliders
#define MAX_CONTROL_PICKERS 5
#define MAX_CONTROL_TEXTFIELDS 2
#define SLIDER_BASE_TAG 1000
#define PICKER_BASE_TAG 2000
#define TEXT_BASE_TAG 3000
 // obPopupDelegate,
@interface controlPanel : UIView <UIGestureRecognizerDelegate,UITextFieldDelegate,
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

    UISlider *sliders[MAX_CONTROL_SLIDERS];
    UIPickerView *pickers[MAX_CONTROL_PICKERS];
    UITextField *textFields[MAX_CONTROL_TEXTFIELDS];
    UIView *header,*footer;

    int diceRolls;  //9/9 for analytics
    int resets;     //9/9 for analytics
    int sChanges[MAX_CONTROL_SLIDERS]; //count the changes!
    int pChanges[MAX_CONTROL_PICKERS];
    
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
@property (nonatomic, strong) NSString *vname;
@property (nonatomic, strong) NSString *vcomment;
@property (nonatomic, strong) NSDictionary *paramDict;


- (id)initWithFrame:(CGRect)frame;
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
-(void) updateControlModeInfo : (NSString*) infostr ; //5/19

@end

