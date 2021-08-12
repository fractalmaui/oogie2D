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
//  9/3  convert to UIView! complete redo!
//       added swipe gesture and didGoLeft/didGoRight delegate callbacks to switch view
//  9/7  add shouldReceiveTouch, made this class UIGestureRecognizerDelegate
//  9/8  add resetButton show/hide, moved factory reset to parent, cleanup dead code
//        shrink control y spread to match proPanel
//  9/9  add clearAnalytics, diceRolls
//  9/16 add genOogie controls for sliders/pickers
//  9/23 add pname to didSetControlValue ,other HUD support
//  9/24 add header for top controls
// 10/8  now updateSessionAnalytics called by parent
// 10/19 add getPickerTitleForTagAndRow, viewForRow for all pickers
// 10/24 integrate OB_SILENCE_HELP
// 10/27 tiny dice!
// 2/19/21 add delay, 3 params
// 3/27    fix UI for ipad
// 4/2   put flag around delay sliders
// 4/3   clear live controls upon end of demo
// 4/7   add ampl vibe
// 4/23  demoNotification was crashing using dispatch, removed
// 5/19  add updateControlModeInfo for reset
// 5/20  add footer for shadow effect, header now 50, sliders taller
// 5/23  make pro button only on RH side, add enable/disble for bottom 6 sliders
// 5/24  shrink picker rows more to make neighbors visible
// 6/19  fix ppanel size bug
// 6/27  update dice to handle delay sliders
// 7/4   fix param bug in sendAllParamsToParent
// 7/9   add oogieStyle
// 7/11  variable cleanup , hook up to undo, add undoable arg to didsetControlValue
// 8/11 MIGRATE to oogie2D> get rid of cappDelegate for now,
//         flurryAnalytics,miniHelp,obPopup


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
    @"Delay Time" ,@"Delay Sustain",@"Delay Mix"}; //2/19 note paddings b4 delay for vibwave
NSString *pickerNames[] = {@"KeySig",@"FVib Wave",@"AVib Wave"};

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
        
        [self setDefaults];
        [self setupView:frame];
        [self configureView]; // final view tweaking
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
    titleLabel.text = @"Live/FX";
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
    yi = 60;
    xs = viewWid-2*OOG_XMARGIN;
    // 7/9 calculate height based on controls
    ys = 3*OOG_SLIDER_HIT + OOG_PICKER_HIT + 3*OOG_YSPACER + 2*OOG_YMARGIN;
    UIView *cPanel = [[UIView alloc] init];
    [cPanel setFrame : CGRectMake(xi,yi,xs,ys)];
    cPanel.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1];
    [scrollView addSubview:cPanel];
    
    xi = OOG_XMARGIN;
    yi = xi; //top of form
    for (i=0;i<3;i++)
    {
        [self addSliderRow:cPanel : i : SLIDER_BASE_TAG + i : sliderNames[i] : yi : OOG_SLIDER_HIT:0.0:100.0];
        yi += (OOG_SLIDER_HIT+OOG_YSPACER);
    }


    [self addPickerRow:cPanel : 0 : PICKER_BASE_TAG+0 : pickerNames[0] : yi : OOG_PICKER_HIT];
    
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
    for (i=0;i<4;i++) //add 4 fx sliders, overdrive, portamento, FVIB level/speed
    {
        float smin = 0.0;
        if (i == 0) smin = 1.0;  //8/6 overdrive is special
        //NSLog(@" add slider %d %@",i,sliderNames[i+3]);
        NSString *dog = [NSString stringWithFormat:@"rowi %d",i];
        [self addSliderRow:pPanel : i+4 : SLIDER_BASE_TAG + i+4 : dog : yi : OOG_SLIDER_HIT:smin:100.0];
        yi += (OOG_SLIDER_HIT+OOG_YSPACER);
    }
    [self addPickerRow:pPanel : 1 : PICKER_BASE_TAG+1 : pickerNames[1] : yi : OOG_PICKER_HIT];
    yi += 2* (OOG_SLIDER_HIT+OOG_YSPACER);
    //4/7/21 add vibe params (2 sliders and a picker)
    for (i=0;i<2;i++) //add 2 fx sliders,  FVIB wave, AVIB level/speed
    {
        float smin = 0.0;
        if (i == 0) smin = 1.0;  //8/6 overdrive is special
        //NSLog(@" add slider %d %@",i,sliderNames[i+7]);
        NSString *dog = [NSString stringWithFormat:@"rowi %d",i];
        [self addSliderRow:pPanel : i+9 : SLIDER_BASE_TAG + i+9 : dog : yi : OOG_SLIDER_HIT:smin:100.0];
        yi += (OOG_SLIDER_HIT+OOG_YSPACER);
    }
    [self addPickerRow:pPanel : 2 : PICKER_BASE_TAG+2 : pickerNames[2] : yi : OOG_PICKER_HIT];


#ifdef GOT_DIGITALDELAY
    yi += (OOG_PICKER_HIT+OOG_YSPACER);
    // 2/19/21 add 3 delay sliders
    for (i=0;i<3;i++)
    {
        float smin = 0.0;
        NSString *dog = [NSString stringWithFormat:@"rowi %d",i];
        [self addSliderRow:pPanel : i+12 : SLIDER_BASE_TAG + i+12 : dog : yi : OOG_SLIDER_HIT:smin:100.0];
        yi += (OOG_SLIDER_HIT+OOG_YSPACER);
    }
#endif
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

    xi = 0;
    yi = 0; //9/14 Popup needs to be at SCREEN TOP, not viewTOP
    xs = viewWid;
    ys = viewHit;
    // 8/11     obp = [[obPopup alloc] initWithFrameAndSizetype:CGRectMake(xi,yi,xs,ys):OB_SIZE_HELP];
    // 8/11     obp.delegate = self;
    //10/24 use settings bundle flags to determine the enuf buttons visibility
  //  obp.showEnufButton = ( [cappDelegate getOnboardingFlag : OB_SILENCE_HELP] == 0) ;
    // 8/11       [self addSubview:obp];
    // 8/8 this contains all the help info for popups...
   // 8/11 mhelp = [miniHelp sharedInstance];
    
    //Scrolling area...
    int scrollHit = 760; //640;  //5/20 enlarged again
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
-(void) setDefaults
{
    _threshold    = 10;
    _overdrive    = 1; 
    _portamento   = 0;
    _bottomMidi   = 30;
    _topMidi      = 90;
    _keySig       = 0; //Major scale
    _vibWave      = 1; //SineWave?
    _vibLevel     = 0;
    _vibSpeed     = 10;
    _vibeWave      = 1; //4/7/21 SineWave?
    _vibeLevel     = 0;
    _vibeSpeed     = 10;
    // 2/19 no delay by default
    _delayTime    = 0;
    _delaySustain = 0;
    _delayMix     = 0;

}

//======(controlPanel)==========================================
// 9/15 redo w/ genOogie method!
-(void) addSliderRow : (UIView*) parent : (int) index : (int) tag : (NSString*) label :
                (int) yoff : (int) ysize : (float) smin : (float) smax
{
    //9/15 new UI element...
NSArray* A = [goog addSliderRow : parent : tag : sliderNames[index] :
                                yoff : viewWid: ysize :0.0 : 100.0];
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



//-(NSArray*) addSliderButtonRow : (UIView*) parent : (int) tag : (NSString*) label :
//                (UIImage*) buttonImage : (nullable id)target :
//                (int) yoff : (int) width : (int) ysize :
//                (float) smin : (float) smax;


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
//  Updates our controls...
//  NOTE: tag 0 cannot be used with buttons, makes bad stuff happen
-(void) configureView
{
    [sliders[0] setValue:_threshold];
    [sliders[1] setValue:_bottomMidi];
    [sliders[2] setValue:_topMidi];
    [pickers[0] selectRow:_keySig inComponent:0 animated:YES];
    [sliders[4] setValue:_overdrive];
    [sliders[5] setValue:_portamento];
    [sliders[6] setValue:_vibLevel];
    [sliders[7] setValue:_vibSpeed];
    [sliders[9] setValue:_vibeLevel]; //6/21 wups wrong indices here!
    [sliders[10] setValue:_vibeSpeed];
    [sliders[12] setValue:_delayTime];
    [sliders[13] setValue:_delaySustain];
    [sliders[14] setValue:_delayMix];

    [pickers[1] selectRow:_vibWave inComponent:0 animated:YES];
    [pickers[2] selectRow:_vibeWave inComponent:0 animated:YES]; //6/21 wups forgot
    resetButton.hidden = !_wasEdited;
    // 4/30 WTF? why wasnt this here earlier?
    //BOOL gotPro = (cappDelegate.proMode || cappDelegate.proModeDemo);
    proButton.hidden = TRUE; // 8/11 FIX gotPro;
    for (int i=4;i<11;i++) [sliders[i] setEnabled:TRUE]; //8/11 FIX gotPro];             //5/23 amateurs cannot use bottom sliders
    for (int i=1;i<3;i++) pickers[i].userInteractionEnabled = TRUE; //8/11 FIX gotPro; //       nor bottom pickers...

}  //end configureView


//======(controlPanel)==========================================
// 8/6 wups, had wrong param order!
-(void) sendAllParamsToParent
{
    [self.delegate didSetControlValue:0  :_threshold:@"":FALSE]; //7/11 add undoable arg
    [self.delegate didSetControlValue:1  :_bottomMidi:@"":FALSE];
    [self.delegate didSetControlValue:2  :_topMidi:@"":FALSE];
    [self.delegate didSetControlValue:3  :(float)_keySig:@"":FALSE];
    [self.delegate didSetControlValue:4  :_overdrive:@"":FALSE];
    [self.delegate didSetControlValue:5  :_portamento:@"":FALSE];
    [self.delegate didSetControlValue:6  :_vibLevel:@"":FALSE];
    [self.delegate didSetControlValue:7  :_vibSpeed:@"":FALSE];
    [self.delegate didSetControlValue:8  :_vibWave:@"":FALSE];
    [self.delegate didSetControlValue:9  :_vibeLevel:@"":FALSE]; //7/4/11 wups, forgot new params!
    [self.delegate didSetControlValue:10 :_vibeSpeed:@"":FALSE];
    [self.delegate didSetControlValue:11 :_vibeWave:@"":FALSE];
    [self.delegate didSetControlValue:12 :_delayTime:@"":FALSE];
    [self.delegate didSetControlValue:13 :_delaySustain:@"":FALSE];
    [self.delegate didSetControlValue:14 :_delayMix:@"":FALSE];
}

//======(controlPanel)==========================================
// 8/3 update session analytics here..
-(void)sliderStoppedDragging:(id)sender
{
    UISlider *slider = (UISlider*)sender;
    int tagMinusBase = (int)(slider.tag-1000);
    //8/3 update slider activity count
    if (tagMinusBase>=0 && tagMinusBase<MAX_CONTROL_SLIDERS) sChanges[tagMinusBase]++;
    NSString *name = sliderNames[tagMinusBase]; //7/11 for undo
    float value    = slider.value;
    [self.delegate didSetControlValue:tagMinusBase:value:name:TRUE];
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
    int tagMinusBase = (int)slider.tag-1000; // 7/11 new name
    //Get slider, associated param, and pass back to parent!
    float value = slider.value;
    //NSLog(@" sval %f",value);
    NSString *name = dice ? @"" : sliderNames[tagMinusBase];
    [self.delegate didSetControlValue:tagMinusBase:value:name:FALSE];

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
// 8/21 sets sliders directly and they report to parent,
//   pickers values have to be sent to parent here
- (IBAction)diceSelect:(id)sender
{
    double smins[15]= {0.0,0.0,0.0,0.0,0.0, //6/27/21 add more min/max delay fields
                       0.0,0.0,0.0,0.0,0.0,
                       0.0,0.0,0.0,0.0,0.0};
    double smaxes[15]= {100.0,100.0,100.0,100.0,100.0,
                        100.0,100.0,100.0,100.0,100.0,
                        100.0,100.0,100.0,100.0,100.0};
    int numSliders = 3; // Assume only top panel accessible...
    rollingDiceNow = TRUE;
    // 8/29 No pro mode? no bottom panel
    // 9/2   ...only 7 sliders with empty space at index 3
     //if (cappDelegate.proMode || cappDelegate.proModeDemo) numSliders = 15;   //6/27/21
    
    if (diceUndo)
    {
        NSLog(@" undo?");
        diceUndo = FALSE;
        return;
    }
    
    BOOL needVibrato    = (drand(0,1) < 0.20);
    BOOL needPortamento = (drand(0,1) < 0.20);
    BOOL needAmplVibe   = (drand(0,1) < 0.20);
    BOOL needDelay      = (drand(0,1) < 0.20);   //6/27/21

    for (int i=0;i<numSliders;i++) //randomize sliders based on pro mode
    {
        if (sliders[i] != nil) //skip empty spaces
        {
            float f = (float)drand(smins[i],smaxes[i]); // get slider randomized val
            if (i == 5  && !needPortamento) f = 0.0; //portamento on/off
            if (i == 6  && !needVibrato)    f = 0.0; //vibratoo on/off
            if (i == 9  && !needAmplVibe)   f = 0.0; //Ampl vibe on/off
            if (i == 12 && !needDelay)      f = 0.0; //Delay on/off //6/27/21
            [sliders[i] setValue:f]; //most all others get set!
            [self updateSliderAndDelegateValue : sliders[i]: TRUE]; //9/23
        }
    } //end for int
    //Randomize our 3 pickers...
    int row = (int)drand(0,12);
    [pickers[0] selectRow:row inComponent:0 animated:NO];
    [self.delegate didSetControlValue:3 :(float)row:@"":FALSE]; //messy hard coded tag!
    //if (cappDelegate.proMode || cappDelegate.proModeDemo) // 8/29 Pro Mode? bottom panel ok
    {
        row = (int)drand(0,4);
        [pickers[1] selectRow:row inComponent:0 animated:NO];
        [self.delegate didSetControlValue:8 :(float)row:@"":FALSE]; //messy hard coded tag!
        row = (int)drand(0,4); //4/8 randomize ampl wave
        [pickers[2] selectRow:row inComponent:0 animated:NO];
        [self.delegate didSetControlValue:11 :(float)row:@"":FALSE];
    }
    [self.delegate didSelectControlDice]; //4/29
    diceRolls++; //9/9 for analytics
    diceUndo = FALSE;
    rollingDiceNow = FALSE;

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
    resettingNow = TRUE; //used w/ undo
    [self setDefaults];
    [self configureView];
    [self sendAllParamsToParent];
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
            NSString *sname = sliderKeys[i];
            //8/11 FIX[fanal updateSliderCount:sname:sChanges[i]];
        }
    }
    for (int i=0;i<MAX_CONTROL_PICKERS;i++)
    {
        if (pChanges[i] > 0) //report changes to analytics
        {
            //NSLog(@" picker[%d] %d",i,pChanges[i]);
            NSString *pname = pickerKeys[i];
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
    NSString *title = @"";
    if (tag == PICKER_BASE_TAG)
    {
        title = keySigs[row];
    }
    else{
        title = vibratoWaves[row];
    }
    return title;
}



#pragma UIPickerViewDelegate


 
//-------<UIPickerViewDelegate>-----------------------------
// 6/18 redo
- (void)pickerView:(UIPickerView *)pickerView didSelectRow: (NSInteger)row inComponent:(NSInteger)component {
    if (!_wasEdited) {_wasEdited = TRUE; resetButton.hidden = FALSE;} //9/8 show reset button now!
    int which = 0;
    if (pickerView.tag == PICKER_BASE_TAG)
    {
        which = 3;
    }
    else if (pickerView.tag == PICKER_BASE_TAG+1) //vib wave
    {
        which = 8;
    }
    else{ //4/8/21 ampl vibe wave
        which = 11;
    }
    int liltag = (int)pickerView.tag - PICKER_BASE_TAG;
    [self.delegate didSetControlValue:which :(float)row:pickerNames[liltag]: !rollingDiceNow && !resettingNow];   //7/11

    //8/3 update picker activity count
    int pMinusBase = (int)(pickerView.tag-PICKER_BASE_TAG);
    if (pMinusBase>=0 && pMinusBase<MAX_CONTROL_PICKERS) pChanges[pMinusBase]++;
}

 
//-------<UIPickerViewDelegate>-----------------------------
// tell the picker how many rows are available for a given component
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    //NSUInteger numRows = 0;
    if (pickerView.tag == PICKER_BASE_TAG)  return 12;
    return 4; //vibrato waves
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


@end
