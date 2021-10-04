//
//               _       _     ____                  _
//   _ __   __ _| |_ ___| |__ |  _ \ __ _ _ __   ___| |
//  | '_ \ / _` | __/ __| '_ \| |_) / _` | '_ \ / _ \ |
//  | |_) | (_| | || (__| | | |  __/ (_| | | | |  __/ |
//  | .__/ \__,_|\__\___|_| |_|_|   \__,_|_| |_|\___|_|
//  |_|
//
//  OogieCam patchPanel.h
//  
//  Redone by Dave Scruton on 9/28/21
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
@protocol patchPanelDelegate;

@interface patchPanel : UIView <UIGestureRecognizerDelegate,
                    UIPickerViewDelegate,UIPickerViewDataSource>
{
    int viewWid,viewHit,buttonWid,buttonHit;
    UIScrollView *scrollView;
    //Panels: universal,envelope,channels,gestures,midi
    UIView *header;
    UIView *uPanel,*ePanel,*cPanel,*mPanel,*ftPanel,*pkPanel;
    UIImageView *adsrImage;

    int uHit,eHit,cHit,mHit,ftHit,pkHit;
    UIButton *diceButton;
    UIButton *resetButton;
    UIButton *helpButton;
    UIButton *dismissButton;
    UIButton *goLeftButton;
    UIButton *goRightButton;

    NSArray *paAllParams;
    NSArray *paSliderNames;
    NSArray *paPickerNames;
    NSMutableArray *allSliders;
    NSMutableArray *allPickers;

    // Field data accumulator: tracks all activity in this session
    //  which is then used at dismiss time to save changes to edits
//    BOOL sliderChanged[MAX_PATCH_SLIDERS];
//    BOOL pickerChanged[MAX_PATCH_PICKERS];
//    int sChanges[MAX_PATCH_SLIDERS]; //session analytics:count the changes!
//    int pChanges[MAX_PATCH_PICKERS];

    int diceRolls;  //9/9 for analytics
    int resets;     //9/9 for analytics
    edits *paramEdits;
    // 8/12 FIX obPopup *obp; //onboarding popup panel
    // 8/12 FIX miniHelp *mhelp;
    // 8/12 FIX flurryAnalytics *fanal; //8/3
   // 8/12 fix? oogieVoice *startVoice; //8/21 for cancel
    soundFX *sfx; //8/27 for sample silencer
    BOOL diceUndo;
    BOOL rollingDiceNow,resettingNow;
    genOogie *goog;  //9/15

}


@property (nonatomic, unsafe_unretained) id <patchPanelDelegate> delegate;
@property (nonatomic, strong) NSString *patchName;
@property (nonatomic, strong) NSArray *sampleNames;
@property (nonatomic, strong) NSArray *outputNames;
@property (nonatomic, assign) int yTop; //9/14 cluge
@property (nonatomic, strong) NSMutableDictionary *oogieVoiceResultsDict;
// 8/12/21 fix? @property (nonatomic, strong) oogieVoice *ov;
@property (nonatomic, assign) BOOL wasEdited;
@property(nonatomic,assign)   BOOL isUp; //8/21
@property(nonatomic,assign)   BOOL randomized;
@property (nonatomic, strong) NSDictionary *paramDict;
@property(nonatomic,assign)   int whichSamp;


- (void)setupView:(CGRect)frame;
- (void) configureView;
- (void)updateSessionAnalytics; 


@end



@protocol patchPanelDelegate <NSObject>
@optional
-(void) didSetPatchValue  : (int) which : (float) newVal : (NSString*) pname : (NSString*) pvalue : (BOOL)undoable;
-(void) didSelectRight ;
-(void) didSelectLeft ;
-(void) didSelectPatchDice ;
-(void) didSelectPatchReset ;
-(void) didSelectPatchDismiss ; 
-(void) updateProModeInfo : (NSString*) infostr ;  //5/19
@end


