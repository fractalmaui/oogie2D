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
// Sept 2021: Complete redo: now we get a dictionary of info for each param.
//                this is used to set current values, and defaults for reset.
//            The configure UI and randomize UI functions are now in genOogie...
//           
// 5/23  make pro button only on RH side, add enable/disble for bottom 6 sliders
// 5/24  shrink picker rows more to make neighbors visible
// 6/19  fix ppanel size bug
// 6/27  update dice to handle delay sliders
// 7/9   add oogieStyle
// 7/11  variable cleanup , hook up to undo, add undoable arg to didsetControlValue
// 8/11 MIGRATE to oogie2D> get rid of cappDelegate for now,
//         flurryAnalytics,miniHelp,obPopup
// 9/17 redo params to read input / defaults from incoming dictionary
// 9/18 add randomize, remove sendAllParamsToParent, add sendUpdatedParamsToParent
#import "controlPanel.h"
//#import "AppDelegate.h" //KEEP this OUT of viewController.h!!

@implementation controlPanel

#define NORMAL_CONTROLS
#define GOT_DIGITALDELAY


double drand(double lo_range,double hi_range );
 

//AppDelegate *cappDelegate;
NSString *sliderNames[] = {@"Threshold",@"Bottom Note",@"Top Note",
    @"padding",@"Overdrive",@"Portamento",
    @"FVib Level" ,@"FVib Speed" ,@"",
    @"AVib Level" ,@"AVib Speed",@"",   //4/7 add vibe
    @"Delay Time" ,@"Delay Sustain",@"Delay Mix",
    @"Latitude", @"Longitude"  //8/12 for oogie2D / oogieAR
}; //2/19 note paddings b4 delay for vibwave
//these must match tags which increment over all controls!

//3 sliders, a picker, 4 sliders, a picker, 2 sliders a picker then 5 sliders and 2 texts
NSString *allParams[] = {@"threshold",@"bottommidi",@"topmidi",@"keysig",
    @"level",@"portamento",   //is level OK here?
    @"viblevel" ,@"vibspeed",@"vibwave",
    @"vibelevel" ,@"vibespeed",@"vibewave",
    @"delaytime" ,@"delaysustain",@"delaymix",
    @"latitude", @"longitude",@"patch",@"soundpack",@"name",@"comment"
};
#define C_ALLPARAMCOUNT 21  //should batch allparams above

NSString *pickerNames[] = {@"KeySig",@"FVib Wave",@"AVib Wave",@"Patch",@"SoundPack"};

NSString *textFieldNames[] = {@"Name",@"Comments"};

//for analytics use: simple 3 letter keys for all controls
//  first char indicates UI, then 2 letters for control
// sliders are grouped: 3 at top, then a picker, then four more.
NSString *sliderKeys[] = {@"LTH",@"LBN",@"LTN",@"---",
                @"LOV",@"LPO",
                @"LVL",@"LVS",@"",
                @"LAL",@"LAS",@"",
                @"DET",@"DEF",@"DEM"}; //2/19 note padding b4 delay
NSString *pickerKeys[] = {@"LKS",@"LVW",@"LAW"};

// Strings used in pickers...
NSString *keys[] = {@"C",@"C#",@"D",@"D#",@"E",@"F",@"F#",@"G",@"G#",@"A",@"A#",@"B"};
NSString *keySigs[] = {@"Major",@"Minor",@"Lydian",@"Phrygian",
                       @"Mixolydian",@"Locrian",@"Egyptian",@"Hungarian",
                       @"Algerian",@"Japanese",@"Chinese",@"Chromatic"};
NSString *vibratoWaves[] = {@"Sine",@"Saw",@"Square",@"Ramp"}; //4/30 make so it matches order in SYNTH 



//======(controlPanel)==========================================
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {

      //  cappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        // 9/15 add UI utilities
        goog = [genOogie sharedInstance];
        _spNames = @[];
        _paNames = @[];

        [self setupView:frame];
        //8/3 flurry analytics
        //8/11 FIX fanal = [flurryAnalytics sharedInstance];

        // 8/12 add notification for ProMode demo...
        [[NSNotificationCenter defaultCenter]
                                addObserver: self selector:@selector(demoNotification:)
                                       name: @"demoNotification" object:nil];
        _wasEdited = FALSE; //9/8
        sfx   = [soundFX sharedInstance];  //8/27
        diceUndo = FALSE; //7/9
        rollingDiceNow = resettingNow = FALSE;
    }
    return self;
}


//======(controlPanel)==========================================
-(void) setupView:(CGRect)frame
{
    //9/20 Wow. we dont have a frame here!!! get width at least!
    CGSize screenSize   = [UIScreen mainScreen].bounds.size;
    viewWid = screenSize.width;
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
    titleLabel.text = @"Voice";
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
    
    //Add live controls panel-------------------------------------
    xi = OOG_XMARGIN;
    yi = 240; //9/10 account for new papanel... 60;
    xs = viewWid-2*OOG_XMARGIN;
    // 7/9 calculate height based on controls
    ys = 3*OOG_SLIDER_HIT + 2*OOG_TEXT_HIT + OOG_PICKER_HIT + 3*OOG_YSPACER + 2*OOG_YMARGIN;
    UIView *cPanel = [[UIView alloc] init];
    [cPanel setFrame : CGRectMake(xi,yi,xs,ys)];
    cPanel.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1];
    [scrollView addSubview:cPanel];
    xi = OOG_XMARGIN;
    yi = xi; //top of form
    // add threshold, lo/hi midi sliders
    for (i=0;i<3;i++)
    {
        [self addSliderRow:cPanel : i : SLIDER_BASE_TAG + i : sliderNames[i] : yi : OOG_SLIDER_HIT:0.0:1.0];
        yi += (OOG_SLIDER_HIT+OOG_YSPACER);
    }
    // add keysig picker
    [self addPickerRow:cPanel : 0 : PICKER_BASE_TAG+3 : pickerNames[0] : yi : OOG_PICKER_HIT];
    
    //Add pro mode controls panel-------------------------------------
    xi = OOG_XMARGIN;
    yi = cPanel.frame.origin.y + cPanel.frame.size.height + panelSkip; //6/27
    xs = viewWid - 2*OOG_XMARGIN;
    // 7/9 calculate height based on controls
    //  wouldnt it be nice to do this AFTER controls are created??
    ys = 11*OOG_SLIDER_HIT + 2*OOG_PICKER_HIT + 10*OOG_YSPACER + 2*OOG_YMARGIN;
    UIView *pPanel = [[UIView alloc] init];
    [pPanel setFrame : CGRectMake(xi,yi,xs,ys)];
    pPanel.backgroundColor = [UIColor colorWithRed:0.3 green:0.0 blue:0.0 alpha:1];
    [scrollView addSubview:pPanel];

    //Add label for pro mode controls
    yi = 10;
    //int ypro = yi;
    ys = OOG_SLIDER_HIT;
    xs = viewWid*0.9;
    UILabel *l3 = [[UILabel alloc] initWithFrame:
                   CGRectMake(xi,yi,xs,ys)];
    [l3 setTextColor : [UIColor whiteColor]];
    l3.text = @"Effects [Pro Mode]";
    [pPanel addSubview : l3];
    yi += (OOG_SLIDER_HIT+OOG_YSPACER);
    // add sliders for overdrive,portamento,viblevel,vibspeed
    for (i=0;i<4;i++) //add 4 fx sliders, overdrive, portamento, FVIB level/speed
    {
        NSString *dog = [NSString stringWithFormat:@"rowi %d",i];
        [self addSliderRow:pPanel : i+4 : SLIDER_BASE_TAG + i+4 : dog : yi : OOG_SLIDER_HIT:0.0:1.0];
        yi += (OOG_SLIDER_HIT+OOG_YSPACER);
    }
    // add picker for viblevel
    [self addPickerRow:pPanel : 1 : PICKER_BASE_TAG+8 : pickerNames[1] : yi : OOG_PICKER_HIT];
    yi += 2* (OOG_SLIDER_HIT+OOG_YSPACER);
    //4/7/21 add vibe level/spped
    for (i=0;i<2;i++) //add 2 fx sliders,  FVIB wave, AVIB level/speed
    {
        NSString *dog = [NSString stringWithFormat:@"rowi %d",i];
        [self addSliderRow:pPanel : i+9 : SLIDER_BASE_TAG + i+9 : dog : yi : OOG_SLIDER_HIT:0.0:1.0];
        yi += (OOG_SLIDER_HIT+OOG_YSPACER);
    }
    // add picker for viblevel
    [self addPickerRow:pPanel : 2 : PICKER_BASE_TAG+11 : pickerNames[2] : yi : OOG_PICKER_HIT];

#ifdef GOT_DIGITALDELAY
    yi += (OOG_PICKER_HIT+OOG_YSPACER);
    // 2/19/21 add 3 delay sliders
    for (i=0;i<3;i++)
    {
        NSString *dog = [NSString stringWithFormat:@"rowi %d",i];
        [self addSliderRow:pPanel : i+12 : SLIDER_BASE_TAG + i+12 : dog : yi : OOG_SLIDER_HIT:0.0:1.0];
        yi += (OOG_SLIDER_HIT+OOG_YSPACER);
    }
#endif

    
    xi = OOG_XMARGIN;
    //assume right below pPanel...
    yi = pPanel.frame.origin.y + pPanel.frame.size.height + panelSkip;
    xs = viewWid - 2*OOG_XMARGIN;
    ys = 3*OOG_SLIDER_HIT + 2*OOG_TEXT_HIT + 2*OOG_YMARGIN; // + 2*OOG_PICKER_HIT + 10*OOG_YSPACER ;
    UIView *llPanel = [[UIView alloc] init];
    [llPanel setFrame : CGRectMake(xi,yi,xs,ys)];
    llPanel.backgroundColor = [UIColor colorWithRed:0.0 green:0.4 blue:0.4 alpha:1];
    [scrollView addSubview:llPanel];

    //8/12 add stuff for oogie2D / oogieAR
    yi = OOG_YMARGIN;
    ys = OOG_SLIDER_HIT;
    // CHECK number, is it 15?? or 14? above were 3 sliders at 12...
    // 9/15 KRASH sending slider tag 15!
    [self addSliderRow:llPanel : 15 : SLIDER_BASE_TAG + 15 : @"Latitude (Y)" : yi :
        OOG_SLIDER_HIT: 0.0 : 1.0];
    yi+=ys;
    [self addSliderRow:llPanel : 16 : SLIDER_BASE_TAG + 16 : @"Longitude (X)" : yi :
        OOG_SLIDER_HIT:0.0 : 1.0];
    //9/11 text entry fields...9/20 fix yoffset bug
    yi += (OOG_SLIDER_HIT+OOG_YSPACER);
    [self addTextRow:llPanel :0 :TEXT_BASE_TAG+19 : textFieldNames[0] :yi :OOG_TEXT_HIT ];
    yi += (OOG_TEXT_HIT+OOG_YSPACER);
    [self addTextRow:llPanel :1 :TEXT_BASE_TAG+20 : textFieldNames[1] :yi :OOG_TEXT_HIT ];
    //9/1 new panel for patches at top...
    xi = OOG_XMARGIN;
    yi = 60;   // llPanel.frame.origin.y + llPanel.frame.size.height + panelSkip;
    xs = viewWid - 2*OOG_XMARGIN;
    ys = 180;
    UIView *paPanel = [[UIView alloc] init];
    
    [paPanel setFrame : CGRectMake(xi,yi,xs,ys)];
    paPanel.backgroundColor = [UIColor colorWithRed:0.41 green:0.41 blue:0.41 alpha:1];
    [scrollView addSubview : paPanel];
     
     
     yi = 10;
     //int ypro = yi;
     ys = OOG_SLIDER_HIT;
     xs = viewWid*0.9;
     UILabel *l4 = [[UILabel alloc] initWithFrame:
                    CGRectMake(xi,yi,xs,ys)];
     [l4 setTextColor : [UIColor whiteColor]];
     l4.text = @"Patch / SoundPack";
     [paPanel addSubview : l4];
    // add patch / soundpack pickers
    yi += ys;
    ys = OOG_PICKER_HIT;
    [self addPickerRow:paPanel : 3 : PICKER_BASE_TAG+17 : pickerNames[3] : yi : OOG_PICKER_HIT];
    yi += ys;
    [self addPickerRow:paPanel : 4 : PICKER_BASE_TAG+18 : pickerNames[4] : yi : OOG_PICKER_HIT];
    
    //5/23 make pro button only on RH side where controls are
    CGRect pRect = pPanel.frame;
    pRect.origin.x = pRect.size.width * 0.2; // 8/4 enlarge button to left , was 0.4
    proButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [proButton setFrame:pRect]; //5/23
    [proButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    proButton.backgroundColor    = [UIColor clearColor];
    [proButton addTarget:self action:@selector(proSelect:) forControlEvents:UIControlEventTouchUpInside];
    [scrollView addSubview:proButton];
    
    UIView *vLabel = [[UIView alloc] init];
    xi = viewWid;
    yi = viewHit/2;
    xs = 30;
    ys = 120;
    [vLabel setFrame : CGRectMake(xi,yi,xs,ys)];
    
    vLabel.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1];
    [self addSubview:vLabel];

//    xi = 0;
//    yi = 0; //9/14 Popup needs to be at SCREEN TOP, not viewTOP
//    xs = viewWid;
//    ys = viewHit;
    // 8/11     obp = [[obPopup alloc] initWithFrameAndSizetype:CGRectMake(xi,yi,xs,ys):OB_SIZE_HELP];
    // 8/11     obp.delegate = self;
    //10/24 use settings bundle flags to determine the enuf buttons visibility
  //  obp.showEnufButton = ( [cappDelegate getOnboardingFlag : OB_SILENCE_HELP] == 0) ;
    // 8/11       [self addSubview:obp];
    // 8/8 this contains all the help info for popups...
   // 8/11 mhelp = [miniHelp sharedInstance];

    
    //Scrolling area...
    int scrollHit = 1200; //8/12 760; //640;  //5/20 enlarged again
    //if (cappDelegate.gotIPad) scrollHit+=120; //3/27 ipad needs a bit more room
    
    scrollView.contentSize = CGSizeMake(viewWid, scrollHit);
                         
    [self clearAnalytics];

} //end setupView

//======(controlPanel)==========================================
//9/9 for session analytics
-(void) clearAnalytics
{
    //8/3 for session analytics: count activities
    diceRolls = 0; //9/9 for analytics
    resets    = 0; //9/9 for analytics
    for (int i=0;i<MAX_CONTROL_SLIDERS;i++) sChanges[i] = 0;
    for (int i=0;i<MAX_CONTROL_PICKERS;i++) pChanges[i] = 0;
}

//======(controlPanel)==========================================
// handles L/R swipe gesture over scrolling view...
// NOTE swipe direction is opposite from LR button direction!
- (void)swipeGestureDetected:(UISwipeGestureRecognizer *)swipeGesture
{
    int dir = (int)swipeGesture.direction;
    if (dir == 1) //right
        [self leftSelect:nil];  //9/9
    else
        [self rightSelect:nil];  //9/9
} //end swipeGestureDetected

//======(controlPanel)==========================================
// 9/7 ignore slider moves!
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
      if ([touch.view isKindOfClass:[UISlider class]]) {
          return NO; // ignore the touch
      }
      return YES; // handle the touch
}

//======(controlPanel)==========================================
- (BOOL)prefersStatusBarHidden
{
    return YES;
}


//======(controlPanel)==========================================
// 9/15 redo w/ genOogie method!
-(void) addSliderRow : (UIView*) parent : (int) index : (int) tag : (NSString*) label :
                (int) yoff : (int) ysize : (float) smin : (float) smax
{
    //9/15 new UI element...
   NSArray* A = [goog addSliderRow : parent : tag : sliderNames[index] :
                           yoff : viewWid: ysize :smin : smax];
   if (A.count > 0)
      {
        UISlider* slider = A[0];
        // hook it up to callbacks
        [slider addTarget:self action:@selector(sliderAction:) forControlEvents:UIControlEventValueChanged];
        [slider addTarget:self action:@selector(sliderStoppedDragging:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
        sliders[index] = slider;
        }
} //end addSliderRow

//======(controlPanel)==========================================
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

//======(controlPanel)==========================================
// adds a canned label/picker set...
-(void) addPickerRow : (UIView*) parent : (int) index : (int) tag : (NSString*) label : (int) yoff : (int) ysize
{
    //9/15 new UI element...
     NSArray* A = [goog addPickerRow : parent : tag : pickerNames[index] :
                                  yoff : viewWid : ysize];
    if (A.count > 0)
    {
        UIPickerView * picker = A[0];
        picker.delegate   = self;
        picker.dataSource = self;
        pickers[index] = picker;
    }

} //end addPickerRow


//======(controlPanel)==========================================
// 9/11 textField... for oogie2D/AR
-(void) addTextRow : (UIView*) parent : (int) index : (int) tag : (NSString*) label :
                (int) yoff : (int) ysize
{
    //9/15 new UI element...
    NSArray* A = [goog addTextRow : parent : tag : textFieldNames[index] : yoff : viewWid : ysize];
   if (A.count > 0)
      {
          UITextView * textField = A[0];
          textField.delegate     = self;
          textFields[index]      = textField;
      }
} //end addSliderRow


//======(controlPanel)==========================================
//  Updates our controls... LONG AND TEDIOUS,
//    takes incoming dictionary of name / value pairs, and
//    tries to find the proper control for each
//  NOTE: tag 0 cannot be used with buttons, makes bad stuff happen
-(void) configureView
{
    [pickers[3] reloadAllComponents];
    [pickers[4] reloadAllComponents];
    [self configureViewWithReset : FALSE];
}

//======(controlPanel)==========================================
// This is huge. it should be made to work with any control panel!
-(void) configureViewWithReset : (BOOL)reset
{
    //CLEAN THIS UP: make allpar,allpic,allslid class members instead of arrays!
    NSMutableArray *allpar = [[NSMutableArray alloc] init];
    for (int i=0;i<C_ALLPARAMCOUNT;i++) [allpar addObject:allParams[i]];
    NSMutableArray *allpick = [[NSMutableArray alloc] init];
    for (int i=0;i<MAX_CONTROL_PICKERS;i++) if (pickers[i] != nil) [allpick addObject:pickers[i]];
    NSMutableArray *allslid = [[NSMutableArray alloc] init];
    for (int i=0;i<MAX_CONTROL_SLIDERS;i++) if (sliders[i] != nil)  [allslid addObject:sliders[i]];
    NSMutableArray *alltext = [[NSMutableArray alloc] init];
    for (int i=0;i<MAX_CONTROL_TEXTFIELDS;i++) if (textFields[i] != nil)  [alltext addObject:textFields[i]];
    NSArray *noresetparams = @[@"patch",@"soundpack",@"name"];
    NSMutableDictionary *pickerchoices = [[NSMutableDictionary alloc] init];
    [pickerchoices setObject:_paNames forKey:@17];  //patches are on picker 17
    [pickerchoices setObject:_spNames forKey:@18];  //soundpacks are on picker 18
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



//======(controlPanel)==========================================
// 9/18/21 Sends a limited set of updates to parent
-(void) sendUpdatedParamsToParent : (NSDictionary*) paramsDict
{
    for (NSString*key in paramsDict.allKeys)
    {
        NSArray *ra = paramsDict[key];
        NSNumber *nt = ra[0];
        NSNumber *nv = ra[1];
        NSString *ns = ra[2];
        [self.delegate didSetControlValue:nt.intValue:nv.floatValue:key:ns:FALSE];
    }
} //end sendUpdatedParamsToParent

//======(controlPanel)==========================================
// 8/3 update session analytics here..
-(void)sliderStoppedDragging:(id)sender
{
    [self updateSliderAndDelegateValue : sender : FALSE]; //9/23
}

//======(controlPanel)==========================================
-(void)sliderAction:(id)sender
{
    [self updateSliderAndDelegateValue : sender : FALSE]; //9/23
}

//======(controlPanel)==========================================
//called when slider is moved and on dice/resets!
-(void) updateSliderAndDelegateValue :(id)sender : (BOOL) dice
{
    if (!_wasEdited) {_wasEdited = TRUE; resetButton.hidden = FALSE;} //9/8 show reset button now!
    UISlider *slider = (UISlider*)sender;
    int tagMinusBase = ((int)slider.tag % 1000); // 7/11 new name
    float value = slider.value;
    NSString *name = dice ? @"" : allParams[tagMinusBase];
    [self.delegate didSetControlValue:tagMinusBase:value:allParams[tagMinusBase]:name:TRUE];
} //end updateSliderAndDelegateValue


//======(controlPanel)==========================================
- (IBAction)helpSelect:(id)sender
{
    [self putUpOBHelpInstructions];
}

//======(controlPanel)==========================================
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

//======(controlPanel)==========================================
- (IBAction)proSelect:(id)sender
{
    [self.delegate controlNeedsProMode]; //9/8 pass buck to parent
}

//======(controlPanel)==========================================
- (IBAction)loNoteSelect:(id)sender
{
    NSLog(@" lonote");
}


//======(controlPanel)==========================================
- (void)LPGestureUndo:(UILongPressGestureRecognizer *)recognizer
{
    diceUndo = TRUE;   //7/9 handitoff to dice...
}

//======(controlPanel)==========================================
// 9/18  make this generic too, and return a list of updates for delegate.
// THEN add a method to go thru the updates dict and pass to parent,
//    and reuse this method here and in configureView!
-(void) randomizeParams
{
    //asdf
    NSLog(@" RANDOMIZE");
    //CLEAN THIS UP: make allpar,allpic,allslid class members instead of arrays!
    NSMutableArray *allpar = [[NSMutableArray alloc] init];
    for (int i=0;i<C_ALLPARAMCOUNT;i++) [allpar addObject:allParams[i]];
    NSMutableArray *allpick = [[NSMutableArray alloc] init];
    for (int i=0;i<MAX_CONTROL_PICKERS;i++) if (pickers[i] != nil) [allpick addObject:pickers[i]];
    NSMutableArray *allslid = [[NSMutableArray alloc] init];
    for (int i=0;i<MAX_CONTROL_SLIDERS;i++) if (sliders[i] != nil)  [allslid addObject:sliders[i]];
    NSArray *norandomizeparams = @[@"patch",@"soundpack",@"name",@"comment",@"delaysustain"];

    NSMutableDictionary *resetDict = [goog randomizeFromVC : allpar : allpick : allslid : norandomizeparams];
    [self sendUpdatedParamsToParent:resetDict];

    [self.delegate didSelectControlDice]; //4/29
    diceRolls++; //9/9 for analytics
    diceUndo = FALSE;
    rollingDiceNow = FALSE;

} //end randomizeParams


//======(controlPanel)==========================================
// 8/21 sets sliders directly and they report to parent,
//   pickers values have to be sent to parent here
- (IBAction)diceSelect:(id)sender
{
    //NOTE delaySustain if really large can cause problems, dont randomize it

    [self randomizeParams  ];
    resetButton.hidden = FALSE; //indicate param change
} //end diceSelect


//======(controlPanel)==========================================
- (IBAction)leftSelect:(id)sender
{
    [self.delegate didSelectLeft];
}

//======(controlPanel)==========================================
- (IBAction)rightSelect:(id)sender
{
    [self.delegate didSelectRight];
}

//======(controlPanel)==========================================
- (IBAction)resetSelect:(id)sender
{
    [self resetControls];
    [self.delegate updateControlModeInfo : @"Reset F/X"]; //5/19
    [self.delegate didSelectControlReset]; //7/11 for undo
}

//======(controlPanel)==========================================
// 4/3 reset called via button OR end of proMode demo
-(void) resetControls
{
    [self configureViewWithReset: TRUE];
    resettingNow = TRUE; //used w/ undo
    _wasEdited         = FALSE;
    resetButton.hidden = TRUE;
    resettingNow       = FALSE;
} //end resetControls

//======(controlPanel)==========================================
//8/3
-(void)updateSessionAnalytics
{
    //NSLog(@" duh collected analytics for flurry");
    for (int i=0;i<MAX_CONTROL_SLIDERS;i++)
    {
        if (sChanges[i] > 0) //report changes to analytics
        {
            //NSLog(@" slider[%d] %d",i,sChanges[i]);
            //NSString *sname = sliderKeys[i];
            //8/11 FIX[fanal updateSliderCount:sname:sChanges[i]];
        }
    }
    for (int i=0;i<MAX_CONTROL_PICKERS;i++)
    {
        if (pChanges[i] > 0) //report changes to analytics
        {
            //NSLog(@" picker[%d] %d",i,pChanges[i]);
            //NSString *pname = pickerKeys[i];
            //8/11 FIX[fanal updatePickerCount:pname:pChanges[i]];
        }
    }
    //8/11 FIX[fanal updateDiceCount : @"LDI" : diceRolls]; //9/9
    //8/11 FIX [fanal updateMiscCount : @"LRE" : resets]; //9/9
    [self clearAnalytics]; //9/9 clear for next session

} //end updateSessionAnalytics


//======(controlPanel)==========================================
- (NSString *)getPickerTitleForTagAndRow : (int)tag : (int)row
{
    //NSLog(@" get picker tag %d",row);
    NSString *title = @"";
    //tags pickers, 17 / 18  /  3  /  8  / 11

    if (tag == PICKER_BASE_TAG+3)
    {
        title = keySigs[row];
    }
    else if (tag == PICKER_BASE_TAG+8 || tag == PICKER_BASE_TAG+11)
    {
        title = vibratoWaves[row];
    }
    else if (tag == PICKER_BASE_TAG+17) //patch
    {
        if (_paNames != nil) title = _paNames[row];

    }
    else if (tag == PICKER_BASE_TAG+18) //soundpack
    {
        if (_spNames != nil) title = _spNames[row];

    }
    return title;
}

#pragma UIPickerViewDelegate

//-------<UIPickerViewDelegate>-----------------------------
// 6/18 redo
- (void)pickerView:(UIPickerView *)pickerView didSelectRow: (NSInteger)row inComponent:(NSInteger)component {
    if (!_wasEdited) {_wasEdited = TRUE; resetButton.hidden = FALSE;} //9/8 show reset button now!
    int liltag = pickerView.tag - PICKER_BASE_TAG; //just pass tags to parent now

    NSString *patchName = @"";
    if (liltag == 17) //patch? pass back our name...
    {
        if (row > 0) patchName = _paNames[row-1];
        else patchName = @"random";
    }
    [self.delegate didSetControlValue:liltag :(float)row : allParams[liltag] : patchName : !rollingDiceNow && !resettingNow];   //7/11

    //8/3 update picker activity count
    int pMinusBase = (int)(pickerView.tag-PICKER_BASE_TAG);
    if (pMinusBase>=0 && pMinusBase<MAX_CONTROL_PICKERS) pChanges[pMinusBase]++;
}

 
//-------<UIPickerViewDelegate>-----------------------------
// tell the picker how many rows are available for a given component
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    int tag = (int)pickerView.tag;
    //tags pickers, 17 / 18  /  3  /  8  / 11
    if ( tag == PICKER_BASE_TAG + 3)  return 12; //keysig
    else if ( tag == PICKER_BASE_TAG+8 || tag == PICKER_BASE_TAG+11 )  //vib ratos
        return 4;
    else if ( tag == PICKER_BASE_TAG+17) //patch
        {
            if (_paNames != nil) return _paNames.count;
        }
    else if ( tag == PICKER_BASE_TAG+18) //soundpack
        {
            if (_spNames != nil) return _spNames.count;
        }
    
    return 0; //empty (failed above test?)
    
}

//-------<UIPickerViewDelegate>-----------------------------
// tell the picker how many components it will have
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
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



//=======<obPopupDelegate>======================================
//- (void)obPopupDidSelectOK : (int)obType
//{
//}

//=======<obPopupDelegate>======================================
//- (void)obPopupDidSelectEnoughHelp : (int)obType
//{
//    //10/24 tell app Delegate to turn off minihelp... WHY do i need to use constant here!?
//    //[cappDelegate setOnboardingFlag : OB_SILENCE_HELP : 2]; //8/21 add int arg
//}

// 4/3 clear live controls upon end of demo
// 4/23 OK to do ui calls from notification!
- (void)demoNotification:(NSNotification *)notification
{
        [self resetControls];    //clear any effects changes...
}


#pragma mark - UITextFieldDelegate

//==========<UITextFieldDelegate>====================================================
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    //NSLog(@" begin");
    return YES;
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
    [self.delegate didSetControlValue:liltag : 0.0 : allParams[liltag] : s: FALSE];
    return YES;
}



@end
