//                   ____                  _
//   _ __  _ __ ___ |  _ \ __ _ _ __   ___| |
//  | '_ \| '__/ _ \| |_) / _` | '_ \ / _ \ |
//  | |_) | | | (_) |  __/ (_| | | | |  __/ |
//  | .__/|_|  \___/|_|   \__,_|_| |_|\___|_|
//  |_|
//
//  OogieCam proPanel
//
//  Created by Dave Scruton on 6/19/20.
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
// 8/12/21 fix? #import "AppDelegate.h" //KEEP this OUT of viewController.h!!
//      Looks like we cant support oogieVoice here, so we need to bring in params
//      in a dict...
// 9/11/21 NOTE: no dj mode handling here!
#define ARC4RANDOM_MAX      0x100000000
#define PERCKIT_VOICE 2

#define SWIFT_VERSION

#import "proPanel.h"
@implementation proPanel

// 8/12/21 fix? AppDelegate *pappDelegate;

double drand(double lo_range,double hi_range);


NSString *sliderDisplayNames[] = {@"Attack",@"Decay",@"Sustain",
                           @"SLevel",@"Release",@"Duty",
                           @"NoteVal",@"VolumeVal",@"PanVal",@"SampOff%",  //these go with pickers which already have names
                           @"Level", @"KeyOff" , @"KeyTune",  //2/12/21
                           @"Channel", //MIDI channel, not used now
                           @"",@"",@"",@"",
                           @"",@"",@"",@"",@"", //placeholders for perckit
};
//These should match the 16 slider field changed entries one for one
NSString *sliderParamNames[] = {@"attack",@"decay",@"sustain",
    @"slevel",@"release",@"duty",
    @"nchan",@"vchan",@"pchan",@"sampoffset",
    @"plevel", @"pkeyoffset" , @"pkeydetune", //2/12/21
    @"channel", //MIDI chan, not used
    @"pkpan1",@"pkpan2",@"pkpan3",@"pkpan4",@"pkpan5",@"pkpan6",@"pkpan7",@"pkpan8"
};

//up to 8 picker fields, similar to sliders 4/27 add 2 empty padds
// 5/18 why were there 2 blank fields at start of pickerDisplayNames?
// 6/11 fix missing names for perckit pickers...
NSString *pickerDisplayNames[] = {@"Wave",@"Poly",@"Note",@"Volume",@"Pan",
                @"PercKit Sample 1",@"PercKit Sample 2",@"PercKit Sample 3",@"PercKit Sample 4",
                @"PercKit Sample 5",@"PercKit Sample 6",@"PercKit Sample 7",@"PercKit Sample 8"};
NSString *pickerParamNames[] = {@"wave",@"poly",@"notemode",@"volmode",@"pan",
    @"pkloox1",@"pkloox2",@"pkloox3",@"pkloox4",
    @"pkloox5",@"pkloox6",@"pkloox7",@"pkloox8"};

//for analytics use: simple 3 letter keys for all controls
//  first char indicates UI, then 2 letters for control
NSString *psliderKeys[] = {@"PAT",@"PDE",
@"PSU",@"PSL",@"PRE",@"PDU",@"PNL",@"PVL",@"PPL",@"PSO",@"PLV",@"PKO",@"PDT",@"PCH",
    @"",@"",@"",@"",@"",@"",@"",@""}; //including placeholders!
NSString *ppickerKeys[] = {@"PWA",@"PPO",@"PNO",@"PVO",@"PPA",
    @"PS1",@"PS2",@"PS3",@"PS4",@"PS5",@"PS6",@"PS7",@"PS8"};

//Color channel choices...
NSString *channels[] = {@"Red",@"Green",@"Blue",
    @"Hue",@"Lum",@"Sat",@"Cyan",
    @"Mag",@"Yel",@"Slider"
};

NSString *synthWaves[] = {@"Sine",@"Saw",@"Square",
    @"Ramp",@"Noise"
};

NSString *onOffs[] = {@"Off",@"On"};


//======(proPanel)==========================================
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // 8/12/21 FIX pappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        // 9/15 add UI utilities
        goog = [genOogie sharedInstance]; //MUST setup before UI!
        [self setDefaults];
        [self setupView:frame];
        [self configureView]; // final view tweaking
        
        
        paramEdits = [edits sharedInstance];  //for saving param edits in documents
        [self setDefaults];
        
        _isUp = FALSE; //8/21
        //8/13 flurry analytics
        // 8/12/21 FIX fanal = [flurryAnalytics sharedInstance];

        sfx   = [soundFX sharedInstance]; //8/27
        _randomized = FALSE; //9/29
        
        _oogieVoiceResultsDict = [[NSMutableDictionary alloc] init];

    }
    return self;
}


//======(proPanel)==========================================
// Create all the controls in this panel.
// NOTE All frames are computed geometrically, so the UI
//  will be basically the same on any device XY scale.
// NOTE Super wide devices like iPad in landscape orientation
//  will have controls that are flat and squished out!
-(void) setupView:(CGRect)frame
{
    viewWid    = frame.size.width;
    viewHit    = frame.size.height;
//    buttonWid = viewHit * 0.07; //9/8 vary by viewhit, not wid
//    buttonHit  = buttonWid;
    buttonWid = viewWid * 0.12; //10/4 REDO button height,scale w/width
    // 8/12/21 FIX if (pappDelegate.gotIPad) //12/11 smaller buttons on ipad!
    // 8/12/21 FIX     buttonWid = viewWid * 0.06;  // ...by half?
    buttonHit = OOG_HEADER_HIT;
    self.frame = frame;
    self.backgroundColor = [UIColor blueColor]; // 6/19/21 colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.1];
    int xs,ys,xi,yi;
    
    xi = 0;
    yi = 0;
    xs = viewWid;
    ys = viewHit;
    scrollView = [[UIScrollView alloc] init];
    scrollView.frame = CGRectMake(xi,yi,xs,ys);
    scrollView.backgroundColor = [UIColor clearColor]; // 6/19/21 [UIColor colorWithRed:0 green:0 blue:0.2 alpha:1]; //[UIColor blueColor]; //blackColor]; //[UIColor redColor];
    scrollView.showsVerticalScrollIndicator = TRUE;
//    // Panel heights... redid 5/20 for taller sliders
//    uHit  = 140;  //universal (top) panel
//    eHit  = 255;  //envelope generator panel 7/9/21 adjust
//    cHit  = 215;  //channel panel 7/9/21 adjust
//    ftHit = 150;  //FineTune panel 2/12/21
//    mHit  = 0;    // 9/23 no midi panel   95;   //midi panel
//    pkHit = 650;  //percKit panel  7/9/21 adjust
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
    

    yi = 0;
    xs = viewWid*0.5; //9/16 not too wide
    xi = viewWid * 0.5 - xs*0.5;
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:
                           CGRectMake(xi,yi,xs,ys)];
    [titleLabel setTextColor : [UIColor whiteColor]];
    [titleLabel setFont:[UIFont fontWithName:@"Helvetica Neue" size: 32.0]];
    titleLabel.text = @"Patch Edit";
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [header addSubview : titleLabel];
    
    xs = viewWid*0.2; //10/19 narrow help button
    xi = viewWid * 0.5 - xs*0.5;;
    helpButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [helpButton setFrame:CGRectMake(xi,yi,xs,ys)];
    helpButton.backgroundColor = [UIColor clearColor];
    [helpButton addTarget:self action:@selector(helpSelect:) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview : helpButton];
    
    xs = buttonHit;
    ys = buttonHit;
    yi = 0; //7/9
    xi = OOG_XMARGIN;
    //9/3 add dice where helpbutton WAS
    diceButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [diceButton setImage:[UIImage imageNamed:@"bluedice.png"] //10/27 new color
                forState:UIControlStateNormal];
    int inset = 4; //10/27 tiny dice!
    CGRect rr = CGRectMake(xi+inset, yi+inset, xs-2*inset, ys-2*inset);
    [diceButton setFrame:rr];
    [diceButton setTintColor:[UIColor grayColor]];
    [diceButton addTarget:self action:@selector(diceSelect:) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:diceButton];
    
    //Add reset button next to dice
    float borderWid = 5.0f;
    UIColor *borderColor = [UIColor whiteColor];
    xi += xs + 5;
    xs = buttonHit * 1.4; //5/20 viewWid*0.15;
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
    [header addSubview:goLeftButton];
    xi+=xs;
    goRightButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [goRightButton setImage:[UIImage imageNamed:@"arrowRight"] forState:UIControlStateNormal];
    [goRightButton setFrame:CGRectMake(xi,yi, xs,ys)];
    [goRightButton addTarget:self action:@selector(rightSelect:) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:goRightButton];
    //9/24 end header area
    
    //int sliderNum = 0;
    int panelY    = 60; //8/6 move down for title/help button
    int panelSkip = 5; //Space between panels
    int panelTopMargin = 3;
    
    //universal panel...
    xi = OOG_XMARGIN; //6/19/21
    xs = viewWid - 2*OOG_XMARGIN;
    
    // 7/9 calculate height based on controls
    uHit = 2*OOG_PICKER_HIT + OOG_YSPACER + 2*OOG_YMARGIN;
    uPanel = [[UIView alloc] init];
    [uPanel setFrame : CGRectMake(xi,panelY,xs,uHit)];
    uPanel.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.5 alpha:1];
    [scrollView addSubview:uPanel];
    yi = 5*panelTopMargin;
    // args: parent, tag, label, yoff, ysize
    //Add Pickers for Wave / Poly
    [self addPickerRow:uPanel : 0 : PICKER_BASE_TAG + 0 : @"Wave" : yi : OOG_PICKER_HIT];
    yi += (OOG_PICKER_HIT - 15); //5/24 test squnch pickers together
    [self addPickerRow:uPanel : 1 : PICKER_BASE_TAG + 1 : @"Poly" : yi : OOG_PICKER_HIT];

    //envelope panel next... series of 6 sliders
    panelY += (uHit+panelSkip);
    xi = OOG_XMARGIN; //6/19/21
    xs = viewWid - 2*OOG_XMARGIN;
    // 7/9 calculate height based on controls
    eHit = 6*OOG_SLIDER_HIT + OOG_PICKER_HIT + 6*OOG_YSPACER + 2*OOG_YMARGIN;
    ePanel = [[UIView alloc] init];
    [ePanel setFrame : CGRectMake(xi,panelY,xs,eHit)];
    ePanel.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.5 alpha:1];
    [scrollView addSubview:ePanel];
    yi = panelTopMargin;
    xs = viewWid;
    ys = OOG_SLIDER_HIT;
    UILabel *l1 = [[UILabel alloc] initWithFrame: //label goes from col 1 to 2
                   CGRectMake(xi,yi,xs,ys)];
    [l1 setTextColor : [UIColor whiteColor]];
    l1.text = @"Envelope";
    [ePanel addSubview : l1];

    // 9/14 add ADSR image output
    xi = 120;
    xs = viewWid - viewWid*0.05 - xi;
    ys = 40;
    adsrImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"empty64x64"]];
    [adsrImage setFrame:CGRectMake(xi,yi,xs,ys)];
    adsrImage.layer.borderWidth  = 2;
    adsrImage.layer.borderColor  = [UIColor blackColor].CGColor;
    [ePanel addSubview:adsrImage];
    yi+=20; //9/15 skip down a bit..

    xi = OOG_XMARGIN; //6/19/21
    // 4/26 analyze pass xs = viewWid - xi;
    for (int i = 0;i<6;i++) //first slider is in ADSR now 9/8
    {
        yi += (OOG_SLIDER_HIT+2);
        [self addSliderRow:ePanel : i : SLIDER_BASE_TAG + i : sliderDisplayNames[i] : yi : OOG_SLIDER_HIT:0.0:100.0];
    }
    
    //Color Channels panel next... 3 groups of picker/slider pairs and one slider below that
    panelY += (eHit+panelSkip);
    xi = OOG_XMARGIN; //6/19/21
    xs = viewWid - 2*OOG_XMARGIN;
    // 7/9 calculate height based on controls
    cHit = OOG_SLIDER_HIT + 3*OOG_PICKER_HIT + 3*OOG_YSPACER + 2*OOG_YMARGIN;
    cPanel = [[UIView alloc] init];
    [cPanel setFrame : CGRectMake(xi,panelY,xs,cHit)];
    cPanel.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.5 alpha:1];
    [scrollView addSubview:cPanel];
    yi = panelTopMargin;
    xs = viewWid;
    ys = OOG_SLIDER_HIT;
    UILabel *l2 = [[UILabel alloc] initWithFrame: //label goes from col 1 to 2
                   CGRectMake(xi,yi,xs,ys)];
    [l2 setTextColor : [UIColor whiteColor]];
    l2.text = @"Color Channels";
    [cPanel addSubview : l2];
    yi+=ys;
    ys = OOG_PICKER_HIT + 5; // 50; //Need more spacing between pickers!
    // WHY is picker font so HUGE? Shrink it and we can reduce ysize!
    for (int i=0;i<3;i++)
    {     //args: parent, pickerTag, sliderTag, ypos , ysize
        [self addPickerSliderRow : cPanel : i+2 : i+6 : yi :ys]; //i/j = picker / slider # 10/16
        yi+=ys-18; //5/24 test squnch
    }
    yi += 5; // 9/8 add teeny space
    //9/8 remove level, 9 was 10
    [self addSliderRow:cPanel : 9 : SLIDER_BASE_TAG + 9 : sliderDisplayNames[9] : yi : OOG_SLIDER_HIT:1.0:100.0]; //also add a slider
    // 4/26 analyze pass yi+=ys;
    
    panelY += (cHit+panelSkip);
    
    //FineTune panel 2/12/21
    // 7/9 calculate height based on controls
    ftHit = 4*OOG_SLIDER_HIT + 3*OOG_YSPACER + 2*OOG_YMARGIN;
    ftPanel = [[UIView alloc] init];
    xi = OOG_XMARGIN; //6/19/21
    xs = viewWid - 2*OOG_XMARGIN;
    [ftPanel setFrame : CGRectMake(xi,panelY,xs,ftHit)];
    ftPanel.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.6 alpha:1];
    [scrollView addSubview:ftPanel];
    yi = panelTopMargin;
    xs = viewWid;
    ys = OOG_SLIDER_HIT;
    UILabel *l4 = [[UILabel alloc] initWithFrame:
                   CGRectMake(xi,yi,xs,ys)];
    [l4 setTextColor : [UIColor whiteColor]];
    l4.text = @"Fine Tuning";
    [ftPanel addSubview : l4];
    for (int i = 0;i<3;i++)   //3 items...
    {
        yi += (OOG_SLIDER_HIT+2);
        [self addSliderRow:ftPanel : 10 + i: SLIDER_BASE_TAG + 10 + i : sliderDisplayNames[10+i] : yi : OOG_SLIDER_HIT:1.0:100.0];
    }
    //NOTE: ftpanel and pkpanel overlap, one is visible when other is hidden!
//midi panel next... NOT USED YET
//    mPanel = [[UIView alloc] init];
//    [mPanel setFrame : CGRectMake(0,panelY,viewWid,mHit)];
//    mPanel.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.6 alpha:1];
//    [scrollView addSubview:mPanel];
//    yi = panelTopMargin;
//    xs = viewWid;
//    ys = OOG_SLIDER_HIT;
//    UILabel *l3 = [[UILabel alloc] initWithFrame:
//                   CGRectMake(xi,yi,xs,ys)];
//    [l3 setTextColor : [UIColor whiteColor]];
//    l3.text = @"Midi Output";
//    [mPanel addSubview : l3];
//    for (int i = 11;i<12;i++)   //just one item at this time...
//    {
//        yi += (OOG_SLIDER_HIT+2);
//        [self addSliderRow:mPanel : i : sliderDisplayNames[i] : yi : OOG_SLIDER_HIT:1.0:16.0];
//    }
    
    //PercKit Panel (optional depending on patch type)
    //    panelY += (mHit+panelSkip); //use this if MIDI panel is present
    pkPanel = [[UIView alloc] init];
    xi = OOG_XMARGIN; //6/19/21
    xs = viewWid - 2*OOG_XMARGIN;
    pkHit = 10*OOG_SLIDER_HIT + 8*OOG_PICKER_HIT + 8*OOG_YSPACER + 2*OOG_YMARGIN;
    [pkPanel setFrame : CGRectMake(xi,panelY,xs,pkHit)];
    pkPanel.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.7 alpha:1];
    [scrollView addSubview:pkPanel];
    yi = panelTopMargin;
    xs = viewWid;
    ys = OOG_SLIDER_HIT;
    UILabel *l5 = [[UILabel alloc] initWithFrame: //2/12/21 rename var
                   CGRectMake(xi,yi,xs,ys)];
    [l5 setTextColor : [UIColor whiteColor]];
    l5.text = @"Percussion Kit";
    [pkPanel addSubview : l5];
    for (int i = 0;i<8;i++)   //add 8 sets of pickers and sliders
    {
        yi += (OOG_SLIDER_HIT+4);
        NSString *pname = [NSString stringWithFormat:@"Sample %d",i+1];
        [self addPickerRow:pkPanel : i+5 : PICKER_BASE_TAG + i+5 : pname : yi : OOG_PICKER_HIT];
        yi += OOG_PICKER_HIT; // - 20; //5/24 test squnch
        NSString *sname = [NSString stringWithFormat:@"Pan %d",i+1];
        // 7/18/21 fix bad 3rd arg...
        [self addSliderRow:pkPanel : i+14 : SLIDER_BASE_TAG + i+14 : sname : yi : OOG_SLIDER_HIT:0.0:255.0];
    }
    
    // 8/6 add help
    xi = yi = 0;
    xs = viewWid;
    ys = viewHit;
    // 8/12/21 FIX  obp = [[obPopup alloc] initWithFrameAndSizetype:CGRectMake(xi,yi,xs,ys):OB_SIZE_HELP];
    // 8/12/21 FIX obp.delegate = self;
    //10/24 use settings bundle flags to determine the enuf buttons visibility
    // I have to use hardcoded value here!...WTF?#define OB_SILENCE_HELP 1202
    // 8/12/21 FIX  obp.showEnufButton = ( [pappDelegate getOnboardingFlag : 1202] == 0) ;
    // 8/12/21 FIX [self addSubview:obp];
    // 8/8 this contains all the help info for popups...
    // 8/12/21 FIX mhelp = [miniHelp sharedInstance];
} //end setupView


//======(proPanel)==========================================
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


//======(proPanel)==========================================
// 9/7 ignore slider moves!
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
      if ([touch.view isKindOfClass:[UISlider class]]) {
          return NO; // ignore the touch
      }
      return YES; // handle the touch
}

//======(proPanel)==========================================
- (BOOL)prefersStatusBarHidden
{
    return YES;
}

//======(proPanel)==========================================
// 9/16 redo adds a canned label/picker/slider set...
-(void) addPickerSliderRow : (UIView*) parent : (int)pindex : (int) sindex : (int) yoff : (int) ysize
{
    NSArray* A = [goog addPickerSliderRow:parent :PICKER_BASE_TAG+pindex :SLIDER_BASE_TAG+sindex :pickerDisplayNames[pindex] :yoff :viewWid :ysize];

    if (A.count > 1)
    {
        UIPickerView * picker = A[0];
        picker.delegate       = self;
        picker.dataSource     = self;
        pickers[pindex]       = picker;
        
        UISlider     *slider  = A[1];
        [slider addTarget:self action:@selector(sliderAction:) forControlEvents:UIControlEventValueChanged];
        [slider addTarget:self action:@selector(sliderStoppedDragging:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
        sliders[sindex] = slider; //retain for setting below
    }
} //end addPickerSliderRow


//======(controlPanel)==========================================
// 9/16 redo adds a canned label/picker set...
-(void) addPickerRow : (UIView*) parent : (int) index : (int) tag : (NSString*) label : (int) yoff : (int) ysize
{
    //9/15 new UI element...
    NSArray* A = [goog addPickerRow : parent : tag : label :
                                 yoff : viewWid : ysize];
    if (A.count > 0)
    {
        UIPickerView * picker = A[0];
        picker.delegate   = self;
        picker.dataSource = self;
        pickers[index] = picker;
    }
} //end addPickerRow

//======(proPanel)==========================================
// 9/16 redo adds a canned label/slider set...
-(void) addSliderRow : (UIView*) parent : (int) index : (int) tag : (NSString*) label : (int) yoff : (int) ysize :
(float) smin : (float) smax
{
    //NSLog(@" addslider %d",index);
    //9/15 new UI element...
    NSArray* A = [goog addSliderRow : parent : tag : label :
                                yoff : viewWid: ysize :smin : smax];
    if (A.count > 0)
    { UISlider* slider = A[0];
        // hook it up to callbacks
        [slider addTarget:self action:@selector(sliderAction:) forControlEvents:UIControlEventValueChanged];
        [slider addTarget:self action:@selector(sliderStoppedDragging:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
        sliders[index] = slider;
    }
} //end addSliderRow


//======(proPanel)==========================================
-(void) setDefaults
{
    //try to match Sinewave patch
    // 8/12/21 FIX ???
//    _ov.attack = 2;
//    _ov.decay = 8;
//    _ov.sustain  = 3;
//    _ov.sLevel  = 0;
//    _ov.releaseTime  = 40;
//    _ov.duty = 0;
//    _ov.noteMode = 3;
//    _ov.volMode  = 9;
//    _ov.pan      = 9;
//    _ov.nchan    = 128;
//    _ov.vchan    = 128;
//    _ov.pchan    = 128;
//    _ov.sampOffset = 0;
//    for (int i=0;i<8;i++)
//    {
//        [_ov OVsetPercLoox:i :i];  //Should this be special for each patch?
//        [_ov OVsetPercLooxPans:i :128]; //pan to center
//    }

} //end setDefaults

//======(proPanel)==========================================
-(void) setEdited
{
    if (!_wasEdited)  //7/18 show reset on change
    {
        _wasEdited = TRUE;
        //9/29 only allow reset on factory patches!!!
        resetButton.hidden = (!_wasEdited || _randomized);  //NOT on randomized ones
    }
} //end setEdited


//======(proPanel)==========================================
//  Updates our controls...
//  NOTE: tag 0 cannot be used with buttons, makes bad stuff happen
//  9/8 removed level!
-(void) configureView
{
    goRightButton.enabled = FALSE;
    
#ifdef SWIFT_VERSION //Swift version uses dict as source
    NSNumber *nn;
    nn = _oogieVoiceDict[@"type"];
    int type = nn.intValue;

    nn = _oogieVoiceDict[@"wave"];
    [pickers[0] selectRow:nn.intValue inComponent:0 animated:YES];
    nn = _oogieVoiceDict[@"poly"];
    [pickers[1] selectRow:nn.intValue inComponent:0 animated:YES];
    
    
    nn = _oogieVoiceDict[@"attack"];
    [sliders[0] setValue:nn.floatValue];
    nn = _oogieVoiceDict[@"decay"];
    [sliders[1] setValue:nn.floatValue];
    nn = _oogieVoiceDict[@"sustain"];
    [sliders[2] setValue:nn.floatValue];
    nn = _oogieVoiceDict[@"slevel"];
    [sliders[3] setValue:nn.floatValue];
    nn = _oogieVoiceDict[@"release"];
    [sliders[4] setValue:nn.floatValue];
    nn = _oogieVoiceDict[@"duty"];
    [sliders[5] setValue:nn.floatValue];
    nn = _oogieVoiceDict[@"nchan"];
    [sliders[6] setValue:nn.floatValue];
    nn = _oogieVoiceDict[@"pchan"];
    [sliders[7] setValue:nn.floatValue];
    nn = _oogieVoiceDict[@"vchan"];
    [sliders[8] setValue:nn.floatValue];
    nn = _oogieVoiceDict[@"sampoffset"];
    [sliders[9] setValue:nn.floatValue];

    nn = _oogieVoiceDict[@"notemode"];
    [pickers[2] selectRow:nn.intValue inComponent:0 animated:YES];
    nn = _oogieVoiceDict[@"volmode"];
    [pickers[3] selectRow:nn.intValue inComponent:0 animated:YES];
    nn = _oogieVoiceDict[@"volmode"];
    int lpan = nn.intValue;
    if (lpan == 11) lpan = 9; //keep it legal for now...
    [pickers[4] selectRow:lpan inComponent:0 animated:YES];
    // fineTune section
// 8/12 ADD THIS!
//    nn = _oogieVoiceDict[@"plevel"];
//    [sliders[10] setValue:nn.floatValue];
//    nn = _oogieVoiceDict[@"pkeyoffset"];
//    [sliders[11] setValue:nn.floatValue];
//    nn = _oogieVoiceDict[@"pkeydetune"];
//    [sliders[12] setValue:nn.floatValue];
    if (type == PERCKIT_VOICE)
    {
        for (int i=0;i<8;i++)
        {
            NSString *pkey = [NSString stringWithFormat:@"percloox%d",i];
            nn = _oogieVoiceDict[pkey];
            int bufNum = nn.intValue - LOAD_SAMPLE_OFFSET;
            if (bufNum >= 0 && bufNum < _sampleNames.count)
            {
                [pickers[5 + i] selectRow: bufNum inComponent:0 animated:YES];
                pkey = [NSString stringWithFormat:@"perclooxpans%d",i];
                nn = _oogieVoiceDict[pkey];
                NSLog(@"[%d] buf[%d] pan %d",i,bufNum,nn.intValue);
                [sliders[13+ i] setValue : nn.floatValue];
            }
        }
    }

#else //OBJECTIVE C version, use oogieVoice as source...
    // universal section
    ///WTF? there are 2 pickers at top, wave / poly  and then three down below ADSR, note/vol/pan!
    [pickers[0] selectRow:_ov.wave inComponent:0 animated:YES];
    NSLog(@" set wave picker 0 to %d",_ov.wave);
    [pickers[1] selectRow:_ov.poly inComponent:0 animated:YES];
    //envelope section
    [sliders[0] setValue:_ov.attack];
    [sliders[1] setValue:_ov.decay];
    [sliders[2] setValue:_ov.sustain];
    [sliders[3] setValue:_ov.sLevel];
    [sliders[4] setValue:_ov.releaseTime];
    [sliders[5] setValue:_ov.duty];
    sliders[5].hidden = (_ov.wave != 2); // 10/19 duty slider only for squares!
    // channels section
    [sliders[6] setValue:_ov.nchan];
    [sliders[7] setValue:_ov.vchan];
    [sliders[8] setValue:_ov.pchan];
    [sliders[9] setValue:_ov.sampOffset];
    [pickers[2] selectRow:_ov.noteMode inComponent:0 animated:YES]; //9/2
    [pickers[3] selectRow:_ov.volMode  inComponent:0 animated:YES]; //9/2
    //NSLog(@" set panpicker %d",_ov.pan);
    //Problem: there is a discontinuity in PAN params... 11 means to use slider,
    //  but the other valid modes in this UI are 1..9 (0..8 for picker)
    int lpan = _ov.pan;
    if (lpan == 11) lpan = 9;
    [pickers[4] selectRow: lpan inComponent:0 animated:YES];
    // fineTune section 2/12/21
    [sliders[10] setValue:_ov.pLevel];
    [sliders[11] setValue:_ov.pKeyOffset];
    [sliders[12] setValue:_ov.pKeyDetune];
     handle percKit settings if needed
    if (_ov.type == PERCKIT_VOICE)
    {
        for (int i=0;i<8;i++)
        {
            int bufNum = [_ov OVgetPercLoox :i] - LOAD_SAMPLE_OFFSET; //10/12 wups wrong offset!
            if (bufNum >= 0 && bufNum < _sampleNames.count)
            {
                int ppan = [_ov OVgetPercLooxPans :i];
                [sliders[13+ i] setValue : ppan]; //2/12/21 add 3 sliders above here
                //NSLog(@" picker %d buf %d pan %d",i,bufNum,ppan);
                [pickers[5 + i] selectRow: bufNum inComponent:0 animated:YES];
            }
            else NSLog(@" picker outta boundz! %d",bufNum);
        }
        [self enableADSRControls : FALSE]; //5/19
        //7/9 Picker[0] should be disabled here too, but HOW?
    }
    else
    {
        [self enableADSRControls : TRUE];  //5/19
    }
#endif

    // midi section
   // [sliders[11] setValue:_ov.midiChannel];
    
    // 8/12/21 FIX     startVoice = [_ov copy]; //get a copy for later!
    //Scrolling area varies in size...
    int scrollHit = uHit + eHit + cHit + ftHit + mHit + 100; // 2/12/21
    // 7/9/21: note else below... does it apply to other voice types or just to device type???
    // 8/12/21 FIX if (_ov.type == PERCKIT_VOICE) scrollHit += pkHit;
    // 8/12/21 FIX else if (pappDelegate.gotIPad) scrollHit+=120; //3/27 more space needed on ipad
    scrollView.contentSize = CGSizeMake(viewWid, scrollHit);
    // 7/6 moved here from viewDidLoad
    for (int i=0;i<MAX_PRO_SLIDERS;i++) sliderChanged[i] = FALSE;
    for (int i=0;i<MAX_PRO_PICKERS;i++) pickerChanged[i] = FALSE;
    [self clearAnalytics];
    
    //Show/Hide percKit panel based on voice type
    // 8/12/21 FIX ftPanel.hidden =  (_ov.type == PERCKIT_VOICE); //2/12/21
    // 8/12/21 FIX pkPanel.hidden =  (_ov.type != PERCKIT_VOICE);
    //9/29 only allow reset on factory patches!!!
    resetButton.hidden = (!_wasEdited || _randomized);  //NOT on randomized ones
    //9/14 ADSR diaplay  asdf
    [self updateADSRDisplay];

}  //end configureView

//======(proPanel)==========================================
// 5/19 sets ADSR on/off
-(void) enableADSRControls : (BOOL) enabled
{
    
    //5/19 streamline, load empty early!?
//    if (!enabled)
//        [adsrImage setImage : [UIImage imageNamed:@"empty64x64"]];
    adsrImage.hidden = !enabled;
    for (int i = 0;i<6;i++) //first slider is in ADSR now 9/8
    {
        sliders[i].enabled = enabled;
    }

} //end enableADSRControls

//======(proPanel)==========================================
//9/9 for session analytics
-(void) clearAnalytics
{
    //8/13 for session analytics: count activities
    diceRolls = 0; //9/9 for analytics
    resets    = 0; //9/9 for analytics
    for (int i=0;i<MAX_PRO_SLIDERS;i++) sChanges[i] = 0;
    for (int i=0;i<MAX_PRO_PICKERS;i++) pChanges[i] = 0;
}

//======(proPanel)==========================================
-(void) resetAllEdits
{
    for (int i=0;i<MAX_PRO_SLIDERS;i++)
    {
        if (sliderParamNames[i].length > 0)
            [paramEdits removeEdit : _patchName : sliderParamNames[i]]; //7/8
    }
    for (int i=0;i<MAX_PRO_PICKERS;i++)
    {
        if (pickerParamNames[i].length > 0)
            [paramEdits removeEdit : _patchName : pickerParamNames[i]];//7/8
    }
    [paramEdits saveToDocs]; //Update edits file on disk

}  //end resetAllEdits

//======(proPanel)==========================================
// called upon reset.. parent resets live output ...
-(void) sendAllParamsToParent
{
    //send vals to delegate...
    for (int i=0;i<MAX_PRO_SLIDERS;i++)
    {
        if (sliderParamNames[i].length > 0)
            [self.delegate didSetProValue : SLIDER_BASE_TAG + i : sliders[i].value : @"" : FALSE];
    }
    for (int i=0;i<MAX_PRO_PICKERS;i++)
    {
        if (pickerParamNames[i].length > 0)
            [self.delegate didSetProValue : PICKER_BASE_TAG + i :
             (int)[pickers[i] selectedRowInComponent:0] : @"" : FALSE];
    }
} //end sendAllParamsToParent

//======(proPanel)==========================================
// 8/13 update session analytics here..
-(void)sliderStoppedDragging:(id)sender
{
    UISlider *slider = (UISlider*)sender;
    int tagMinusBase = (int)(slider.tag-SLIDER_BASE_TAG);
    //8/3 update slider activity count
    if (tagMinusBase>=0 && tagMinusBase<MAX_CONTROL_SLIDERS) sChanges[tagMinusBase]++;
    [paramEdits addEdit: _patchName // 9/27 dont forget to add edit!
                       : sliderParamNames[tagMinusBase]
                       : [NSString stringWithFormat:@"%d",(int)sliders[tagMinusBase].value]];
    [paramEdits saveToDocs];
    NSString *name = sliderParamNames[tagMinusBase]; //7/11 for undo
    float value    = slider.value;
    [self.delegate didSetProValue:tagMinusBase:value:name:TRUE];
} //end sliderStoppedDragging


//======(proPanel)==========================================
// slider tags start at 1000, pickers at 2000
//  9/8 removed level!
-(void)sliderAction:(id)sender
{
    UISlider *slider = (UISlider*)sender;
    float value = slider.value;
    //NSLog(@" slider %@ %f %d",sender,value,slider.tag);
    int itag = (int)slider.tag - SLIDER_BASE_TAG;
#ifdef SWIFT_VERSION //Uses a dictionary!
    //NO NEED FOR THIS CRAP???
    //double dval = (double)value;
    NSNumber *nn = [NSNumber numberWithDouble:(double)value];
    switch (itag)
    {
        case 0: _oogieVoiceResultsDict[@"attack"] = nn;  // value 0..255 for next few
            break;
        case 1: _oogieVoiceResultsDict[@"decay"] = nn;  // value 0..255 for next few
            break;
        case 2: _oogieVoiceResultsDict[@"sustain"] = nn;  // value 0..255 for next few
            break;
        case 3: _oogieVoiceResultsDict[@"slevel"] = nn;  // value 0..255 for next few
            break;
        case 4: _oogieVoiceResultsDict[@"release"] = nn;  // value 0..255 for next few
            break;
        case 5: _oogieVoiceResultsDict[@"duty"] = nn;  // value 0..255 for next few
            break;
        case 6: _oogieVoiceResultsDict[@"nchan"] = nn;  // value 0..255 for next few
            break;
    }
    
#else   //Objective C version uses oogieVoice
    int ival = (int) value;
    switch (itag)
    {
        case 0: _ov.attack = ival;  // value 0..255 for next few
            break;
        case 1: _ov.decay = ival;
            break;
        case 2: _ov.sustain = ival;
            break;
        case 3: _ov.sLevel = ival;
            break;
        case 4: _ov.releaseTime = ival;
            break;
        case 5: _ov.duty = ival;
            break;
        case 6: _ov.nchan = ival;
            break;
        case 7: _ov.vchan = ival;
            break;
        case 8: _ov.pchan = ival;
            break;
        case 9: _ov.sampOffset = ival;
            break;
        case 10: _ov.pLevel = ival;
            break;
        case 11: _ov.pKeyOffset = ival;
            break;
        case 12: _ov.pKeyDetune = ival;
            break;
            //        case 11: _ov.midiChannel = ival;
            //            break;
        default: break;
    }
    if (itag > 12) //handle perc pans 2/12/21
    {
        [_ov OVsetPercLooxPans : itag-13 : ival];
    }
#endif
    
    //9/14 handle ADSR ONLY, is there a better place for this?
    if (itag > -1 && itag < 5 ) //top ADSR controls, 0 thru 4
        [self updateADSRDisplay];

    sliderChanged[itag] = TRUE;
    [self setEdited];
    // 9/23 new name arg for HUD
    int liltag= (int)slider.tag;
#ifdef SWIFT_VERSION
    liltag = (int)slider.tag - SLIDER_BASE_TAG;  //WHY dont we do this w/ objective c ??
#endif
    [self.delegate didSetProValue : liltag : value : sliderDisplayNames[liltag] : FALSE];
} //end  sliderAction


//======(proPanel)==========================================
- (IBAction)helpSelect:(id)sender
{
    [self putUpOBHelpInstructions];
}

//======(proPanel)==========================================
// 8/28 redo w/ bullet points
-(void) putUpOBHelpInstructions
{
    //  #define OB_SILENCE_HELP 1202
// 8/12/21 FIX
//    if ( [pappDelegate getOnboardingFlag : 1202] != 0) return; //No mini help?
//    obp.titleText       = mhelp.obProControlsTitle;
//    obp.blurb1Text      = mhelp.obProControlsBlurb1;
//    obp.blurb2Text      = mhelp.obProControlsBlurb2;   //8/28 add text and attributed bullet points
//    obp.bulletStrings   = mhelp.obProControlsBullets;
//    obp.yTop = _yTop; //9/14 CLUGE tell popup where it is on screen
//    obp.hasBulletPoints = TRUE;
//    obp.obType          = 0; //type doesnt matter here
//    [obp update];
//    [obp bounceIn];
}

//======(proPanel)==========================================
// 8/21 sets sliders directly and they report to parent,
//   pickers values have to be sent to parent here
- (IBAction)diceSelect:(id)sender
{
    float f;
    diceRolls++; //9/9 for analytics
    
    BOOL needChannelSlider[3] = {FALSE,FALSE,FALSE};
    //10/16 move pickers to first part
    //Randomize our 2 / 3 / 8 pickers...
    int row = (int)drand(0,5); //wave (picker)
    [pickers[0] selectRow:row inComponent:0 animated:NO];
    [self updateWorkVoiceForPicker : 0 : row]; //10/4 set voice too!
    [self.delegate didSetProValue : (int)pickers[0].tag : (float)row : @"": FALSE];
    row = (int)drand(0,2); //mono/poly (picker)
    [pickers[1] selectRow:row inComponent:0 animated:NO];
    [self updateWorkVoiceForPicker : 1 : row]; //10/4 set voice too!
    [self.delegate didSetProValue : (int)pickers[1].tag : (float)row : @"": FALSE];
    for (int i=0;i<3;i++) //color channels
    {
        row = (int)drand(0,10); //channels...
        if (row == 9) needChannelSlider[i] = TRUE;
        [pickers[i+2] selectRow:row inComponent:0 animated:NO];
        [self updateWorkVoiceForPicker : i+2 : row]; //10/4 set voice too!
        [self.delegate didSetProValue : (int)pickers[i+2].tag : (float)row : @"": FALSE];
    }
    // 9/2 saw bug, sample being chosen is out of range or unloaded?
// 8/12/21 FIX
//    if (_ov.type == PERCKIT_VOICE)  //randomize percKit stuff if needed
//    {
//        double samps = (double)_sampleNames.count-1;
//        for (int i=0;i<8;i++) //percKit 8 sample/pans
//        {
//            row = (int)drand(0,samps); //channels...
//            [pickers[i+5] selectRow:row inComponent:0 animated:NO];
//            [self updateWorkVoiceForPicker : i+5 : row]; //10/4 set voice too!
//            [self.delegate didSetProValue : (int)pickers[i+5].tag : (float)row : @"": FALSE];
//        }
//    }
    for (int i=0;i<13;i++)
    {
        pickerChanged[i] = TRUE;
    }

    //sliders: 0-5 are ADSR, 6-8 are color channel,9 is sample offset,
    //  and 10-18 are percKit pan
    for (int i=0;i<19;i++) //10/16 randomize all sliders...
    {
        if (sliders[i] != nil) //skip empty spaces
        {
            double slo = sliders[i].minimumValue;
            double shi = sliders[i].maximumValue;
            //special params:
            if (i == 9) //9/8 sample offset, limit range here
            { slo = 0.0; shi = 20.0;}
            BOOL okToChange = TRUE;   //8/27
            // Some sliders can't be accessed under percKit!
            // 8/12/21 FIX if (_ov.type == PERCKIT_VOICE && (i<6 || i==9)) okToChange = FALSE; //10/16
            BOOL needToClear = FALSE; //10/16 for sample offset & channel sliders
            // Sample offset only applies to samples and percussion
            // 8/12/21 FIX if (_ov.type != SAMPLE_VOICE && _ov.type != PERCUSSION_VOICE && i == 9) needToClear = TRUE;
            if (i > 5 && i<9) //6..8 channel sliders?
            {
                if (!needChannelSlider[i-6])  needToClear = TRUE; //no need to set channel slider...
            }
            if (okToChange)
            {
                f = (float)drand(slo,shi);
                if (needToClear) f = 0.0;
                [sliders[i] setValue:f];
                [self sliderAction:sliders[i]];
                sliderChanged[i] = TRUE;
            }
        }
    } //end for int
    [self.delegate updateProModeInfo : @"Randomize Patch" ]; //5/19 improvement
    [self setEdited];   //  5/19

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



//======(proPanel)==========================================
- (IBAction)resetSelect:(id)sender
{
    resets++; //9/9 for analytics
    [self.delegate selectedFactoryReset];  //9/8 parent handles this now
}

////======(proPanel)==========================================
//-(void) factoryReset
//{
//    //NOTE: this needs to access AllPatches!!!
//    [self sendAllParamsToParent];
//    [self resetAllEdits];
//    [self.delegate didFactoryReset];          //9/1 force patch reload
//    //9/1 this is weird: need to reset shit!
//    [self setDefaults];
//    NSLog(@"asdf ok setup sliders etc");
//    [self configureView];
//    _wasEdited = FALSE;
//    resetButton.hidden = !_wasEdited;
//
//}

//======(proPanel)==========================================
// envelope display...
-(void) updateADSRDisplay
{
    //inside the app delegate is an allpatches object, and that
    //  object (swift) has a handle into the synth to pull ADSR image data.
    // simple, huh? needs the imageView for frame purposes
    //NSLog(@" update adsr samp %d",_ov.whichSamp);
    //5/24 make sure we are all legit, must have valid envelope!
// 8/12/21 FIX
//    int tsize = [sfx getEnvelopeSize:_ov.whichSamp];
//    if (tsize > 0) //OK to proceed?
//    {
//        UIImage *dog = [pappDelegate.allp getADSRDisplayWithBptr:_ov.whichSamp adsrImage:adsrImage];
//        if (dog != nil) adsrImage.image = dog; //5/24
//
//    }
}

//======(proPanel)==========================================
//8/3
-(void)updateSessionAnalytics
{
// 8/12/21 FIX
//    for (int i=0;i<MAX_PRO_SLIDERS;i++)
//    {
//        if (sChanges[i] > 0) //report changes to analytics
//        {
//            NSString *sname = psliderKeys[i];
//            [fanal updateSliderCount:sname:sChanges[i]];
//        }
//    }
//    for (int i=0;i<MAX_PRO_PICKERS;i++)
//    {
//        if (pChanges[i] > 0) //report changes to analytics
//        {
//            NSString *pname = ppickerKeys[i];
//            [fanal updatePickerCount:pname:pChanges[i]];
//        }
//    }
//    [fanal updateDiceCount : @"PDI" : diceRolls]; //9/9
//    [fanal updateMiscCount : @"PRE" : resets];    //9/9
//    [self clearAnalytics]; //9/9 clear for next session
} //end updateSessionAnalytics

//======(proPanel)==========================================
-(NSString*) getPickerTitleForTagAndRow : (int) tag : (int) row
{
    //NSLog(@" picker tag %d   row  %d",tag,row);
    if (tag == PICKER_BASE_TAG)
    {
        //NSLog(@"wave slider");
        return synthWaves[row];
    }
    else if (tag == PICKER_BASE_TAG + 1)
    {
        //NSLog(@"onoff slider");
        return onOffs[row];

    }
    else if (tag < PICKER_BASE_TAG+5) //Channels slider? 5/18 fix offset bug
    {
        //NSLog(@"channel slider");
        return channels[row];
    }
    else
    {
        //7/17 CLUGE: need to strip GM stuff off this name!
        NSString *sname = _sampleNames[row];
        if ([sname containsString: @"M0"])
        {
            sname = [sname substringWithRange : NSMakeRange(5,sname.length-5)];
        }
        return sname;
    }
    return @"";

} //end getPickerTitleForTagAndRow

#pragma UIPickerViewDelegate
 

//-------<UIPickerViewDelegate>-----------------------------
//10/4 need to break out for dice!
-(void) updateWorkVoiceForPicker : (int) itag : (int) ival
{
// 8/12/21 FIX 
//    switch (itag)
//    {
//        case 0: _ov.wave = ival;
//            break;
//        case 1: _ov.poly = ival;
//            break;
//        case 2: _ov.noteMode = ival;
//            break;
//        case 3: _ov.volMode = ival;
//            break;
//        case 4: _ov.pan = ival;
//            break;
//        default: break;
//    }
} //end updateWorkVoiceForPicker

//-------<UIPickerViewDelegate>-----------------------------
// 6/18 redo
- (void)pickerView:(UIPickerView *)pickerView didSelectRow: (NSInteger)row inComponent:(NSInteger)component {
    int itag = (int)pickerView.tag-PICKER_BASE_TAG;
    int irow = (int)row; //9/7
    //NSLog(@" selectpicker %d / %d row %d", (int)pickerView.tag,itag,irow);
    [self updateWorkVoiceForPicker:itag:irow];
    pickerChanged[itag] = TRUE;
    if (itag == 0) //10/19  wave?
        sliders[5].hidden = (irow != 2); // 10/19 duty slider only for squares!

    if (itag>=0 && itag<MAX_PRO_PICKERS) pChanges[itag]++;
    if (itag > 4) //sample name picker, special treatment
        irow+=LOAD_SAMPLE_OFFSET;  // add sample offset
    NSLog(@" add edit %@",_patchName);
    [paramEdits addEdit:_patchName //9/7 make sure to save!
                       : pickerParamNames[itag]
                       : [NSString stringWithFormat:@"%d",irow]];
    [paramEdits saveToDocs]; //Update edits file
    [self setEdited];
    // 9/23 new name arg for HUD
    int liltag = (int)pickerView.tag - PICKER_BASE_TAG;
    NSString *pname = pickerDisplayNames[liltag]; //6/11 fix +2 cluge
    BOOL isColorChannel = FALSE; //10/4 move here...9/23 for HUD
    isColorChannel = (itag > 1 && itag < 5);
    if (isColorChannel) pname = [pname stringByAppendingString : @" channel"]; //9/23 for HUD
    [self.delegate didSetProValue : (int)pickerView.tag : (float)row :  pname:TRUE];
} //end pickerView.didSelectRow

 
//-------<UIPickerViewDelegate>-----------------------------
// tell the picker how many rows are available for a given component
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    if (pickerView.tag == PICKER_BASE_TAG)         return 5;
    else if (pickerView.tag == PICKER_BASE_TAG+1)  return 2;
    else if (pickerView.tag < PICKER_BASE_TAG+5)   return 10;
    else //this gets called before samplenames are loaded! must guess! OUCH!
    {
        return 60; //9/6 CLUGE (int)_sampleNames.count;

    }
}

//-------<UIPickerViewDelegate>-----------------------------
// always have ONE component per picker!
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

//-------<UIPickerViewDelegate>-----------------------------
- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view{
    UILabel* tView = (UILabel*)view;
    if (!tView){
        tView = [[UILabel alloc] init];
            // Setup label properties - frame, font, colors etc
        tView.frame = CGRectMake(0,0,200,15); //5/24 shrinkem
        [tView setFont:[UIFont fontWithName:@"Helvetica Neue" size: 16.0]];
    }
    // Fill the label text here
    tView.text = [self getPickerTitleForTagAndRow:(int)pickerView.tag:(int)row];
    return tView;
}


 
//-------<UIPickerViewDelegate>-----------------------------
// tell the picker the width of each row for a given component
- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component {
 int sectionWidth = 250; //was 200  most pickers are wide
 return sectionWidth;
}

//-------<UIPickerViewDelegate>-----------------------------
// 5/24 shrink picker rows more to make neighbors visible
- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component
{
    return 15;
}


//=======<obPopupDelegate>======================================
- (void)obPopupDidSelectOK : (int)obType
{
}

//=======<obPopupDelegate>======================================
- (void)obPopupDidSelectEnoughHelp : (int)obType
{
    //10/24 tell app Delegate to turn off minihelp... WHY do i need to use constant here!?
    // 8/12/21 FIX [pappDelegate setOnboardingFlag : OB_SILENCE_HELP : 2]; //8/21 add int arg
}

// 8/12 for now just dismiss this panel!
- (void)demoNotification:(NSNotification *)notification
{
     _isUp = FALSE; //8/21
     //[self dismissViewControllerAnimated : YES completion:nil];
}

@end
