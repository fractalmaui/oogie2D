//
//               _       _     ____                  _
//   _ __   __ _| |_ ___| |__ |  _ \ __ _ _ __   ___| |
//  | '_ \ / _` | __/ __| '_ \| |_) / _` | '_ \ / _ \ |
//  | |_) | (_| | || (__| | | |  __/ (_| | | | |  __/ |
//  | .__/ \__,_|\__\___|_| |_|_|   \__,_|_| |_|\___|_|
//  |_|
//
//  OogieCam patchPanel.m
//
//  Redone by Dave Scruton on 9/28/21
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//
//  9/30  ADSR display still needs fixing!
//        New for oogieAR: edits are stored as raw slider / control values,
//          let OogiePatchParams figure out display values
//  10/3 add indices to sliders/pickers
//         pull factoryReset, add resetControls
//  11/5   add makeADSRImage , general code cleanup
//  11/24  redo envelope display, generate ADSR herein!, cleanup non-percKit randomize
//  11/29  cosmetic, add bottom bevel panel
//  12/13  fix bug hiding bevelPanel, add NEED_ARROWS
//  12/21  add upanel hide/show to configureView, cleanup also
//             pull all left/right button stuff
#define ARC4RANDOM_MAX      0x100000000
#define PERCKIT_VOICE 2

#define SWIFT_VERSION

#import "patchPanel.h"
@implementation patchPanel

double drand(double lo_range,double hi_range);

//Color channel choices...
NSString *channels[] = {@"Red",@"Green",@"Blue",
    @"Hue",@"Lum",@"Sat",@"Cyan",
    @"Mag",@"Yel",@"Slider"
};

NSString *synthWaves[] = {@"Sine",@"Saw",@"Square",
    @"Ramp",@"Noise"
};

NSString *onOffs[] = {@"Off",@"On"};

float env256[256]; //work array used in envelope rendering


//======(patchPanel)==========================================
- (id)init
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        NSLog(@"patchPanel init...");
        goog = [genOogie sharedInstance]; //MUST setup before UI!
        paramEdits = [edits sharedInstance];  //for saving param edits in documents
        _isUp = FALSE; //8/21
        paAllParams   = nil;
        paSliderNames = nil;
        paPickerNames = nil;
        allSliders = [[NSMutableArray alloc] init];
        allPickers = [[NSMutableArray alloc] init];
        
        //8/13 flurry analytics
        // 8/12/21 FIX fanal = [flurryAnalytics sharedInstance];
        sfx   = [soundFX sharedInstance]; //8/27
        _randomized = FALSE; //9/29
        _oogieVoiceResultsDict = [[NSMutableDictionary alloc] init];
    }
    return self;
} //end init


//======(patchPanel)==========================================
//10/1 new storage
-(void) setupCannedData
{
    if (paAllParams != nil) return; //only go thru once!
    //NSLog(@" setup canned patch Param data...");
    paAllParams = @[@"wave",
                    @"attack",@"decay",@"sustain",@"slevel",@"release",
                    @"duty",@"sampleoffset", @"plevel", @"pkeyoffset" ,@"pkeydetune",
                    @"percloox_0", @"perclooxpans_0",
                    @"percloox_1", @"perclooxpans_1",
                    @"percloox_2", @"perclooxpans_2",
                    @"percloox_3", @"perclooxpans_3",
                    @"percloox_4", @"perclooxpans_4",
                    @"percloox_5", @"perclooxpans_5",
                    @"percloox_6", @"perclooxpans_6",
                    @"percloox_7", @"perclooxpans_7"
    ];
    paSliderNames = @[@"Attack",@"Decay",@"Sustain",
                      @"SLevel",@"Release",@"Duty",
                      @"SampOff%",
                      @"Level", @"KeyOff" , @"KeyTune",  //2/12/21
                      @"",@"",@"",@"",
                      @"",@"",@"",@"" //placeholders for perckit
    ];
    paPickerNames = @[@"Wave",
                      @"PercKit Sample 1",@"PercKit Sample 2",@"PercKit Sample 3",@"PercKit Sample 4",
                      @"PercKit Sample 5",@"PercKit Sample 6",@"PercKit Sample 7",@"PercKit Sample 8"];
    
} //end setupCannedData

//======(patchPanel)==========================================
// 10/1 this now gets called from parent
// Create all the controls in this panel.
// NOTE All frames are computed geometrically, so the UI
//  will be basically the same on any device XY scale.
// NOTE Super wide devices like iPad in landscape orientation
//  will have controls that are flat and squished out!
-(void) setupView:(CGRect)frame
{
    NSLog(@"patchPanel setupView...");
    [self setupCannedData];

    viewWid    = frame.size.width;
    viewHit    = frame.size.height;
    buttonWid = viewWid * 0.12; //10/4 REDO button height,scale w/width
    // 8/12/21 FIX if (pappDelegate.gotIPad) //12/11 smaller buttons on ipad!
    // 8/12/21 FIX     buttonWid = viewWid * 0.06;  // ...by half?
    buttonHit = OOG_HEADER_HIT;
    self.frame = frame;
    self.backgroundColor = [UIColor blueColor]; // 6/19/21 colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.1];
    int xs,ys,xi,yi;
    
    int iSlider = 0; //10/3 keep slider / picker count
    int iPicker = 0;
    int iParam  = 0;

    xi = 0;
    yi = 0;
    xs = viewWid;
    ys = viewHit;
    scrollView = [[UIScrollView alloc] init];
    scrollView.frame = CGRectMake(xi,yi,xs,ys);
    scrollView.backgroundColor = [UIColor yellowColor]; // 6/19/21 [UIColor colorWithRed:0 green:0 blue:0.2 alpha:1]; //[UIColor blueColor]; //blackColor]; //[UIColor redColor];
    scrollView.showsVerticalScrollIndicator = TRUE;
//    // Panel heights... redid 5/20 for taller sliders
//    uHit  = 140;  //universal (top) panel
//    eHit  = 255;  //envelope generator panel 7/9/21 adjust
//    cHit  = 215;  //channel panel 7/9/21 adjust
//    ftHit = 150;  //FineTune panel 2/12/21
//    mHit  = 0;    // 9/23 no midi panel   95;   //midi panel
//    pkHit = 650;  //percKit panel  7/9/21 adjust
    [self addSubview:scrollView];

#ifdef NEED_ARROWS

    xi = 0; //10/1 add edit label / button
    yi = 0;
    xs = viewWid;
    ys = OOG_MENU_CURVERAD;
    UILabel *editLabel = [[UILabel alloc] initWithFrame:
                   CGRectMake(xi,yi,xs,ys)];
    [editLabel setBackgroundColor : [UIColor redColor]];
    [editLabel setTextColor : [UIColor whiteColor]];
    [editLabel setFont:[UIFont fontWithName:@"Helvetica Neue" size: 22.0]];   //11/19
    editLabel.text = @"Edit Voice";
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
    xs = viewWid - 2*OOG_XMARGIN;
    ys = OOG_HEADER_HIT;  //7/9
    header = [[UIView alloc] init];
    header.frame = CGRectMake(xi,yi,xs,ys);
    header.backgroundColor = [UIColor blackColor];
    header.layer.shadowColor   = [UIColor blackColor].CGColor;
    header.layer.shadowOffset  = CGSizeMake(0,10);
    header.layer.shadowOpacity = 0.3;
    [self addSubview:header];
 
    yi = 0;
    xs = viewWid*0.5; //9/16 not too wide
    xi = viewWid * 0.5 - xs*0.5;
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:
                           CGRectMake(xi,yi,xs,ys)];
    [titleLabel setTextColor : [UIColor whiteColor]];
    [titleLabel setFont:[UIFont fontWithName:@"Helvetica Neue" size: 22.0]];   //11/19
    titleLabel.text = @"Patch Edit";
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [header addSubview : titleLabel];
    
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
    goRightButton.enabled = FALSE;  //9/30
    int panelY    = 60; //8/6 move down for title/help button
#else
    int panelY  = 0; //for top panel...
#endif
    int panelSkip = 5; //Space between panels
    int panelTopMargin = 3;
    
    //universal panel...
    xi = OOG_XMARGIN; //6/19/21
    xs = viewWid - 2*OOG_XMARGIN;
    
    // 7/9 calculate height based on controls
    uHit = 1*OOG_PICKER_HIT + 2*OOG_YMARGIN; //10/2 smaller size
    uPanel = [[UIView alloc] init];
    [uPanel setFrame : CGRectMake(xi,panelY,xs,uHit)];
    uPanel.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.5 alpha:1];
    [scrollView addSubview:uPanel];
    yi = panelTopMargin;
    // args: parent, tag, label, yoff, ysize
    //Add Pickers for Wave
    [self addPickerRow:uPanel : iPicker : PICKER_BASE_TAG + iParam : paPickerNames[iPicker] : yi : OOG_PICKER_HIT];
    yi += (OOG_PICKER_HIT - 15); //5/24 test squnch pickers together
    iPicker++;
    iParam++;

    //envelope panel next... series of 6 sliders
    panelY += (uHit+panelSkip);
    xi = OOG_XMARGIN; //6/19/21
    xs = viewWid - 2*OOG_XMARGIN;
    // 7/9 calculate height based on controls
    eHit = 7*OOG_SLIDER_HIT + OOG_PICKER_HIT + 6*OOG_YSPACER + 2*OOG_YMARGIN;
    ePanel = [[UIView alloc] init];
    [ePanel setFrame : CGRectMake(xi,panelY,xs,eHit)];
    ePanel.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.5 alpha:1];
    [scrollView addSubview:ePanel];
    yi = 2*panelTopMargin;
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
    for (int i = 0;i<7;i++) //first slider is in ADSR now 9/8
    {
        yi += (OOG_SLIDER_HIT+2);
        [self addSliderRow:ePanel : iSlider : SLIDER_BASE_TAG + iParam : paSliderNames[iSlider] : yi : OOG_SLIDER_HIT:0.0:1.0];
        iSlider++;
        iParam++;
    }

    panelY += (eHit+panelSkip);
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

    for (int i = 0;i<3;i++)   //3 finetune items...
    {
        yi += (OOG_SLIDER_HIT+2);
        [self addSliderRow:ftPanel : iSlider : SLIDER_BASE_TAG + iParam : paSliderNames[iSlider] : yi : OOG_SLIDER_HIT:0.0:1.0]; //10/3 typo
        iSlider++;
        iParam++;
    }
    
    //PercKit Panel (optional depending on patch type)
    //    panelY += (mHit+panelSkip); //use this if MIDI panel is present
    pkPanel = [[UIView alloc] init];
    xi = OOG_XMARGIN; //6/19/21
    xs = viewWid - 2*OOG_XMARGIN;
    pkHit = 10*OOG_SLIDER_HIT + 8*OOG_PICKER_HIT + 8*OOG_YSPACER + 2*OOG_YMARGIN;
    //11/29 add rounded panel beneath our last panel , cosmetic
    bevelPanel = [[UIView alloc] init]; //12/13 make class member name / comments panel...
    [bevelPanel setFrame : CGRectMake(xi,panelY+20,xs,pkHit)]; //asdf
    bevelPanel.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.7 alpha:1];
    bevelPanel.layer.cornerRadius = 20;
    bevelPanel.clipsToBounds      = TRUE;
    [scrollView addSubview:bevelPanel];
    //this is the panel controls are added to
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
    percKitParamStart = iParam; //11/24 keep track of percKit top param#
    for (int i = 0;i<8;i++)   //add 8 sets of pickers and sliders
    {
        yi += (OOG_SLIDER_HIT+4);
        NSString *pname = [NSString stringWithFormat:@"Sample %d",i+1];
        [self addPickerRow:pkPanel : iPicker : PICKER_BASE_TAG + iParam : pname : yi : OOG_PICKER_HIT];
        iPicker++;
        iParam++;
        yi += OOG_PICKER_HIT; // - 20; //5/24 test squnch
        NSString *sname = [NSString stringWithFormat:@"Pan %d",i+1];
        // 7/18/21 fix bad 3rd arg...
        [self addSliderRow:pkPanel : iSlider : SLIDER_BASE_TAG + iParam : sname : yi : OOG_SLIDER_HIT:0.0:1.0];
        iSlider++;
        iParam++;
    }
    
    int scrollHit = 1300; //11/13 add room at bottom
    scrollView.contentSize = CGSizeMake(viewWid, scrollHit);

} //end setupView


//======(patchPanel)==========================================
- (void) resizeView : (CGRect)frame
{
    self.frame = frame;
    scrollView.frame = frame;
}

//======(patchPanel)==========================================
- (BOOL)prefersStatusBarHidden
{
    return YES;
}

//======(controlPanel)==========================================
// 9/16 redo adds a canned label/picker set...
-(void) addPickerRow : (UIView*) parent : (int) index : (int) tag : (NSString*) label : (int) yoff : (int) ysize
{
    //NSLog(@" add picker[%d] %@ to picker[%d]",tag,label,index);
    NSArray* A = [goog addPickerRow : parent : tag : label : yoff : viewWid : ysize];
    if (A.count > 0)
    {
        UIPickerView * picker = A[0];
        picker.delegate   = self;
        picker.dataSource = self;
        //10/1 pickers[index] = picker;
        [allPickers addObject:picker];
    }
} //end addPickerRow


//======(controlPanel)==========================================
// 9/15 redo w/ genOogie method!
-(void) addSliderRow : (UIView*) parent : (int) index : (int) tag : (NSString*) label :
                (int) yoff : (int) ysize : (float) smin : (float) smax
{
    //NSLog(@" add slider[%d] %@",tag,label);
    //9/15 new UI element...
   NSArray* A = [goog addSliderRow : parent : tag : paSliderNames[index] :
                           yoff : viewWid: ysize :smin : smax];
   if (A.count > 0)
      {
        UISlider* slider = A[0];
        // hook it up to callbacks
        [slider addTarget:self action:@selector(sliderAction:) forControlEvents:UIControlEventValueChanged];
        [slider addTarget:self action:@selector(sliderStoppedDragging:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
          [allSliders addObject:slider];
          //10/1  sliders[index] = slider;
        }
} //end addSliderRow


//======(patchPanel)==========================================
-(void) setEdited
{
    if (!_wasEdited)  //7/18 show reset on change
    {
        _wasEdited = TRUE;
        //9/29 only allow reset on factory patches!!!
        //NSLog(@" set reset button hidden %d",(!_wasEdited || _randomized));
        resetButton.hidden = (!_wasEdited || _randomized);  //NOT on randomized ones
    }
} //end setEdited


//======(patchPanel)==========================================
-(void) configureView
{
    // dig out type param ... percKit type is special!
    NSArray *ra = _paramDict[@"type"];
    NSNumber *nn = @0;  //10/2 handle nil errz
    if (ra != nil && ra.count >0) nn = ra.lastObject;
    patchType = nn.intValue; //12/13 wups was in wrong place
    //Load sample names into all perc pickers...
    NSString *s = @"no name"; //get voice name for title
    NSArray *a  = [_paramDict objectForKey:@"name"];
    if (a.count > 0) s = a.lastObject;
    [self configureViewWithReset : FALSE];
    //handle percKit pickers...
    int percPickerOffset = 1; //10/2
    BOOL gotPercKit = (patchType == PERCKIT_VOICE); //12/21
    if (gotPercKit)
    {
        for (int i=0;i<8;i++)
        {
            NSString *pname = [NSString stringWithFormat:@"percloox_%d",i];
            NSArray *ra = _paramDict[pname];
            int whichPicker = i + percPickerOffset;
            if (ra != nil)
            {
                [allPickers[whichPicker] reloadAllComponents]; //10/2 OUCH! watch addressing here!!!
                NSString *ss = ra[ra.count-1];
                NSUInteger foundit = [_sampleNames indexOfObject:ss];
                if (foundit != NSNotFound) //10/2 got a match
                    [allPickers[whichPicker] selectRow: foundit inComponent:0 animated:YES];
            }
        } //end i loop
    } //end nn.intValue
    else
    {
        for (int i=1;i<6;i++)
        {
            NSString *pname = paAllParams[i];
            NSArray *paramz = _paramDict[pname];
            if (paramz != nil)
            {
                NSNumber *nn = paramz.lastObject; //get default value...
                [self setLocalEnvelopeValsByIndex:i :nn.floatValue];
            }
        }
        [goog buildEnvelope256:aa:dd:ss:slsl:rr:env256];
        adsrImage.image = [goog makeADSRImage:256 :64 : env256];
    }
    //12/21 new enable/disables
    [self enableUPanelControls : (patchType == SYNTH_VOICE)];
    [self enableADSRControls   : !gotPercKit];
    pkPanel.hidden             = !gotPercKit;
    bevelPanel.hidden          = !gotPercKit;

    int scrollHit = gotPercKit ? 1300 : 600; //12/21 vary scroll height
    scrollView.contentSize = CGSizeMake(viewWid, scrollHit);


    NSArray *edits = [paramEdits getEditKeys:_patchName]; //10/3 check for edits
    if (edits && edits.count > 0) [self setEdited];
} //end configureView

//======(patchPanel)==========================================
// This is huge. it should be made to work with any control panel!
-(void) configureViewWithReset : (BOOL)reset
{
    NSMutableArray *alltext = [[NSMutableArray alloc] init]; //NO TEXT FIELDS YET
    NSArray *noresetparams = @[];   //@"patch",@"soundpack",@"name"];
    NSMutableDictionary *pickerchoices = [[NSMutableDictionary alloc] init];
    NSDictionary *resetDict = [goog configureViewFromVC:reset : _paramDict : paAllParams :
                     allPickers : allSliders : alltext :
               noresetparams : pickerchoices];
    resetButton.hidden = !_wasEdited;

} //end configureViewWithReset

//======(patchPanel)==========================================
// 9/18/21 Sends a limited set of updates to parent
//        only called on randomize now!
-(void) sendUpdatedParamsToParent : (NSDictionary*) paramsDict
{
    for (NSString*key in paramsDict.allKeys)
    {
        NSArray *ra = paramsDict[key];
        NSNumber *nt = ra[0];
        NSNumber *nv = ra[1];
        NSString *ns = ra[2];
        [self.delegate didSetPatchValue:nt.intValue:nv.floatValue:key:ns:FALSE];
        // 10/3 add edits for each randomized param...
        [paramEdits addEdit: _patchName // 10/3 dont forget to add edit!
                           : key
                           : [NSString stringWithFormat:@"%f", nv.floatValue]];
    }
    [paramEdits saveToDocs]; // 10/3
} //end sendUpdatedParamsToParent

//======(patchPanel)==========================================
// 5/19 sets ADSR on/off
-(void) enableADSRControls : (BOOL) enabled
{
    adsrImage.hidden = !enabled;
    for (int i = 0;i<7;i++) //12/20 add sampleoff to sliders included herein
    {
        UISlider *s = (UISlider*)allSliders[i];
        s.enabled = enabled;
    }
} //end enableADSRControls
 
//======(patchPanel)==========================================
// 12/21 sets top panel on/off
-(void) enableUPanelControls : (BOOL) enabled
{
    for (int i = 0;i<1;i++) //12/20 add sampleoff to pickers included herein
    {
        UIPickerView *p = (UIPickerView*)allPickers[i];
        [p setUserInteractionEnabled:enabled];
    }
} //end enableUPanelControls
 
//======(patchPanel)==========================================
// 8/3 update session analytics here..
-(void)sliderStoppedDragging:(id)sender
{
    [self updateSliderAndDelegateValue : sender : FALSE]; //9/23
    UISlider *slider = (UISlider*)sender;
    int tagMinusBase = (int)(slider.tag%1000);

    //NSLog(@"tag %d wavebuf %d",tagMinusBase,nn.intValue);
    if (tagMinusBase > 0 && tagMinusBase < 6) //11/5 envelope control?
    {
        [goog buildEnvelope256:aa:dd:ss:slsl:rr:env256];
        adsrImage.image = [goog makeADSRImage:256 :64 : env256];
    }
    
    [paramEdits addEdit: _patchName // 9/27 dont forget to add edit!
                       : paAllParams[tagMinusBase]
                       : [NSString stringWithFormat:@"%f", slider.value]]; //9/30 save float
    [paramEdits saveToDocs];
}

//======(patchPanel)==========================================
-(void)sliderAction:(id)sender
{
    [self updateSliderAndDelegateValue : sender : FALSE]; //9/23
}

//======(patchPanel)==========================================
// 11/24 for local envelope display
-(void) setLocalEnvelopeValsByIndex : (int) index : (float)value
{
    switch (index)
    {
        case 1: aa   = value; break;
        case 2: dd   = value; break;
        case 3: ss   = value; break;
        case 4: slsl = value; break;
        case 5: rr   = value; break;
        default: break;
    }
} //end setLocalEnvelopeValsByIndex

//======(patchPanel)==========================================
//called when slider is moved and on dice/resets!
-(void) updateSliderAndDelegateValue :(id)sender : (BOOL) dice
{
    if (!_wasEdited) {_wasEdited = TRUE; resetButton.hidden = FALSE;} //9/8 show reset button now!
    UISlider *slider = (UISlider*)sender;
    int tagMinusBase = ((int)slider.tag % 1000); // 7/11 new name
    float value = slider.value;
    
    //11/24 crude: get ADSR values for local display
    if (tagMinusBase > 0 && tagMinusBase < 6) //adsr?
        [self setLocalEnvelopeValsByIndex:tagMinusBase :value];
    NSString *name = dice ? @"" : paAllParams[tagMinusBase];
    [self.delegate didSetPatchValue:tagMinusBase:value:paAllParams[tagMinusBase]:name:TRUE];
} //end updateSliderAndDelegateValue

//======(controlPanel)==========================================
- (IBAction)dismissSelect:(id)sender
{
    [self.delegate didSelectPatchDismiss];
}

//======(patchPanel)==========================================
// 9/18  make this generic too, and return a list of updates for delegate.
// THEN add a method to go thru the updates dict and pass to parent,
//    and reuse this method here and in configureView!
-(void) randomizeParams
{
    NSMutableArray *norandomizeparams = [NSMutableArray arrayWithArray: @[@"patch",@"soundpack",@"name",@"comment",@"delaysustain",@"threshold"] ];
    if (patchType != PERCKIT_VOICE) // dont randomize any perckit stuff....
    {
        for (int i=percKitParamStart;i<percKitParamStart + 16;i++)
            [norandomizeparams addObject:paAllParams[i]];
    }

    NSMutableDictionary *resetDict = [goog randomizeFromVC : paAllParams : allPickers : allSliders : norandomizeparams];
    //11/24: NOTE for patch types that are NOT percKit, we should strip out any perkloox / pans!!!
    [self sendUpdatedParamsToParent:resetDict];
    [self.delegate didSelectPatchDice]; //4/29
    //OUCH! how do i reload new ADSR to display?
    [self setADSRFromRandomizeResults : resetDict]; //RELOAD adsr vars from returned stuff
    [goog buildEnvelope256:aa:dd:ss:slsl:rr:env256]; //11/24 dont forget ADSR!
    adsrImage.image = [goog makeADSRImage:256 :64 : env256];

    diceRolls++; //9/9 for analytics
    diceUndo = FALSE;
    rollingDiceNow = FALSE;
} //end randomizeParams

//======(patchPanel)==========================================
-(void) setADSRFromRandomizeResults : (NSMutableDictionary *) resetD
{
    for (int i=1;i<7;i++)
    {
        NSString *pname = paAllParams[i];
        NSArray *a = resetD[pname];
        if (a.count > 1) //got valid return set? extract ADSR field# and vaue
        {
            NSNumber *nn0 = a[0]; //get index
            NSNumber *nn1 = a[1]; //get value
            [self  setLocalEnvelopeValsByIndex : nn0.intValue   : nn1.floatValue];
        }
    }
}

//======(patchPanel)==========================================
// 8/21 sets sliders directly and they report to parent,
//   pickers values have to be sent to parent here
- (IBAction)diceSelect:(id)sender
{
    [paramEdits removeAllEdits : _patchName]; // 11/25 remove old edits!
    [self randomizeParams  ];
    resetButton.hidden = FALSE; //indicate param change
} //end diceSelect

//======(patchPanel)==========================================
- (IBAction)resetSelect:(id)sender
{
    [paramEdits removeAllEdits : _patchName]; // 10/3
    //10/3 tell parent to reset
    [self.delegate didSelectPatchReset];  //10/3
    resetButton.hidden = TRUE;
    _wasEdited = FALSE;
}

//======(patchPanel)==========================================
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
// 6/18 redo
- (void)pickerView:(UIPickerView *)pickerView didSelectRow: (NSInteger)row inComponent:(NSInteger)component {
    if (!_wasEdited) {_wasEdited = TRUE; resetButton.hidden = FALSE;} //9/8 show reset button now!
    int liltag = (int)pickerView.tag % 1000; //just pass tags to parent now
    NSString *sname = [NSString stringWithFormat:@"%d",(int)row]; // first picker? pack choice
    if (liltag > 1 && (row >= 0 && row < _sampleNames.count)) //2nd..picker? chose a sample? get name!
        sname = _sampleNames[row];
    [self.delegate didSetPatchValue:liltag :(float)row : paAllParams[liltag] : sname :
                                    !rollingDiceNow && !resettingNow];   //7/11
    //8/3 update picker activity count
    // ANALYTICS if (liltag>=0 && liltag<allPickers.count) pChanges[liltag]++;
    [paramEdits addEdit:_patchName //9/7 make sure to save!
                       : paAllParams[liltag]
                       : sname];
    [paramEdits saveToDocs]; //Update edits file

}
 
//-------<UIPickerViewDelegate>-----------------------------
// tell the picker how many rows are available for a given component
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    if (pickerView.tag == PICKER_BASE_TAG)         return 5;
    else //this gets called before samplenames are loaded! must guess! OUCH!
    {
        return _sampleNames.count;
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


@end
