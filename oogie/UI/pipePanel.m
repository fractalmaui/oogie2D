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
//  Created by Dave Scruton on 9/14/20.
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//
// 9/24 remove swipe gesture,add dismiss button
// 10/1 redo with NSArrays instead of C-arrays
//  10/3 add indices to sliders/pickers
//  10/21 add delete button
// 10/29 close KB if panel closes, see lastSelectedTextField
// 10/30 add shouldChangeCharactersInRange delegate callback
// 11/29 cosmetic, add bottom bevel panel
// 12/6  add delay slider
// 12/15 pull which from didSetPipeValue delegate method
#import "pipePanel.h"

@implementation pipePanel

//======(pipePanel)==========================================
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
        lastSelectedTextField = nil; //indicate no select

        _outputNames = @[]; //start with something!
        _wasEdited = FALSE; //9/8
        sfx   = [soundFX sharedInstance];  //8/27
        diceUndo = FALSE; //7/9
        rollingDiceNow = resettingNow = FALSE;
    }
    return self;
} //end init

//======(pipePanel)==========================================
//10/1 new storage
-(void) setupCannedData
{
    if (allParams != nil) return; //only go thru once!
    //NSLog(@" setup canned pipe Param data...");
    allParams      = @[@"inputchannel",@"outputparam",@"lorange",@"hirange",@"invert",@"delay",@"name",@"comment"];
    sliderNames    = @[@"LoRange",@"HiRange",@"Delay"];
    pickerNames    = @[@"InputChannel",@"OutputParam",@"Invert"];
    textFieldNames = @[@"Name",@"Comments"];
    
    icParams = @[@"Red", @"Green", @"Blue", @"Hue",
                 @"Luminosity", @"Saturation", @"Cyan", @"Magenta", @"Yellow"];
    opParams = @[@"OPutput1", @"OPutput2", @"OPutput3"];
    
    inputChanParams = @[ @"Red", @"Green", @"Blue", @"Hue",
        @"Luminosity", @"Saturation", @"Cyan", @"Magenta", @"Yellow"];
    invertParams = @[@"Off", @"On"];

} //end setupCannedData


//======(pipePanel)==========================================
- (void) startAnimation
{
    animTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self
                       selector:@selector(animTimerTick:) userInfo:nil repeats:YES];
}

//======(pipePanel)==========================================
- (void)animTimerTick:(NSTimer *)timer
{
    //NSLog(@" anim bing");
    [self.delegate needPipeDataImage];
}

//======(pipePanel)==========================================
- (void) stopAnimation
{
    [animTimer invalidate];
}

//======(pipePanel)==========================================
- (void) setDataImage:(UIImage*) i
{
    //NSLog(@" setdataimage %@",i);
    if (dataImageView != nil) dataImageView.image = i;
}

//======(pipePanel)==========================================
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
    self.backgroundColor = [UIColor blueColor]; // 6/19/21 colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.1];
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
    [editLabel setBackgroundColor : [UIColor blueColor]];
    [editLabel setTextColor : [UIColor whiteColor]];
    [editLabel setFont:[UIFont fontWithName:@"Helvetica Neue" size: 22.0]]; //11/19
    editLabel.text = @"Edit Pipe";
    editLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview : editLabel];

    // 9/24 add dismiss button for oogieAR only
    dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [dismissButton setFrame:CGRectMake(xi,yi,xs,ys)];
    dismissButton.backgroundColor = [UIColor clearColor];
    [dismissButton addTarget:self action:@selector(dismissSelect:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:dismissButton];

    // 9/24 HEADER, top buttons and title info
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
    [titleLabel setFont:[UIFont fontWithName:@"Helvetica Neue" size: 22.0]];  //11/19
    titleLabel.text = @"Pipe";
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [header addSubview : titleLabel];
    
    xs = viewWid*0.2; //10/19 narrow help button
    xi = viewWid * 0.5 - xs*0.5;;
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
     [diceButton setImage:[UIImage imageNamed:@"bluedice.png"] forState:UIControlStateNormal];
     int inset = 4; //10/27 tiny dice!
     CGRect rr = CGRectMake(xi+inset, yi+inset, xs-2*inset, ys-2*inset);
     [diceButton setFrame:rr];
     [diceButton setTintColor:[UIColor grayColor]];
     [diceButton addTarget:self action:@selector(diceSelect:) forControlEvents:UIControlEventTouchUpInside];
     [header addSubview:diceButton];
    
    //10/21 add delete button top RL
    xs = OOG_HEADER_HIT * 0.8;
    ys = xs;
    xi = viewWid - ys - 3*OOG_XMARGIN; //LH side, note inset
    deleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [deleteButton setImage:[UIImage imageNamed:@"redx.png"] forState:UIControlStateNormal];
    [deleteButton setFrame:CGRectMake(xi,yi,xs,ys)];
    [deleteButton addTarget:self action:@selector(deleteSelect:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:deleteButton];
    
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
    
     
    //Add shape controls panel-------------------------------------
    xi = OOG_XMARGIN;
    yi = 60 + OOG_SLIDER_HIT;
    xs = viewWid-2*OOG_XMARGIN;
    ys = 9*OOG_SLIDER_HIT + 3*OOG_TEXT_HIT + 2*OOG_PICKER_HIT + 2*OOG_YMARGIN;
    //11/29 add rounded panel beneath our last panel , cosmetic
    UIView *bevelPanel = [[UIView alloc] init]; //name / comments panel...
    [bevelPanel setFrame : CGRectMake(xi,yi+20,xs,ys)]; //asdf
    bevelPanel.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1];
    bevelPanel.layer.cornerRadius = 20;
    bevelPanel.clipsToBounds      = TRUE;
    [scrollView addSubview:bevelPanel];
    //this is the panel controls are added to
    UIView *sPanel = [[UIView alloc] init];
    [sPanel setFrame : CGRectMake(xi,yi,xs,ys)];
    sPanel.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1];
    [scrollView addSubview:sPanel];
    
    //10/5 add data image, make slider height
    xi = OOG_XMARGIN;
    yi = xi; //top of panel
    xs = viewWid-3*OOG_XMARGIN;
    ys = 2*OOG_SLIDER_HIT;
    dataImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"empty64x64"]];
    [dataImageView setFrame:CGRectMake(xi,yi,xs,ys)];
    dataImageView.layer.borderWidth  = 2;
    dataImageView.layer.borderColor  = [UIColor darkGrayColor].CGColor;
    [sPanel addSubview:dataImageView];

    xi = OOG_XMARGIN;
    yi+= (ys+OOG_YSPACER); //skip down below last item
    // 2 pickers ... Input/Output
    [self addPickerRow:sPanel : iPicker : PICKER_BASE_TAG + iParam : pickerNames[iPicker] : yi : OOG_PICKER_HIT];
    yi +=  (OOG_PICKER_HIT+OOG_YSPACER);
    iPicker++;
    iParam++;
    [self addPickerRow:sPanel : iPicker : PICKER_BASE_TAG + iParam : pickerNames[iPicker] : yi : OOG_PICKER_HIT];
    yi +=  (OOG_PICKER_HIT+OOG_YSPACER);
    iPicker++;
    iParam++;

    // 2 Sliders... lo/hi range 9/22 make range 0..1
    [self addSliderRow:sPanel : iSlider : SLIDER_BASE_TAG + iParam : sliderNames[iSlider] : yi : OOG_SLIDER_HIT:0.0:1.0];
    yi += (OOG_SLIDER_HIT+OOG_YSPACER);
    iSlider++;
    iParam++;
    [self addSliderRow:sPanel : iSlider : SLIDER_BASE_TAG + iParam : sliderNames[iSlider] : yi : OOG_SLIDER_HIT:0.0:1.0];
    yi += (OOG_SLIDER_HIT+OOG_YSPACER);
    iSlider++;
    iParam++;
    // invert picker
    [self addPickerRow:sPanel : iPicker : PICKER_BASE_TAG + iParam : pickerNames[iPicker] : yi : OOG_PICKER_HIT];
    yi +=  (OOG_PICKER_HIT+OOG_YSPACER);
    iPicker++;
    iParam++;
    // 12/6 delay slider
    [self addSliderRow:sPanel : iSlider : SLIDER_BASE_TAG + iParam : sliderNames[iSlider] : yi : OOG_SLIDER_HIT:0.0:1.0];
    yi += (OOG_SLIDER_HIT+OOG_YSPACER);
    iSlider++;
    iParam++;

    // 2 text entry fields... name / comment 9/20 fix yoffset bug
    yi += (OOG_TEXT_HIT+OOG_YSPACER);
    [self addTextRow:sPanel :iText :TEXT_BASE_TAG + iParam : textFieldNames[iText] :yi :OOG_TEXT_HIT ];
    yi += (OOG_TEXT_HIT+OOG_YSPACER);
    iText++;
    iParam++;
    [self addTextRow:sPanel :iText :TEXT_BASE_TAG + iParam : textFieldNames[iText] :yi :OOG_TEXT_HIT ];
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
    int scrollHit = 650; //  11/29 shrink a bit
    //if (cappDelegate.gotIPad) scrollHit+=120; //3/27 ipad needs a bit more room
    scrollView.contentSize = CGSizeMake(viewWid, scrollHit);

} //end setupView

//======(pipePanel)==========================================
// 9/7 ignore slider moves!
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
      if ([touch.view isKindOfClass:[UISlider class]]) {
          return NO; // ignore the touch
      }
      return YES; // handle the touch
}

//======(pipePanel)==========================================
- (BOOL)prefersStatusBarHidden
{
    return YES;
}


//======(pipePanel)==========================================
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
        [allSliders addObject:slider];
    }
} //end addSliderRow

//======(pipePanel)==========================================
// 6/8 test slider with button...
-(NSArray*) addSliderButtonRow : (UIView*) parent : (int) tag : (NSString*) label :
                (UIImage*) buttonImage :
                (int) yoff : (int) width : (int) ysize :
                (float) smin : (float) smax
{
    int xs,ys,xi,yi;
    
    //get 3 columns...
    int x1 = 0.05 * width;
    int x2 = 0.30 * width;
    int x3 = 0.95 * width - ysize; //square button
    int x4 = 0.95 * width;

    xi = 0;
    yi = yoff;
    xs = width;
    ys = ysize;
    //9/15 everything lives in an UIView...
    UIView *sliderRow = [[UIView alloc] init];
    [sliderRow setFrame : CGRectMake(xi,yi,xs,ys)];
    sliderRow.backgroundColor = [UIColor clearColor]; //[UIColor colorWithRed:0.3 green:0 blue:0 alpha:1];
    [parent addSubview:sliderRow];

    xi = x1; //4/26
    yi = 0; //back to top left...
    UILabel *l = [[UILabel alloc] initWithFrame: //label goes from col 1 to 2
                  CGRectMake(xi,yi,xs,ys)];
    [l setTextColor : [UIColor whiteColor]];
    l.text = label;
    [sliderRow addSubview : l];
    
    xi = x2;
    xs = x3-x2;
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(xi,yi,xs,ys)];
    [slider setBackgroundColor:[UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1]];
    slider.minimumValue = 0.0;
    slider.minimumValue = smin;
    slider.maximumValue = smax;
    slider.continuous   = YES;
    slider.value        = (smin+smax)/2;
    slider.tag          = tag;
    [sliderRow addSubview:slider];
    
    xi = x3;
    xs = x4-x3;
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    [b setFrame:CGRectMake(xi,yi,xs,ys)];
    [b setImage:buttonImage forState:UIControlStateNormal];
    b.backgroundColor    = [UIColor clearColor];
    [sliderRow addSubview:b];
    
    return @[slider,b]; //maybe add more handles later?
} //end addSliderButtonRow

//======(pipePanel)==========================================
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
        //NSLog(@" add picker %@ at %d",picker,index);
        [allPickers addObject:picker];
    }
    
} //end addPickerRow

//======(pipePanel)==========================================
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


//======(pipePanel)==========================================
-(void) configureView
{
    [allPickers[1] reloadAllComponents]; //load pipe outputs, they may change over time
    NSString *s = @"no name"; //get voice name for title
    NSArray *a  = [_paramDict objectForKey:@"name"]; //extract the pipe name...
    if (a.count > 0) s = a.lastObject;
    titleLabel.text = s;
    [self configureViewWithReset : FALSE];
}

//======(pipePanel)==========================================
// This is huge. it should be made to work with any control panel!
-(void) configureViewWithReset : (BOOL)reset
{
    //CLEAN THIS UP: make allpar,allpic,allslid class members instead of arrays!
    NSArray *noresetparams = @[@"texture",@"name",@"comment"];
    NSMutableDictionary *pickerchoices = [[NSMutableDictionary alloc] init];
    [pickerchoices setObject:inputChanParams forKey:@0]; //output names (variable)
    [pickerchoices setObject:_outputNames forKey:@1]; //output names (variable)
    NSDictionary *resetDict = [goog configureViewFromVC:reset : _paramDict : allParams :
                     allPickers : allSliders : allTextFields :
               noresetparams : pickerchoices];
    if (reset) //reset? need to inform delegate of param changes...
    {
        [self sendUpdatedParamsToParent:resetDict];
    }
    
    resetButton.hidden = !_wasEdited;
    // 4/30 WTF? why wasnt this here earlier?
    //BOOL gotPro = (cappDelegate.proMode || cappDelegate.proModeDemo);
    proButton.hidden = TRUE; // 8/11 FIX gotPro;

} //end configureViewWithReset

//======(pipePanel)==========================================
// 9/18/21 Sends a limited set of updates to parent
-(void) sendUpdatedParamsToParent : (NSDictionary*) paramsDict
{
    for (NSString*key in paramsDict.allKeys)
    {
        NSArray *ra = paramsDict[key];
        NSNumber *nt = ra[0];
        NSNumber *nv = ra[1];
        NSString *ns = ra[2];
        [self.delegate didSetPipeValue :  nv.floatValue:key:ns:FALSE]; //12/15
    }
} //end sendUpdatedParamsToParent

//======(pipePanel)==========================================
// 9/18  make this generic too, and return a list of updates for delegate.
// THEN add a method to go thru the updates dict and pass to parent,
//    and reuse this method here and in configureView!
-(void) randomizeParams
{
    NSLog(@" RANDOMIZE PIPE");
    NSArray *norandomizeparams = @[@"texture",@"name",@"comment"];
    NSMutableDictionary *resetDict = [goog randomizeFromVC : allParams : allPickers : allSliders : norandomizeparams];
    [self sendUpdatedParamsToParent:resetDict];
    [self.delegate didSelectPipeDice]; //4/29
    diceRolls++; //9/9 for analytics
    diceUndo = FALSE;
    rollingDiceNow = FALSE;

} //end randomizeParams

//======(pipePanel)==========================================
-(void)sliderStoppedDragging:(id)sender
{
    [self updateSliderAndDelegateValue : sender : FALSE]; //9/23
}

//======(pipePanel)==========================================
-(void)sliderAction:(id)sender
{
    [self updateSliderAndDelegateValue : sender : FALSE]; //9/23
}

//======(pipePanel)==========================================
//called when slider is moved and on dice/resets!
-(void) updateSliderAndDelegateValue :(id)sender : (BOOL) dice
{
    if (!_wasEdited) {_wasEdited = TRUE; resetButton.hidden = FALSE;} //9/8 show reset button now!
    UISlider *slider = (UISlider*)sender;
    int tagMinusBase = ((int)slider.tag % 1000); // 7/11 new name
    float value = slider.value;
    NSString *name = dice ? @"" : allParams[tagMinusBase];
    [self.delegate didSetPipeValue: value:allParams[tagMinusBase]:name:TRUE];  //12/15
} //end updateSliderAndDelegateValue


//======(pipePanel)==========================================
- (IBAction)dismissSelect:(id)sender
{
    [lastSelectedTextField resignFirstResponder]; //10/29 Close keyboard if up
    [self.delegate didSelectPipeDismiss];
}


//======(pipePanel)==========================================
- (IBAction)helpSelect:(id)sender
{
    [self putUpOBHelpInstructions];
}

//======(pipePanel)==========================================
// 8/28 redo w/ bullet points
-(void) putUpOBHelpInstructions
{
    //if ( [cappDelegate getOnboardingFlag : OB_SILENCE_HELP] != 0) return; //No mini help?
// 8/11
//    obp.titleText       = mhelp.obLiveControlsTitle;
//    obp.blurb1Text      = mhelp.obLiveControlsBlurb1;
//    obp.blurb2Text      = mhelp.obLiveControlsBlurb2;
//    obp.bulletStrings   = mhelp.obLiveControlsBullets;
//    obp.obType          = 0; //type doesnt matter here
//    obp.hasBulletPoints = TRUE;
//    [obp update];
//    obp.yTop = _yTop; //9/14 CLUGE tell popup where it is on screen
//    [obp bounceIn];
}

//======(pipePanel)==========================================
- (void)LPGestureUndo:(UILongPressGestureRecognizer *)recognizer
{
    diceUndo = TRUE;   //7/9 handitoff to dice...
}

//======(pipePanel)==========================================
// 8/21 sets sliders directly and they report to parent,
//   pickers values have to be sent to parent here
- (IBAction)diceSelect:(id)sender
{
    [self randomizeParams];
} //end diceSelect

//======(pipePanel)==========================================
// 10/21 delete this pipe
- (IBAction)deleteSelect:(id)sender
{
    [self.delegate didSelectPipeDelete];
} //end deleteSelect



 
//======(pipePanel)==========================================
- (IBAction)resetSelect:(id)sender
{
    [self resetControls];
    //[self.delegate updateControlModeInfo : @"Reset F/X"]; //5/19
    [self.delegate didSelectPipeReset]; //7/11 for undo
}

//======(pipePanel)==========================================
// 4/3 reset called via button OR end of proMode demo
-(void) resetControls
{
    resettingNow       = TRUE; //used w/ undo
    [self configureViewWithReset: TRUE];
    _wasEdited         = FALSE;
    resetButton.hidden = TRUE;
    resettingNow       = FALSE;
} //end resetControls


//======(pipePanel)==========================================
- (NSString *)getPickerTitleForTagAndRow : (int)tag : (int)row
{
    //NSLog(@" pipes...get picker tag %d",tag);
    NSString *title = @"";
    if (tag == PICKER_BASE_TAG + 0) //input chans
    {
        title = inputChanParams[row];
    }
    else if (tag == PICKER_BASE_TAG + 1) // output names (variable)
    {
        title = _outputNames[row];
    }
    else if (tag == PICKER_BASE_TAG + 4) // output names (variable)
    {
        title = invertParams[row];
    }
   // NSLog(@" gptit %d %@",row,title);
    return title;
}

#pragma UIPickerViewDelegate
 
//-------<UIPickerViewDelegate>-----------------------------
// 6/18 redo
- (void)pickerView:(UIPickerView *)pickerView didSelectRow: (NSInteger)row inComponent:(NSInteger)component {
    if (!_wasEdited) {_wasEdited = TRUE; resetButton.hidden = FALSE;} //9/8 show reset button now!
    int liltag = (int)pickerView.tag % 1000;
    BOOL undoable = !rollingDiceNow && !resettingNow;
    NSString* fieldName = @""; //12/15 simplify
    if (liltag == 0)
        fieldName = inputChanParams[row];
    else if (liltag == 1)
        fieldName = _outputNames[row];
    else if (liltag == 4) // 10/5 invert picker
        fieldName = invertParams[row];
    [self.delegate didSetPipeValue: (float)row: allParams[liltag] :fieldName: undoable]; //12/15
}


//-------<UIPickerViewDelegate>-----------------------------
// tell the picker how many rows are available for a given component
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    int liltag = (int)pickerView.tag % 1000;
    //NSLog(@" get numrows for picker %d",liltag);
    if ( liltag == 0)  return 9; //input channels
    else if ( liltag == 1)  return _outputNames.count;
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
- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component {
 int sectionWidth = 150;
 
 return sectionWidth;
}


#pragma mark - UITextFieldDelegate

//==========<UITextFieldDelegate>====================================================
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    //NSLog(@" begin");
    [self.delegate didStartTextEntry:allParams[(textField.tag % 1000)]];  //10/30 pass field name
    lastSelectedTextField = textField; //10/29
    return YES;
}

//==========<UITextFieldDelegate>====================================================
// 10/30 for displaying text entry on mainVC, note string only contains EDITS
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    [self.delegate didChangeTextEntry:textField.text];  //pass text to parent
    return true;
}


//==========<UITextFieldDelegate>====================================================
- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    NSLog(@" clear");

    return YES;
}

//==========<UITextFieldDelegate>====================================================
// It is important for you to hide the keyboard
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    //NSLog(@" return");
    [textField resignFirstResponder]; //Close keyboard
    NSString *s = textField.text;
    int liltag = (int)textField.tag - TEXT_BASE_TAG;
    [self.delegate didSetPipeValue: 0.0: allParams[liltag] : s : FALSE];   //12/15
    // 9/21 take care of name update at top of menu
    if ([allParams[liltag] isEqualToString:@"name"]) titleLabel.text = s;
    return YES;
}



@end
