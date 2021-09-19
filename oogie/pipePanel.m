//  OogieCam pipePanel
//
//  Created by Dave Scruton on 9/14/20.
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.



#import "pipePanel.h"
//#import "AppDelegate.h" //KEEP this OUT of viewController.h!!

@implementation pipePanel

#define NORMAL_CONTROLS
#define GOT_DIGITALDELAY

double drand(double lo_range,double hi_range );

//let pipeParamNames : [String] = ["InputChannel", "OutputParam","LoRange","HiRange","Name","Comment"]
NSString *pallParams[] = {@"inputchannel",@"outputparam",@"lorange",@"hirange",@"name",@"comment"
};
#define P_ALLPARAMCOUNT 6  //should batch pallParams above


NSString *inputChanParams [] = { @"Red", @"Green", @"Blue", @"Hue",
    @"Luminosity", @"Saturation", @"Cyan", @"Magenta", @"Yellow"};
#define P_INPUTCHANCOUNT 9  //should batch pallParams above

//pipe has 2 pickers, 2 sliders, and 2 texts
NSString *pisliderNames[] = {@"LoRange",@"HiRange"};
NSString *pipickerNames[] = {@"InputChannel",@"OutputParam"};
NSString *pitextFieldNames[] = {@"Name",@"Comments"};

//for analytics use: simple 3 letter keys for all controls
//  first char indicates UI, then 2 letters for control
// sliders are grouped: 3 at top, then a picker, then four more.
/// 9/12 do i need padding after SRO???
NSString *pisliderKeys[] = {@"ILR",@"IHR"};
NSString *pipickerKeys[] = {@"IIC",@"IOP"};

NSArray *icParams;
NSArray *opParams;




//======(pipePanel)==========================================
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {

      //  cappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        // 9/15 add UI utilities
        goog = [genOogie sharedInstance];
        [self setupView:frame];
        //8/3 flurry analytics
        //8/11 FIX fanal = [flurryAnalytics sharedInstance];
        _outputNames = @[]; //start with something!
        _wasEdited = FALSE; //9/8
        sfx   = [soundFX sharedInstance];  //8/27
        diceUndo = FALSE; //7/9
        rollingDiceNow = resettingNow = FALSE;
        
        icParams = @[@"Red", @"Green", @"Blue", @"Hue",
                     @"Luminosity", @"Saturation", @"Cyan", @"Magenta", @"Yellow"];
        opParams = @[@"OPutput1", @"OPutput2", @"OPutput3"];

    }
    return self;
}


//======(pipePanel)==========================================
-(void) setupView:(CGRect)frame
{
    viewWid    = frame.size.width;
    viewHit    = frame.size.height;
//    buttonWid  = viewHit * 0.07; //9/8 vary by viewhit, not wid
//    buttonHit  = buttonWid;
    buttonWid = viewWid * 0.12; //10/4 REDO button height,scale w/width
   // if (cappDelegate.gotIPad) //12/11 smaller buttons on ipad!
   //     buttonWid = viewWid * 0.06;  // ...by half?
    buttonHit = OOG_HEADER_HIT; //buttonWid;
    
    self.frame = frame;
    self.backgroundColor = [UIColor redColor]; // 6/19/21 colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.1];
    int xs,ys,xi,yi;
    
    xi = 0;
    yi = 0;
    xs = viewWid;
    ys = viewHit;
    scrollView = [[UIScrollView alloc] init];
    scrollView.frame = CGRectMake(xi,yi,xs,ys);
    scrollView.backgroundColor = [UIColor clearColor];
    scrollView.showsVerticalScrollIndicator = TRUE;
    [self addSubview:scrollView];
    
    // Add L/R swipe detect...
    UISwipeGestureRecognizer *swipeRGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeGestureDetected:)];
    swipeRGesture.direction = 1; //RIGHT
    swipeRGesture.delegate  = self; //9/7 for checking gestures
    [scrollView addGestureRecognizer:swipeRGesture];
    UISwipeGestureRecognizer *swipeLGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeGestureDetected:)];
    swipeLGesture.direction = 2; //LEFT
    swipeLGesture.delegate  = self; //9/7 for checking gestures
    [scrollView addGestureRecognizer:swipeLGesture];

    int panelSkip = 5; //Space between panels
    int i=0; //6/8

    // 9/24 HEADER, top buttons and title info
    xi = OOG_XMARGIN;
    yi = 0;
    xs = viewWid - 2*OOG_XMARGIN;
    ys = OOG_HEADER_HIT;  //7/9
    header = [[UIView alloc] init];
    header.frame = CGRectMake(xi,yi,xs,ys);
    header.backgroundColor = [UIColor blackColor];
    header.layer.shadowColor   = [UIColor blackColor].CGColor;
    header.layer.shadowOffset  = CGSizeMake(0,10);
    header.layer.shadowOpacity = 0.3;
    [self addSubview:header];

    // 5/20 add footer for shadow at bottom??
    yi = viewHit;
    xi = 0;
    xs = viewWid;
    footer = [[UIView alloc] init];
    footer.frame = CGRectMake(xi,yi,xs,ys);
    footer.backgroundColor = [UIColor blackColor];
    footer.layer.shadowColor   = [UIColor blackColor].CGColor;
    footer.layer.shadowOffset  = CGSizeMake(0,-10);
    footer.layer.shadowOpacity = 0.3;
    [self addSubview:footer];
    
    // 8/4 add title and help button
    xi = 0;
    yi = 0;
    xs = viewWid;
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:
                   CGRectMake(xi,yi,xs,ys)];
    [titleLabel setTextColor : [UIColor whiteColor]];
    [titleLabel setFont:[UIFont fontWithName:@"Helvetica Neue" size: 32.0]];
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
#ifdef NEEDSHAPEMULTIPANELS
    //Left/Right switch UI buttons...
    xs = buttonHit;
    xi = viewWid - 2*OOG_XMARGIN - 2*xs;
    goLeftButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [goLeftButton setImage:[UIImage imageNamed:@"arrowLeft"] forState:UIControlStateNormal];
    [goLeftButton setFrame:CGRectMake(xi,yi, xs,ys)];
    [goLeftButton addTarget:self action:@selector(leftSelect:) forControlEvents:UIControlEventTouchUpInside];
    goLeftButton.enabled = FALSE;
    [header addSubview:goLeftButton];
    xi+=xs;
    goRightButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [goRightButton setImage:[UIImage imageNamed:@"arrowRight"] forState:UIControlStateNormal];
    [goRightButton setFrame:CGRectMake(xi,yi, xs,ys)];
    [goRightButton addTarget:self action:@selector(rightSelect:) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:goRightButton];
    //9/24 END header controls
#endif
    
    //Add shape controls panel-------------------------------------
    xi = OOG_XMARGIN;
    yi = 60;
    xs = viewWid-2*OOG_XMARGIN;
    ys = 8*OOG_SLIDER_HIT + 3*OOG_TEXT_HIT + OOG_PICKER_HIT + 2*OOG_YMARGIN;
    UIView *sPanel = [[UIView alloc] init];
    [sPanel setFrame : CGRectMake(xi,yi,xs,ys)];
    sPanel.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1];
    [scrollView addSubview:sPanel];
    
    xi = OOG_XMARGIN;
    yi = xi; //top of form

    // 2 pickers ... Input/Output
    [self addPickerRow:sPanel : 0 : PICKER_BASE_TAG+0 : pipickerNames[0] : yi : OOG_PICKER_HIT];
    yi +=  (OOG_PICKER_HIT+OOG_YSPACER);
    [self addPickerRow:sPanel : 1 : PICKER_BASE_TAG+1 : pipickerNames[1] : yi : OOG_PICKER_HIT];
    yi +=  (OOG_PICKER_HIT+OOG_YSPACER);

    // 2 Sliders... lo/hi range
    [self addSliderRow:sPanel : 0 : SLIDER_BASE_TAG + 2 : pisliderNames[0] : yi : OOG_SLIDER_HIT:0.0:255.0];
    yi += (OOG_SLIDER_HIT+OOG_YSPACER);
    [self addSliderRow:sPanel : 1 : SLIDER_BASE_TAG + 3 : pisliderNames[1] : yi : OOG_SLIDER_HIT:0.0:255.0];
    yi += (OOG_SLIDER_HIT+OOG_YSPACER);

    // 2 text entry fields... name / comment
    yi+=ys;
    [self addTextRow:sPanel :0 :TEXT_BASE_TAG+4 : pitextFieldNames[0] :yi :OOG_TEXT_HIT ];
    yi+=ys;
    [self addTextRow:sPanel :1 :TEXT_BASE_TAG+5 : pitextFieldNames[1] :yi :OOG_TEXT_HIT ];
    
    UIView *vLabel = [[UIView alloc] init];
    xi = viewWid;
    yi = viewHit/2;
    xs = 30;
    ys = 120;
    [vLabel setFrame : CGRectMake(xi,yi,xs,ys)];
    
    vLabel.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1];
    [self addSubview:vLabel];

    //Scrolling area...
    int scrollHit = 400; //8/12 760; //640;  //5/20 enlarged again asdf
    //if (cappDelegate.gotIPad) scrollHit+=120; //3/27 ipad needs a bit more room
    scrollView.contentSize = CGSizeMake(viewWid, scrollHit);
    [self clearAnalytics];

} //end setupView

//======(pipePanel)==========================================
//9/9 for session analytics
-(void) clearAnalytics
{
//    //8/3 for session analytics: count activities
//    diceRolls = 0; //9/9 for analytics
//    resets    = 0; //9/9 for analytics
//    for (int i=0;i<MAX_PIPE_SLIDERS;i++) sChanges[i] = 0;
//    for (int i=0;i<MAX_PIPE_PICKERS;i++) pChanges[i] = 0;
}
 
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
    //9/12 note we user smin/smax here
NSArray* A = [goog addSliderRow : parent : tag : pisliderNames[index] :
                                yoff : viewWid: ysize :smin: smax];
   if (A.count > 0)
      {
        UISlider* slider = A[0];
        // hook it up to callbacks
        [slider addTarget:self action:@selector(sliderAction:) forControlEvents:UIControlEventValueChanged];
        [slider addTarget:self action:@selector(sliderStoppedDragging:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
        sliders[index] = slider;
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




//-(NSArray*) addSliderButtonRow : (UIView*) parent : (int) tag : (NSString*) label :
//                (UIImage*) buttonImage : (nullable id)target :
//                (int) yoff : (int) width : (int) ysize :
//                (float) smin : (float) smax;


//======(pipePanel)==========================================
// adds a canned label/picker set...
-(void) addPickerRow : (UIView*) parent : (int) index : (int) tag : (NSString*) label : (int) yoff : (int) ysize
{
    //9/15 new UI element...
     NSArray* A = [goog addPickerRow : parent : tag : pipickerNames[index] :
                                  yoff : viewWid : ysize];
    if (A.count > 0)
    {
        UIPickerView * picker = A[0];
        picker.delegate   = self;
        picker.dataSource = self;
        pickers[index] = picker;
    }

} //end addPickerRow


//======(pipePanel)==========================================
// 9/11 textField... for oogie2D/AR
-(void) addTextRow : (UIView*) parent : (int) index : (int) tag : (NSString*) label :
                (int) yoff : (int) ysize
{
    //9/15 new UI element...
    NSArray* A = [goog addTextRow : parent : tag : pitextFieldNames[index] : yoff : viewWid : ysize];
   if (A.count > 0)
      {
          UITextView * textField = A[0];
          textField.delegate     = self;
          textFields[index]      = textField;
      }
} //end addSliderRow


//======(pipePanel)==========================================
-(void) configureView
{
    [pickers[1] reloadAllComponents]; //load pipe outputs, they may change over time
    [self configureViewWithReset : FALSE];
}

//======(pipePanel)==========================================
// This is huge. it should be made to work with any control panel!
-(void) configureViewWithReset : (BOOL)reset
{
    //CLEAN THIS UP: make allpar,allpic,allslid class members instead of arrays!
    NSMutableArray *allpar = [[NSMutableArray alloc] init];
    for (int i=0;i<P_ALLPARAMCOUNT;i++) [allpar addObject:pallParams[i]];
    NSMutableArray *allpick = [[NSMutableArray alloc] init];
    for (int i=0;i<MAX_PIPE_PICKERS;i++) if (pickers[i] != nil) [allpick addObject:pickers[i]];
    NSMutableArray *allslid = [[NSMutableArray alloc] init];
    for (int i=0;i<MAX_PIPE_SLIDERS;i++) if (sliders[i] != nil)  [allslid addObject:sliders[i]];
    NSMutableArray *alltext = [[NSMutableArray alloc] init];
    for (int i=0;i<MAX_PIPE_TEXTFIELDS;i++) if (textFields[i] != nil)  [alltext addObject:textFields[i]];
    NSArray *noresetparams = @[@"texture",@"name",@"comment"];
    NSMutableDictionary *pickerchoices = [[NSMutableDictionary alloc] init];
    NSMutableArray * inparams = [[NSMutableArray alloc] init];
    for (int i=0;i<P_INPUTCHANCOUNT;i++) [inparams addObject:inputChanParams[i]]; //pack to NSARRAY
    [pickerchoices setObject:inparams forKey:@0]; //output names (variable)
    [pickerchoices setObject:_outputNames forKey:@1]; //output names (variable)
    NSDictionary *resetDict = [goog configureViewFromVC:reset : _paramDict : allpar :
                     allpick : allslid : alltext :
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
        [self.delegate didSetPipeValue : nt.intValue : nv.floatValue:key:ns:FALSE];
    }
} //end sendUpdatedParamsToParent

//======(pipePanel)==========================================
// 9/18  make this generic too, and return a list of updates for delegate.
// THEN add a method to go thru the updates dict and pass to parent,
//    and reuse this method here and in configureView!
-(void) randomizeParams
{
    NSLog(@" RANDOMIZE PIPE");
    //CLEAN THIS UP: make allpar,allpic,allslid class members instead of arrays!
    NSMutableArray *allpar = [[NSMutableArray alloc] init];
    for (int i=0;i<P_ALLPARAMCOUNT;i++) [allpar addObject:pallParams[i]];
    NSMutableArray *allpick = [[NSMutableArray alloc] init];
    for (int i=0;i<MAX_PIPE_PICKERS;i++) if (pickers[i] != nil) [allpick addObject:pickers[i]];
    NSMutableArray *allslid = [[NSMutableArray alloc] init];
    for (int i=0;i<MAX_PIPE_SLIDERS;i++) if (sliders[i] != nil)  [allslid addObject:sliders[i]];
    NSArray *norandomizeparams = @[@"texture",@"name",@"comment"];

    NSMutableDictionary *resetDict = [goog randomizeFromVC : allpar : allpick : allslid : norandomizeparams];
    [self sendUpdatedParamsToParent:resetDict];

    [self.delegate didSelectPipeDice]; //4/29
    diceRolls++; //9/9 for analytics
    diceUndo = FALSE;
    rollingDiceNow = FALSE;

} //end randomizeParams

//======(pipePanel)==========================================
// 8/3 update session analytics here..
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
    NSString *name = dice ? @"" : pallParams[tagMinusBase];
    [self.delegate didSetPipeValue:tagMinusBase:value:pallParams[tagMinusBase]:name:TRUE];
} //end updateSliderAndDelegateValue


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
    [self configureViewWithReset: TRUE];
    resettingNow = TRUE; //used w/ undo
    _wasEdited         = FALSE;
    resetButton.hidden = TRUE;
    resettingNow       = FALSE;
} //end resetControls

//======(pipePanel)==========================================
//8/3
-(void)updateSessionAnalytics
{
    //NSLog(@" duh collected analytics for flurry");
//    for (int i=0;i<MAX_CONTROL_SLIDERS;i++)
//    {
//        if (sChanges[i] > 0) //report changes to analytics
//        {
//            //NSLog(@" slider[%d] %d",i,sChanges[i]);
//            //NSString *sname = pisliderKeys[i];
//            //8/11 FIX[fanal updateSliderCount:sname:sChanges[i]];
//        }
//    }
//    for (int i=0;i<MAX_CONTROL_PICKERS;i++)
//    {
//        if (pChanges[i] > 0) //report changes to analytics
//        {
//            //NSLog(@" picker[%d] %d",i,pChanges[i]);
//            //NSString *pname = pipickerKeys[i];
//            //8/11 FIX[fanal updatePickerCount:pname:pChanges[i]];
//        }
//    }
//    //8/11 FIX[fanal updateDiceCount : @"LDI" : diceRolls]; //9/9
//    //8/11 FIX [fanal updateMiscCount : @"LRE" : resets]; //9/9
//    [self clearAnalytics]; //9/9 clear for next session

} //end updateSessionAnalytics

//======(pipePanel)==========================================
- (NSString *)getPickerTitleForTagAndRow : (int)tag : (int)row
{
    //NSLog(@" get picker tag %d",tag);
    NSString *title = @"";
    if (tag == PICKER_BASE_TAG + 0) //input chans
    {
        title = inputChanParams[row];
    }
    if (tag == PICKER_BASE_TAG + 1) // output names (variable)
    {
        title = _outputNames[row];
    }

    return title;
}

#pragma UIPickerViewDelegate
 
//-------<UIPickerViewDelegate>-----------------------------
// 6/18 redo
- (void)pickerView:(UIPickerView *)pickerView didSelectRow: (NSInteger)row inComponent:(NSInteger)component {
    if (!_wasEdited) {_wasEdited = TRUE; resetButton.hidden = FALSE;} //9/8 show reset button now!
    int liltag = (int)pickerView.tag % 1000;
    if (liltag == 0)
        [self.delegate didSetPipeValue:liltag :(float)row: pallParams[liltag] : inputChanParams[row]: !rollingDiceNow && !resettingNow];
    else
        [self.delegate didSetPipeValue:liltag :(float)row: pallParams[liltag] :_outputNames[row]: !rollingDiceNow && !resettingNow];
    //8/3 update picker activity count
    int pMinusBase = (int)(pickerView.tag-PICKER_BASE_TAG);
    if (pMinusBase>=0 && pMinusBase<MAX_PIPE_PICKERS) pChanges[pMinusBase]++;
}


//-------<UIPickerViewDelegate>-----------------------------
// tell the picker how many rows are available for a given component
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    int tag = (int)pickerView.tag;
    if ( tag == PICKER_BASE_TAG)  return 9; //input channels
    else if ( tag == PICKER_BASE_TAG+1)  return _outputNames.count;
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

//==========ActivityVC=================================================================
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    NSLog(@" begin");
    return YES;
}

//==========ActivityVC=================================================================
- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    NSLog(@" clear");

    return YES;
}
//==========ActivityVC=================================================================
// It is important for you to hide the keyboard
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    NSLog(@" return");
    [textField resignFirstResponder]; //Close keyboard
    NSString *s = textField.text;
    int liltag = (int)textField.tag - TEXT_BASE_TAG;
    [self.delegate didSetPipeValue:liltag :0.0:s:@"": FALSE];
    return YES;
}



@end
