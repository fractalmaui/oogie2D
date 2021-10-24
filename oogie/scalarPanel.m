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
//  10/21 add delete button
#import "scalarPanel.h"

@implementation scalarPanel

//======(scalarPanel)==========================================
- (id)init
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        goog = [genOogie sharedInstance];
        allParams      = nil; // 10/1 new data structs
        sliderNames    = nil;
        pickerNames    = nil;
        textFieldNames = nil;
        allSliders     = [[NSMutableArray alloc] init];
        allPickers     = [[NSMutableArray alloc] init];
        allTextFields  = [[NSMutableArray alloc] init];
        
        _outputNames = @[]; //start with something!
        _wasEdited     = FALSE; //9/8
        diceUndo       = FALSE; //7/9
        rollingDiceNow = resettingNow = FALSE;
    }
    return self;
} //end init

//======(scalarPanel)==========================================
//10/15 note similarity to pipe...
-(void) setupCannedData
{
    if (allParams != nil) return; //only go thru once!
    //NSLog(@" setup canned pipe Param data...");
    allParams      = @[@"value",@"outputparam",@"lorange",@"hirange",@"invert",@"name",@"comment"];
    sliderNames    = @[@"value",@"LoRange",@"HiRange"];
    pickerNames    = @[@"OutputParam",@"Invert"];
    textFieldNames = @[@"Name",@"Comments"];
    
    opParams       = @[@"OPutput1", @"OPutput2", @"OPutput3"];
    invertParams   = @[@"Off", @"On"];
} //end setupCannedData


//======(scalarPanel)==========================================
-(void) setupView:(CGRect)frame
{
    [self setupCannedData];
    //Add rounded corners to this view
    self.layer.cornerRadius = OOG_MENU_CURVERAD;
    self.clipsToBounds      = TRUE;
    
    //9/20 Wow. we dont have a frame here!!! get width at least!
    CGSize screenSize   = [UIScreen mainScreen].bounds.size;
    viewWid = screenSize.width;
    viewHit = frame.size.height; //this is probably zero too!!!
    buttonWid = viewWid * 0.12; //10/4 REDO button height,scale w/width
    buttonHit = OOG_HEADER_HIT; //buttonWid;
    
    self.frame = frame;
    self.backgroundColor = [UIColor cyanColor];
    int xs,ys,xi,yi;
    
    int iSlider = 0; //10/3 keep slider / picker count
    int iPicker = 0;
    int iParam  = 0;
    int iText   = 0;
    
    xi = 0;
    yi = 0;
    xs = viewWid;
    ys = viewHit;
    scrollView = [[UIScrollView alloc] init];
    scrollView.frame = CGRectMake(xi,yi,xs,ys);
    scrollView.backgroundColor = [UIColor clearColor];
    scrollView.showsVerticalScrollIndicator = TRUE;
    [self addSubview:scrollView];
    
    xi = 0;
    yi = 0;
    xs = viewWid;
    ys = OOG_MENU_CURVERAD;
    UILabel *editLabel = [[UILabel alloc] initWithFrame:
                          CGRectMake(xi,yi,xs,ys)];
    [editLabel setBackgroundColor : [UIColor cyanColor]];
    [editLabel setTextColor : [UIColor blackColor]];
    [editLabel setFont:[UIFont fontWithName:@"Helvetica Neue" size: 28.0]];
    editLabel.text = @"Edit Scalar";
    editLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview : editLabel];
    // add dismiss button over edit label
    dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [dismissButton setFrame:CGRectMake(xi,yi,xs,ys)];
    dismissButton.backgroundColor = [UIColor clearColor];
    [dismissButton addTarget:self action:@selector(dismissSelect:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:dismissButton];
    
    //10/21 add delete button top RL
    xs = OOG_HEADER_HIT * 0.8;
    ys = xs;
    xi = viewWid - ys - 3*OOG_XMARGIN; //LH side, note inset
    deleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [deleteButton setImage:[UIImage imageNamed:@"redx.png"] forState:UIControlStateNormal];
    [deleteButton setFrame:CGRectMake(xi,yi,xs,ys)];
    [deleteButton addTarget:self action:@selector(deleteSelect:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:deleteButton];
    
    int panelSkip = 5; //Space between panels
    // HEADER, top buttons and title info
    xi = OOG_XMARGIN;
    yi = 30;
    xs = viewWid - 2*OOG_XMARGIN;
    ys = OOG_HEADER_HIT;  //7/9
    header = [[UIView alloc] init];
    header.frame = CGRectMake(xi,yi,xs,ys);
    header.backgroundColor = [UIColor blackColor];
    header.layer.shadowColor   = [UIColor blackColor].CGColor;
    header.layer.shadowOffset  = CGSizeMake(0,10);
    header.layer.shadowOpacity = 0.3;
    [self addSubview:header];
    
    // 8/4 add title and help button
    xi = 0;
    yi = 0;
    xs = viewWid;
    titleLabel = [[UILabel alloc] initWithFrame:
                  CGRectMake(xi,yi,xs,ys)];
    [titleLabel setTextColor : [UIColor whiteColor]];
    [titleLabel setFont:[UIFont fontWithName:@"Helvetica Neue" size: 32.0]];
    titleLabel.text = @"Scalar";
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [header addSubview : titleLabel];
    
    xs = viewWid*0.2; //10/19 narrow help button
    xi = viewWid * 0.5 - xs*0.5;
    helpButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [helpButton setFrame:CGRectMake(xi,yi,xs,ys)];
    helpButton.backgroundColor = [UIColor clearColor];
    [helpButton addTarget:self action:@selector(helpSelect:) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:helpButton];
    
    xs = buttonHit;
    ys = buttonHit;
    xi = OOG_XMARGIN;
    //9/3 add dice where helpbutton WAS
    diceButton = [UIButton buttonWithType:UIButtonTypeCustom];
    NSLog(@" NOTE we need cyan dice for scalar!");
    [diceButton setImage:[UIImage imageNamed:@"cyandice.png"] forState:UIControlStateNormal];
    int inset = 4; //10/27 tiny dice!
    CGRect rr = CGRectMake(xi+inset, yi+inset, xs-2*inset, ys-2*inset);
    [diceButton setFrame:rr];
    [diceButton setTintColor:[UIColor grayColor]];
    [diceButton addTarget:self action:@selector(diceSelect:) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:diceButton];
    
    //7/9 add longpress on dice for undo
    undoLPGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(LPGestureUndo:)];
    undoLPGesture.numberOfTouchesRequired = 1;
    undoLPGesture.delegate = self;
    undoLPGesture.cancelsTouchesInView = NO;
    [diceButton addGestureRecognizer:undoLPGesture];
    
    //Add reset button next to dice
    float borderWid = 5.0f;
    UIColor *borderColor = [UIColor whiteColor];
    xi += xs + 5;
    xs = buttonHit * 1.4; // 5/20 viewWid*0.15;
    resetButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [resetButton setTitle:@"Reset" forState:UIControlStateNormal];
    [resetButton setFrame:CGRectMake(xi, yi, xs, ys)];
    [resetButton setTitleColor:[UIColor colorWithRed:1 green:0.5 blue:0.5 alpha:1] forState:UIControlStateNormal];
    resetButton.backgroundColor    = [UIColor blackColor];
    resetButton.layer.cornerRadius = 10;
    resetButton.clipsToBounds      = TRUE;
    resetButton.layer.borderWidth  = borderWid;
    resetButton.layer.borderColor  = borderColor.CGColor;
    [resetButton addTarget:self action:@selector(resetSelect:) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:resetButton];
    
    
    //Add main controls panel-------------------------------------
    xi = OOG_XMARGIN;
    yi = 60; //skip down below edit area
    xs = viewWid-2*OOG_XMARGIN;
    ys = 8*OOG_SLIDER_HIT + 3*OOG_TEXT_HIT + 2*OOG_PICKER_HIT + 2*OOG_YMARGIN;
    UIView *mPanel = [[UIView alloc] init];
    [mPanel setFrame : CGRectMake(xi,yi,xs,ys)];
    mPanel.backgroundColor = [UIColor colorWithRed:0 green:0.5 blue:0.5 alpha:1];
    [scrollView addSubview:mPanel];
    
    xi = OOG_XMARGIN;
    //10/16 Add value slider
    [self addSliderRow:mPanel : iSlider : SLIDER_BASE_TAG + iParam : sliderNames[iSlider] : yi : OOG_SLIDER_HIT:0.0:1.0];
    yi += (OOG_SLIDER_HIT+OOG_YSPACER);
    iSlider++;
    iParam++;

    // 1 pickers ... Output
    [self addPickerRow:mPanel : iPicker : PICKER_BASE_TAG + iParam : pickerNames[iPicker] : yi : OOG_PICKER_HIT];
    yi +=  (OOG_PICKER_HIT+OOG_YSPACER);
    iPicker++;
    iParam++;
    
    // 2 Sliders... lo/hi range 9/22 make range 0..1
    [self addSliderRow:mPanel : iSlider : SLIDER_BASE_TAG + iParam : sliderNames[iSlider] : yi : OOG_SLIDER_HIT:0.0:1.0];
    yi += (OOG_SLIDER_HIT+OOG_YSPACER);
    iSlider++;
    iParam++;
    [self addSliderRow:mPanel : iSlider : SLIDER_BASE_TAG + iParam : sliderNames[iSlider] : yi : OOG_SLIDER_HIT:0.0:1.0];
    yi += (OOG_SLIDER_HIT+OOG_YSPACER);
    iSlider++;
    iParam++;
    // invert picker
    [self addPickerRow:mPanel : iPicker : PICKER_BASE_TAG + iParam : pickerNames[iPicker] : yi : OOG_PICKER_HIT];
    yi +=  (OOG_PICKER_HIT+OOG_YSPACER);
    iPicker++;
    iParam++;
    
    // 2 text entry fields... name / comment 9/20 fix yoffset bug
    yi += (OOG_TEXT_HIT+OOG_YSPACER);
    [self addTextRow:mPanel :iText :TEXT_BASE_TAG + iParam : textFieldNames[iText] :yi :OOG_TEXT_HIT ];
    yi += (OOG_TEXT_HIT+OOG_YSPACER);
    iText++;
    iParam++;
    [self addTextRow:mPanel :iText :TEXT_BASE_TAG + iParam : textFieldNames[iText] :yi :OOG_TEXT_HIT ];
    iText++;
    iParam++;
    
    UIView *vLabel = [[UIView alloc] init];
    xi = viewWid;
    yi = viewHit/2;
    xs = 30;
    ys = 120;
    [vLabel setFrame : CGRectMake(xi,yi,xs,ys)];
    
    vLabel.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1];
    [self addSubview:vLabel];
    
    //Scrolling area...
    int scrollHit = 450;
    //if (cappDelegate.gotIPad) scrollHit+=120; //3/27 ipad needs a bit more room
    scrollView.contentSize = CGSizeMake(viewWid, scrollHit);
    [self clearAnalytics];
    
} //end setupView

//======(scalarPanel)==========================================
//9/9 for session analytics
-(void) clearAnalytics
{
    //    //8/3 for session analytics: count activities
    //    diceRolls = 0; //9/9 for analytics
    //    resets    = 0; //9/9 for analytics
    //    for (int i=0;i<MAX_PIPE_SLIDERS;i++) sChanges[i] = 0;
    //    for (int i=0;i<MAX_PIPE_PICKERS;i++) pChanges[i] = 0;
}

//======(scalarPanel)==========================================
// 9/7 ignore slider moves!
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isKindOfClass:[UISlider class]]) {
        return NO; // ignore the touch
    }
    return YES; // handle the touch
}

//======(scalarPanel)==========================================
- (BOOL)prefersStatusBarHidden
{
    return YES;
}


//======(scalarPanel)==========================================
// 9/15 redo w/ genOogie method!
-(void) addSliderRow : (UIView*) parent : (int) index : (int) tag : (NSString*) label :
(int) yoff : (int) ysize : (float) smin : (float) smax
{
    NSArray* A = [goog addSliderRow : parent : tag : label :  yoff : viewWid: ysize :smin: smax];
    if (A.count > 0)
    {
        UISlider* slider = A[0];
        // hook it up to callbacks
        [slider addTarget:self action:@selector(sliderAction:) forControlEvents:UIControlEventValueChanged];
        [slider addTarget:self action:@selector(sliderStoppedDragging:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
        NSLog(@" add scalar slider %@ at %d",slider,index);
        [allSliders addObject:slider];
    }
} //end addSliderRow


//======(scalarPanel)==========================================
// adds a canned label/picker set...
-(void) addPickerRow : (UIView*) parent : (int) index : (int) tag : (NSString*) label : (int) yoff : (int) ysize
{
    //9/15 new UI element...
    NSArray* A = [goog addPickerRow : parent : tag : label : yoff : viewWid : ysize];
    if (A.count > 0)
    {
        UIPickerView * picker = A[0];
        picker.delegate   = self;
        picker.dataSource = self;
        NSLog(@" add scalar picker %@ at %d",picker,index);
        [allPickers addObject:picker];
    }
    
} //end addPickerRow

//======(scalarPanel)==========================================
// 9/11 textField... for oogie2D/AR
-(void) addTextRow : (UIView*) parent : (int) index : (int) tag : (NSString*) label :
(int) yoff : (int) ysize
{
    //9/15 new UI element...
    NSArray* A = [goog addTextRow : parent : tag : label : yoff : viewWid : ysize];
    if (A.count > 0)
    {
        UITextView * textField = A[0];
        textField.delegate     = self;
        [allTextFields addObject:textField];
    }
} //end addTextRow


//======(scalarPanel)==========================================
-(void) configureView
{
    [allPickers[0] reloadAllComponents]; //load scalar outputs, they may change over time
    NSString *s = @"no name"; //get voice name for title
    NSArray *a  = [_paramDict objectForKey:@"name"]; //extract the scalar name...
    if (a.count > 0) s = a.lastObject;
    titleLabel.text = s;
    [self configureViewWithReset : FALSE];
}

//======(scalarPanel)==========================================
-(void) configureViewWithReset : (BOOL)reset
{
    //CLEAN THIS UP: make allpar,allpic,allslid class members instead of arrays!
    NSArray *noresetparams = @[@"name",@"comment"];
    NSMutableDictionary *pickerchoices = [[NSMutableDictionary alloc] init];
    [pickerchoices setObject:_outputNames forKey:@0]; //output names (variable)
    NSDictionary *resetDict = [goog configureViewFromVC:reset : _paramDict : allParams :
                                            allPickers : allSliders : allTextFields :
                                         noresetparams : pickerchoices];
    if (reset) //reset? need to inform delegate of param changes...
    {
        [self sendUpdatedParamsToParent:resetDict];
    }
    resetButton.hidden = !_wasEdited;
} //end configureViewWithReset

//======(scalarPanel)==========================================
// 9/18/21 Sends a limited set of updates to parent
-(void) sendUpdatedParamsToParent : (NSDictionary*) paramsDict
{
    for (NSString*key in paramsDict.allKeys)
    {
        NSArray *ra = paramsDict[key];
        NSNumber *nt = ra[0];
        NSNumber *nv = ra[1];
        NSString *ns = ra[2];
        [self.delegate didSetScalarValue : nt.intValue : nv.floatValue:key:ns:FALSE];
    }
} //end sendUpdatedParamsToParent

//======(scalarPanel)==========================================
// 9/18  make this generic too, and return a list of updates for delegate.
// THEN add a method to go thru the updates dict and pass to parent,
//    and reuse this method here and in configureView!
-(void) randomizeParams
{
    NSLog(@" RANDOMIZE SCALAR");
    NSArray *norandomizeparams = @[@"name",@"comment"];
    NSMutableDictionary *resetDict = [goog randomizeFromVC : allParams : allPickers : allSliders : norandomizeparams];
    [self sendUpdatedParamsToParent:resetDict];
    [self.delegate didSelectScalarDice]; //4/29
    diceRolls++; //9/9 for analytics
    diceUndo = FALSE;
    rollingDiceNow = FALSE;
    
} //end randomizeParams

//======(scalarPanel)==========================================
// 8/3 update session analytics here..
-(void)sliderStoppedDragging:(id)sender
{
    [self updateSliderAndDelegateValue : sender : FALSE]; //9/23
}

//======(scalarPanel)==========================================
-(void)sliderAction:(id)sender
{
    [self updateSliderAndDelegateValue : sender : FALSE]; //9/23
}

//======(scalarPanel)==========================================
//called when slider is moved and on dice/resets!
-(void) updateSliderAndDelegateValue :(id)sender : (BOOL) dice
{
    if (!_wasEdited) {_wasEdited = TRUE; resetButton.hidden = FALSE;} //9/8 show reset button now!
    UISlider *slider = (UISlider*)sender;
    int tagMinusBase = ((int)slider.tag % 1000); // 7/11 new name
    float value = slider.value;
    NSString *name = dice ? @"" : allParams[tagMinusBase];
    [self.delegate didSetScalarValue:tagMinusBase:value:allParams[tagMinusBase]:name:TRUE];
} //end updateSliderAndDelegateValue


//======(scalarPanel)==========================================
- (IBAction)dismissSelect:(id)sender
{
    [self.delegate didSelectScalarDismiss];
}


//======(scalarPanel)==========================================
- (IBAction)helpSelect:(id)sender
{
    [self putUpOBHelpInstructions];
}

//======(scalarPanel)==========================================
// TBD STUB
-(void) putUpOBHelpInstructions
{
}

//======(scalarPanel)==========================================
- (void)LPGestureUndo:(UILongPressGestureRecognizer *)recognizer
{
    diceUndo = TRUE;   //7/9 handitoff to dice...
}

//======(scalarPanel)==========================================
// 8/21 sets sliders directly and they report to parent,
//   pickers values have to be sent to parent here
- (IBAction)diceSelect:(id)sender
{
    [self randomizeParams];
} //end diceSelect

//======(scalarPanel)==========================================
// 10/21 delete this scalar 
- (IBAction)deleteSelect:(id)sender
{
    [self.delegate didSelectScalarDelete];
} //end diceSelect

//====(OOGIECAM MainVC)============================================
//-(void) deleteScalarPrompt
//{
//    NSString *title = @"Delete Selected Scalar";
//    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:
//                                            title];
//    [tatString addAttribute : NSForegroundColorAttributeName value:[UIColor blackColor]
//                       range:NSMakeRange(0, tatString.length)];
//    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:30]
//                      range:NSMakeRange(0, tatString.length)];
//    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
//                                NSLocalizedString(title,nil)
//                                message:@"Scalar will be permanently removed"
//                                preferredStyle:UIAlertControllerStyleAlert];
//    [alert setValue:tatString forKey:@"attributedTitle"];
//    alert.view.tintColor = [UIColor blackColor]; //lightText, works in darkmode
//
//    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil)
//                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
//        [self delegate didSelectScalarDelete];
//                                              }]];
//    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
//                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
//                                              }]];
//    [self presentViewController:alert animated:YES completion:nil];
//
//} //end errorMessage



//======(scalarPanel)==========================================
- (IBAction)resetSelect:(id)sender
{
    [self resetControls];
    [self.delegate didSelectScalarReset]; //7/11 for undo
}

//======(scalarPanel)==========================================
// 4/3 reset called via button OR end of proMode demo
-(void) resetControls
{
    resettingNow       = TRUE; //used w/ undo
    [self configureViewWithReset: TRUE];
    _wasEdited         = FALSE;
    resetButton.hidden = TRUE;
    resettingNow       = FALSE;
} //end resetControls

//======(scalarPanel)==========================================
//TBD STUB
-(void)updateSessionAnalytics
{
} //end updateSessionAnalytics

//======(scalarPanel)==========================================
- (NSString *)getPickerTitleForTagAndRow : (int)tag : (int)row
{
    NSString *title = @"";
    if (tag == PICKER_BASE_TAG + 1) //input chans
    {
        title = _outputNames[row];
    }
    else if (tag == PICKER_BASE_TAG + 4) // invert picker
    {
        title = invertParams[row];
    }
    return title;
}

#pragma UIPickerViewDelegate

//-------<UIPickerViewDelegate>-----------------------------
// 6/18 redo
- (void)pickerView:(UIPickerView *)pickerView didSelectRow: (NSInteger)row inComponent:(NSInteger)component {
    if (!_wasEdited) {_wasEdited = TRUE; resetButton.hidden = FALSE;} //9/8 show reset button now!
    int liltag = (int)pickerView.tag % 1000;
    BOOL undoable = !rollingDiceNow && !resettingNow;
    if (liltag == 1)
        [self.delegate didSetScalarValue:liltag :(float)row: allParams[liltag] :_outputNames[row]: undoable];
    else if (liltag == 4) // 10/5 invert picker
        [self.delegate didSetScalarValue:liltag :(float)row: allParams[liltag] :invertParams[row]: undoable];
}


//-------<UIPickerViewDelegate>-----------------------------
// tell the picker how many rows are available for a given component
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    int liltag = (int)pickerView.tag % 1000;
    //NSLog(@" get numrows for picker %d",liltag);
    if ( liltag == 1)  return _outputNames.count;
    else if ( liltag == 4)  return invertParams.count;
    return 0; //empty (failed above test?)
}

//-------<UIPickerViewDelegate>-----------------------------
// tell the picker how many components it will have
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

//-------<UIPickerViewDelegate>-----------------------------
- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view{
    UILabel* tView = (UILabel*)view;
    if (!tView){
        tView = [[UILabel alloc] init];
        // Setup label properties - frame, font, colors etc
        tView.frame = CGRectMake(0,0,200,15); //5/24 shrink vertically
        [tView setFont:[UIFont fontWithName:@"Helvetica Neue" size: 16.0]];
    }
    // Fill the label text here
    tView.text = [self getPickerTitleForTagAndRow:(int)pickerView.tag:(int)row];
    return tView;
} //end viewForRow

//-------<UIPickerViewDelegate>-----------------------------
// 5/24 shrink picker rows more to make neighbors visible
- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component
{
    return 15;
}


//-------<UIPickerViewDelegate>-----------------------------
// tell the picker the width of each row for a given component
- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component
{
    return 150;
}


#pragma mark - UITextFieldDelegate

//==========<UITextFieldDelegate>====================================================
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    return YES;
}

//==========<UITextFieldDelegate>====================================================
- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    return YES;
}

//==========<UITextFieldDelegate>====================================================
// It is important for you to hide the keyboard
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder]; //Close keyboard
    NSString *s = textField.text;
    int liltag = (int)textField.tag - TEXT_BASE_TAG;
    [self.delegate didSetScalarValue:liltag :0.0: allParams[liltag] : s : FALSE];   //9/20
    // 9/21 take care of name update at top of menu
    if ([allParams[liltag] isEqualToString:@"name"]) titleLabel.text = s;
    return YES;
}



@end
