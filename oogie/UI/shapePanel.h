//
//       _                      ____                  _
//   ___| |__   __ _ _ __   ___|  _ \ __ _ _ __   ___| |
//  / __| '_ \ / _` | '_ \ / _ \ |_) / _` | '_ \ / _ \ |
//  \__ \ | | | (_| | |_) |  __/  __/ (_| | | | |  __/ |
//  |___/_| |_|\__,_| .__/ \___|_|   \__,_|_| |_|\___|_|
//                  |_|
//
//  OogieCam shapePanel
//  
//  Created by Dave Scruton on 9/12/20.
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "genOogie.h"
#import "oogieStyles.h"
#import "soundFX.h"


@protocol shapePanelDelegate;

@interface shapePanel : UIView <UIGestureRecognizerDelegate,UITextFieldDelegate,UITextViewDelegate,
                            UIPickerViewDelegate,UIPickerViewDataSource>
{
    int viewWid,viewHit,buttonWid,buttonHit;
    UIScrollView *scrollView;
    UIButton *resetButton;
    UIButton *proButton; //hides pro controls
    UIButton *helpButton;
    UIButton *diceButton;
    UILabel *titleLabel;
    UIButton *dismissButton;
    UIButton *deleteButton;
    UIImageView *textureView;
    UIImageView *otView;
    UITextField *lastSelectedTextField; //10/29
    UIView *header,*footer;

    int topTexSlider;
    float ucoord,vcoord,uscale,vscale;
    
    NSArray *allParams;
    NSArray *sliderNames;
    NSArray *pickerNames;
    NSArray *wrapNames;
    NSArray *textFieldNames;
    NSMutableArray *allSliders;
    NSMutableArray *allPickers;
    NSMutableArray *allTextFields;
    NSArray *rotTypeParams;

    UIImageView *thumbView;
    UIImage *defaultImage;
    
    int diceRolls;  //9/9 for analytics
    int resets;     //9/9 for analytics
    soundFX *sfx; //8/27 for sample silencer
    
    UILongPressGestureRecognizer *undoLPGesture;
    BOOL diceUndo;
    BOOL rollingDiceNow,resettingNow;
    genOogie *goog;  //9/15
}


@property (nonatomic, unsafe_unretained) id <shapePanelDelegate> delegate; // receiver of completion messages

@property (nonatomic, assign) BOOL wasEdited;
@property (nonatomic, strong) NSDictionary *paramDict;
@property (nonatomic, strong) NSDictionary *thumbDict;
@property (nonatomic, strong) NSArray *texNames;
@property (nonatomic, strong) UIImage *texture;

-(void) setupView:(CGRect)frame;
- (void) configureView;
- (void) updateTextureDisplay;

@end

@protocol shapePanelDelegate <NSObject>
@optional
-(void) didSetShapeValue  :(float) newVal : (NSString*) pname : (NSString*) pvalue : (BOOL)undoable;
-(void) didSelectShapeDice ;
-(void) didSelectShapeReset ;
-(void) didSelectShapeDismiss ; //9/24
-(void) didSelectShapeDelete ; //10/21
-(void) didStartTextEntry : (NSString*) pname; //10/30
-(void) didChangeTextEntry : (NSString*) pname;

@end

