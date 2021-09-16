//  OogieCam shapePanel
//  
//  Created by Dave Scruton on 9/12/20.
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
@protocol shapePanelDelegate;

#define MAX_CONTROL_SLIDERS 17  //2/19 add delay 3sliders
#define MAX_CONTROL_PICKERS 5
#define MAX_CONTROL_TEXTFIELDS 2
#define SLIDER_BASE_TAG 1000
#define PICKER_BASE_TAG 2000
#define TEXT_BASE_TAG 3000
 // obPopupDelegate,
@interface shapePanel : UIView <UIGestureRecognizerDelegate,UITextFieldDelegate,
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


@property (nonatomic, unsafe_unretained) id <shapePanelDelegate> delegate; // receiver of completion messages

@property (nonatomic, assign) BOOL wasEdited;

//Do i need this ? is it a pointer not a string?
@property (nonatomic, strong) NSString *texture;
@property (nonatomic, assign) int textNum;
@property (nonatomic, assign) int rotType;
@property (nonatomic, assign) double xPos;
@property (nonatomic, assign) double yPos;
@property (nonatomic, assign) double zPos;
@property (nonatomic, assign) double uCoord;
@property (nonatomic, assign) double vCoord;
@property (nonatomic, assign) double uScale;
@property (nonatomic, assign) double vScale;
@property (nonatomic, assign) double rotation;
@property (nonatomic, assign) double rotSpeed;
//
@property (nonatomic, strong) NSArray *texNames;
@property (nonatomic, strong) NSArray *paNames;
@property (nonatomic, strong) NSString *sname;
@property (nonatomic, strong) NSString *scomment;


- (id)initWithFrame:(CGRect)frame;
- (void) configureView;
- (void)updateSessionAnalytics;

@end

@protocol shapePanelDelegate <NSObject>
@optional
-(void) didSetShapeValue  : (int) which : (float) newVal : (NSString*) pname : (BOOL)undoable;
//-(void) didSelectRight ;
//-(void) didSelectLeft ;
//-(void) controlNeedsProMode ;
-(void) didSelectShapeDice ;
-(void) didSelectShapeReset ;
//-(void) updateControlModeInfo : (NSString*) infostr ; //5/19

@end

