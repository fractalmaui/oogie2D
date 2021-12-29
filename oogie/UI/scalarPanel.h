//
//                 _            ____                  _
//   ___  ___ __ _| | __ _ _ __|  _ \ __ _ _ __   ___| |
//  / __|/ __/ _` | |/ _` | '__| |_) / _` | '_ \ / _ \ |
//  \__ \ (_| (_| | | (_| | |  |  __/ (_| | | | |  __/ |
//  |___/\___\__,_|_|\__,_|_|  |_|   \__,_|_| |_|\___|_|
//
//  OogieCam scalarPanel
//  
//  Created by Dave Scruton on 10/15/21
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "genOogie.h"
#import "oogieStyles.h"
#import "soundFX.h"
@protocol scalarPanelDelegate;

#define MAX_SCALAR_TEXTFIELDS 2
@interface scalarPanel : UIView <UIGestureRecognizerDelegate,UITextFieldDelegate,UITextViewDelegate,
                            UIPickerViewDelegate,UIPickerViewDataSource>
{
    int viewWid,viewHit,buttonWid,buttonHit;
    UIScrollView *scrollView;
    UIButton *resetButton;
    UIButton *helpButton;
    UIButton *diceButton;

    UIImageView *dataImageView;

    UIButton *loNotebutton;
    UIButton *hiNotebutton;
    UIButton *dismissButton;
    UIButton *deleteButton;
    UITextField *lastSelectedTextField; //10/29

    UITextField *ptextFields[MAX_SCALAR_TEXTFIELDS];
    UIView *header,*footer;
    UILabel *titleLabel;

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
    
    UILongPressGestureRecognizer *undoLPGesture;
    BOOL diceUndo;
    BOOL rollingDiceNow,resettingNow;
    genOogie *goog;  //9/15
    NSTimer *animTimer;
    
}


@property (nonatomic, unsafe_unretained) id <scalarPanelDelegate> delegate; // receiver of completion messages

@property (nonatomic, assign) BOOL wasEdited;
@property (nonatomic, strong) NSDictionary *paramDict;
@property (nonatomic, strong) NSArray *outputNames;

- (void) setupView:(CGRect)frame;
- (void) configureView;
//- (void) updateSessionAnalytics;

@end

@protocol scalarPanelDelegate <NSObject>
@optional
-(void) didSetScalarValue  : (float) newVal : (NSString*) pname : (NSString*) pvalue : (BOOL)undoable;
-(void) didSelectScalarDice ;
-(void) didSelectScalarReset ;
-(void) didSelectScalarDismiss ; //9/24
-(void) didSelectScalarDelete ; //10/21
-(void) didStartTextEntry : (NSString*) pname; //10/30
-(void) didChangeTextEntry : (NSString*) pname;

@end

