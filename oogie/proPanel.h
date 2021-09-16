//                   ____                  _
//   _ __  _ __ ___ |  _ \ __ _ _ __   ___| |
//  | '_ \| '__/ _ \| |_) / _` | '_ \ / _ \ |
//  | |_) | | | (_) |  __/ (_| | | | |  __/ |
//  | .__/|_|  \___/|_|   \__,_|_| |_|\___|_|
//  |_|
//
//  OogieCam proPanel.h
//  
//  Created by Dave Scruton on 6/19/20.
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "edits.h"
// 8/12 FIX #import "flurryAnalytics.h"
#import "genOogie.h"
// 8/12 FIX #import "miniHelp.h"
// 8/12 FIX #import "obPopup.h"
// 8/12 FIX #import "oogieVoice.h"
#import "oogieStyles.h"
#import "soundFX.h"
@protocol proPanelDelegate;

//8/12/21 WHERE DO I GET THIS FROM
#define MAX_CONTROL_SLIDERS 32

//leaving some room for expansion...
#define MAX_PRO_SLIDERS 32
#define MAX_PRO_PICKERS 16   //8/21 wups out of bounds!
#define SLIDER_BASE_TAG 1000
#define PICKER_BASE_TAG 2000
 //8/12/21 pulled obPopupDelegate
@interface proPanel : UIView <UIGestureRecognizerDelegate,
                    UIPickerViewDelegate,UIPickerViewDataSource>
{
    int viewWid,viewHit,buttonWid,buttonHit;
    UIScrollView *scrollView;
    //Panels: universal,envelope,channels,gestures,midi
    UIView *header,*footer;
    UIView *uPanel,*ePanel,*cPanel,*mPanel,*ftPanel,*pkPanel;
    UIImageView *adsrImage;

    int uHit,eHit,cHit,mHit,ftHit,pkHit;
    UIButton *diceButton;
    UIButton *goLeftButton;
    UIButton *goRightButton;
    UIButton *resetButton;
    UIButton *helpButton;
    UISlider *sliders[MAX_PRO_SLIDERS];
    UIPickerView *pickers[MAX_PRO_PICKERS];
    // Field data accumulator: tracks all activity in this session
    //  which is then used at dismiss time to save changes to edits
    BOOL sliderChanged[MAX_PRO_SLIDERS];
    BOOL pickerChanged[MAX_PRO_PICKERS];

    int diceRolls;  //9/9 for analytics
    int resets;     //9/9 for analytics
    int sChanges[MAX_PRO_SLIDERS]; //session analytics:count the changes!
    int pChanges[MAX_PRO_PICKERS];
    edits *paramEdits;
    // 8/12 FIX obPopup *obp; //onboarding popup panel
    // 8/12 FIX miniHelp *mhelp;
    // 8/12 FIX flurryAnalytics *fanal; //8/3
   // 8/12 fix? oogieVoice *startVoice; //8/21 for cancel
    soundFX *sfx; //8/27 for sample silencer
    genOogie *goog; //9/15

}


@property (nonatomic, unsafe_unretained) id <proPanelDelegate> delegate;
@property (nonatomic, strong) NSString *patchName;
@property (nonatomic, strong) NSArray *sampleNames;
@property (nonatomic, assign) int yTop; //9/14 cluge
@property (nonatomic, strong) NSDictionary *oogieVoiceDict;
@property (nonatomic, strong) NSMutableDictionary *oogieVoiceResultsDict;
// 8/12/21 fix? @property (nonatomic, strong) oogieVoice *ov;
@property (nonatomic, assign) BOOL wasEdited;
@property(nonatomic,assign)   BOOL isUp; //8/21
@property(nonatomic,assign)   BOOL randomized;


- (id)initWithFrame:(CGRect)frame;
- (void) configureView;
- (void)updateSessionAnalytics; 


@end



@protocol proPanelDelegate <NSObject>
@optional
-(void) didSetProValue  : (int) which : (float) newVal : (NSString*) pname : (BOOL)undoable;
-(void) didSelectRight ;
-(void) didSelectLeft ;
-(void) selectedFactoryReset;
-(void) updateProModeInfo : (NSString*) infostr ;  //5/19
@end


