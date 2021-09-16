//  OogieCam shapePanel
//
//  Created by Dave Scruton on 9/12/20.
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.



#import "shapePanel.h"
//#import "AppDelegate.h" //KEEP this OUT of viewController.h!!

@implementation shapePanel

#define NORMAL_CONTROLS
#define GOT_DIGITALDELAY

double drand(double lo_range,double hi_range );

//AppDelegate *cappDelegate;
NSString *ssliderNames[] = {@"Rotation",@"Shape XPos",@"Shape YPos",@"Shape ZPos",
    @"Tex UPos",@"Tex YPos",@"Tex UScale",@"Tex VScale"
}; //2/19 note paddings b4 delay for vibwave
NSString *spickerNames[] = {@"Texture",@"RotType"};
NSString *stextFieldNames[] = {@"Texture",@"Name",@"Comments"};

//9/12 dupe from oogieShape, use swift vars if possible?
int numRotTypeParams = 9;
NSString *rotTypeParams [] = {@"Manual", @"BPMX1", @"BPMX2", @"BPMX3", @"BPMX4", @"BPMX5", @"BPMX6", @"BPMX7", @"BPMX8"};

//for analytics use: simple 3 letter keys for all controls
//  first char indicates UI, then 2 letters for control
// sliders are grouped: 3 at top, then a picker, then four more.
/// 9/12 do i need padding after SRO???
NSString *ssliderKeys[] = {@"SRO",@"---",@"SXP",@"SYP",@"SZP",
                @"SUP",@"SVP",@"SUS",@"SVS",};

NSString *spickerKeys[] = {@"LKS",@"LVW",@"LAW"};



//======(shapePanel)==========================================
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


//======(shapePanel)==========================================
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
    titleLabel.text = @"Shape";
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

    // texture picker
    [self addPickerRow:sPanel : 0 : PICKER_BASE_TAG+0 : spickerNames[0] : yi : OOG_PICKER_HIT];
    yi +=  (OOG_PICKER_HIT+OOG_YSPACER);

    // rotation slider
    [self addSliderRow:sPanel : 0 : SLIDER_BASE_TAG + 1 : ssliderNames[0] : yi : OOG_SLIDER_HIT:0.0:100.0];
    yi += (OOG_SLIDER_HIT+OOG_YSPACER);

    // rotation type picker
    [self addPickerRow:sPanel : 1 : PICKER_BASE_TAG+2 : spickerNames[1] : yi : OOG_PICKER_HIT];
    yi +=  (OOG_PICKER_HIT+OOG_YSPACER);

    // XYZ position
    for (i=0;i<3;i++)
    {
        [self addSliderRow:sPanel : i+1 : SLIDER_BASE_TAG + 3 + i : ssliderNames[i+1] : yi : OOG_SLIDER_HIT:-10.0:10.0];
        yi += (OOG_SLIDER_HIT+OOG_YSPACER);
    }
    // U/V offset
    for (i=0;i<2;i++)
    {
        [self addSliderRow:sPanel : i+4 : SLIDER_BASE_TAG + 6 + i : ssliderNames[i+4] : yi : OOG_SLIDER_HIT:0.0:100.0];
        yi += (OOG_SLIDER_HIT+OOG_YSPACER);
    }
    // U/V scale
    for (i=0;i<2;i++)
    {
        [self addSliderRow:sPanel : i+7 : SLIDER_BASE_TAG + 8 + i : ssliderNames[i+7] : yi : OOG_SLIDER_HIT:1.0:100.0];
        yi += (OOG_SLIDER_HIT+OOG_YSPACER);
    }

    //9/11 text entry fields...
    yi+=ys;
    [self addTextRow:sPanel :0 :TEXT_BASE_TAG+9 :@"Name" :yi :OOG_TEXT_HIT ];
    yi+=ys;
    [self addTextRow:sPanel :1 :TEXT_BASE_TAG+10 :@"Comment" :yi :OOG_TEXT_HIT ];

    
    UIView *vLabel = [[UIView alloc] init];
    xi = viewWid;
    yi = viewHit/2;
    xs = 30;
    ys = 120;
    [vLabel setFrame : CGRectMake(xi,yi,xs,ys)];
    
    vLabel.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1];
    [self addSubview:vLabel];

    
    //Scrolling area...
    int scrollHit = 1200; //8/12 760; //640;  //5/20 enlarged again asdf
    //if (cappDelegate.gotIPad) scrollHit+=120; //3/27 ipad needs a bit more room
    
    scrollView.contentSize = CGSizeMake(viewWid, scrollHit);
                         
    [self clearAnalytics];

} //end setupView

//======(shapePanel)==========================================
//9/9 for session analytics
-(void) clearAnalytics
{
    //8/3 for session analytics: count activities
    diceRolls = 0; //9/9 for analytics
    resets    = 0; //9/9 for analytics
    for (int i=0;i<MAX_CONTROL_SLIDERS;i++) sChanges[i] = 0;
    for (int i=0;i<MAX_CONTROL_PICKERS;i++) pChanges[i] = 0;
}
 
//======(shapePanel)==========================================
// 9/7 ignore slider moves!
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
      if ([touch.view isKindOfClass:[UISlider class]]) {
          return NO; // ignore the touch
      }
      return YES; // handle the touch
}

//======(shapePanel)==========================================
- (BOOL)prefersStatusBarHidden
{
    return YES;
}

//======(shapePanel)==========================================
-(void) setDefaults
{
    _textNum = 0; //Hopefully our default test pattern
    _xPos = _yPos = _zPos = 0.0;
    _uCoord = _vCoord = 0.0;
    _uScale = _vScale = 1.0;
    _rotation = 1.0;  //TBD
    _rotSpeed = 1.0;
    _sname        = @"empty name";
    _scomment     = @"empty comment";
}

//======(shapePanel)==========================================
// 9/15 redo w/ genOogie method!
-(void) addSliderRow : (UIView*) parent : (int) index : (int) tag : (NSString*) label :
                (int) yoff : (int) ysize : (float) smin : (float) smax
{
    //9/12 note we user smin/smax here
NSArray* A = [goog addSliderRow : parent : tag : ssliderNames[index] :
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

//======(shapePanel)==========================================
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


//======(shapePanel)==========================================
// adds a canned label/picker set...
-(void) addPickerRow : (UIView*) parent : (int) index : (int) tag : (NSString*) label : (int) yoff : (int) ysize
{
    //9/15 new UI element...
     NSArray* A = [goog addPickerRow : parent : tag : spickerNames[index] :
                                  yoff : viewWid : ysize];
    if (A.count > 0)
    {
        UIPickerView * picker = A[0];
        picker.delegate   = self;
        picker.dataSource = self;
        pickers[index] = picker;
    }

} //end addPickerRow


//======(shapePanel)==========================================
// 9/11 textField... for oogie2D/AR
-(void) addTextRow : (UIView*) parent : (int) index : (int) tag : (NSString*) label :
                (int) yoff : (int) ysize
{
    //9/15 new UI element...
    NSArray* A = [goog addTextRow : parent : tag : stextFieldNames[index] : yoff : viewWid : ysize];
   if (A.count > 0)
      {
          UITextView * textField = A[0];
          textField.delegate     = self;
          textFields[index]      = textField;
      }
} //end addSliderRow



//======(shapePanel)==========================================
//  Updates our controls...
//  NOTE: tag 0 cannot be used with buttons, makes bad stuff happen
-(void) configureView
{
    [pickers[0] selectRow:_textNum inComponent:0 animated:YES];
    [sliders[0] setValue:_rotation];
    //Is this right?
    [pickers[1] selectRow:_rotType inComponent:0 animated:YES];
    [sliders[1] setValue:_xPos];
    [sliders[2] setValue:_yPos];
    [sliders[3] setValue:_zPos];
    [sliders[4] setValue:_uCoord];
    [sliders[5] setValue:_vCoord];
    [sliders[6] setValue:_uScale];
    [sliders[7] setValue:_vScale];
    
    //9/11 add name/comment text fields
    [textFields[0] setText:_sname];
    [textFields[1] setText:_scomment];

    resetButton.hidden = !_wasEdited;

    NSLog(@" set up shape pickers");
    [pickers[0] reloadAllComponents];
    [pickers[1] reloadAllComponents];
    
}  //end configureView


//======(shapePanel)==========================================
// 8/6 wups, had wrong param order!
-(void) sendAllParamsToParent
{
//    [self.delegate didSetControlValue:0  :_threshold:@"":FALSE]; //7/11 add undoable arg
//    [self.delegate didSetControlValue:1  :_bottomMidi:@"":FALSE];
//    [self.delegate didSetControlValue:2  :_topMidi:@"":FALSE];
//    [self.delegate didSetControlValue:3  :(float)_keySig:@"":FALSE];
//    [self.delegate didSetControlValue:4  :_overdrive:@"":FALSE];
//    [self.delegate didSetControlValue:5  :_portamento:@"":FALSE];
//    [self.delegate didSetControlValue:6  :_vibLevel:@"":FALSE];
//    [self.delegate didSetControlValue:7  :_vibSpeed:@"":FALSE];
//    [self.delegate didSetControlValue:8  :_vibWave:@"":FALSE];
//    [self.delegate didSetControlValue:9  :_vibeLevel:@"":FALSE]; //7/4/11 wups, forgot new params!
//    [self.delegate didSetControlValue:10 :_vibeSpeed:@"":FALSE];
//    [self.delegate didSetControlValue:11 :_vibeWave:@"":FALSE];
//    [self.delegate didSetControlValue:12 :_delayTime:@"":FALSE];
//    [self.delegate didSetControlValue:13 :_delaySustain:@"":FALSE];
//    [self.delegate didSetControlValue:14 :_delayMix:@"":FALSE];
}

//======(shapePanel)==========================================
// 8/3 update session analytics here..
-(void)sliderStoppedDragging:(id)sender
{
    UISlider *slider = (UISlider*)sender;
    int tagMinusBase = (int)(slider.tag-SLIDER_BASE_TAG);
    //8/3 update slider activity count
    if (tagMinusBase>=0 && tagMinusBase<MAX_CONTROL_SLIDERS) sChanges[tagMinusBase]++;
    NSString *name = ssliderNames[tagMinusBase]; //7/11 for undo
    float value    = slider.value;
    NSLog(@" send shape value: UNCOMMENT! %d %d",tagMinusBase,value);
    [self.delegate didSetShapeValue:tagMinusBase:value:name:TRUE];
}

//======(shapePanel)==========================================
-(void)sliderAction:(id)sender
{
    [self updateSliderAndDelegateValue : sender : FALSE]; //9/23
}

//======(shapePanel)==========================================
//called when slider is moved and on dice/resets!
-(void) updateSliderAndDelegateValue :(id)sender : (BOOL) dice
{
    if (!_wasEdited) {_wasEdited = TRUE; resetButton.hidden = FALSE;} //9/8 show reset button now!
    UISlider *slider = (UISlider*)sender;
    int tagMinusBase = (int)slider.tag-SLIDER_BASE_TAG; // 7/11 new name
    //Get slider, associated param, and pass back to parent!
    float value = slider.value;
    //NSLog(@" sval %f",value);
    NSString *name = dice ? @"" : ssliderNames[tagMinusBase];
    NSLog(@" send shape value: UNCOMMENT! %d %d",tagMinusBase,value);
    [self.delegate didSetShapeValue:tagMinusBase:value:name:TRUE];

} //end updateSliderAndDelegateValue


//======(shapePanel)==========================================
- (IBAction)helpSelect:(id)sender
{
    [self putUpOBHelpInstructions];
}

//======(shapePanel)==========================================
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

//======(shapePanel)==========================================
- (void)LPGestureUndo:(UILongPressGestureRecognizer *)recognizer
{
    diceUndo = TRUE;   //7/9 handitoff to dice...
}

//======(shapePanel)==========================================
// 8/21 sets sliders directly and they report to parent,
//   pickers values have to be sent to parent here
- (IBAction)diceSelect:(id)sender
{
//    double smins[15]= {0.0,0.0,0.0,0.0,0.0, //6/27/21 add more min/max delay fields
//                       0.0,0.0,0.0,0.0,0.0,
//                       0.0,0.0,0.0,0.0,0.0};
//    double smaxes[15]= {100.0,100.0,100.0,100.0,100.0,
//                        100.0,100.0,100.0,100.0,100.0,
//                        100.0,100.0,100.0,100.0,100.0};
//    int numSliders = 3; // Assume only top panel accessible...
//    rollingDiceNow = TRUE;
//    // 8/29 No pro mode? no bottom panel
//    // 9/2   ...only 7 sliders with empty space at index 3
//     //if (cappDelegate.proMode || cappDelegate.proModeDemo) numSliders = 15;   //6/27/21
//
//    if (diceUndo)
//    {
//        NSLog(@" undo?");
//        diceUndo = FALSE;
//        return;
//    }
//
//    BOOL needVibrato    = (drand(0,1) < 0.20);
//    BOOL needPortamento = (drand(0,1) < 0.20);
//    BOOL needAmplVibe   = (drand(0,1) < 0.20);
//    BOOL needDelay      = (drand(0,1) < 0.20);   //6/27/21
//
//    for (int i=0;i<numSliders;i++) //randomize sliders based on pro mode
//    {
//        if (sliders[i] != nil) //skip empty spaces
//        {
//            float f = (float)drand(smins[i],smaxes[i]); // get slider randomized val
//            if (i == 5  && !needPortamento) f = 0.0; //portamento on/off
//            if (i == 6  && !needVibrato)    f = 0.0; //vibratoo on/off
//            if (i == 9  && !needAmplVibe)   f = 0.0; //Ampl vibe on/off
//            if (i == 12 && !needDelay)      f = 0.0; //Delay on/off //6/27/21
//            [sliders[i] setValue:f]; //most all others get set!
//            [self updateSliderAndDelegateValue : sliders[i]: TRUE]; //9/23
//        }
//    } //end for int
//    //Randomize our 3 pickers...
//    int row = (int)drand(0,12);
//    [pickers[0] selectRow:row inComponent:0 animated:NO];
//    [self.delegate didSetControlValue:3 :(float)row:@"":FALSE]; //messy hard coded tag!
//    //if (cappDelegate.proMode || cappDelegate.proModeDemo) // 8/29 Pro Mode? bottom panel ok
//    {
//        row = (int)drand(0,4);
//        [pickers[1] selectRow:row inComponent:0 animated:NO];
//        [self.delegate didSetControlValue:8 :(float)row:@"":FALSE]; //messy hard coded tag!
//        row = (int)drand(0,4); //4/8 randomize ampl wave
//        [pickers[2] selectRow:row inComponent:0 animated:NO];
//        [self.delegate didSetControlValue:11 :(float)row:@"":FALSE];
//    }
//    [self.delegate didSelectControlDice]; //4/29
//    diceRolls++; //9/9 for analytics
//    diceUndo = FALSE;
//    rollingDiceNow = FALSE;

} //end diceSelect

 
//======(shapePanel)==========================================
- (IBAction)resetSelect:(id)sender
{
    [self resetControls];
    //[self.delegate updateControlModeInfo : @"Reset F/X"]; //5/19
    [self.delegate didSelectShapeReset]; //7/11 for undo
}

//======(shapePanel)==========================================
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

//======(shapePanel)==========================================
//8/3
-(void)updateSessionAnalytics
{
    //NSLog(@" duh collected analytics for flurry");
    for (int i=0;i<MAX_CONTROL_SLIDERS;i++)
    {
        if (sChanges[i] > 0) //report changes to analytics
        {
            //NSLog(@" slider[%d] %d",i,sChanges[i]);
            //NSString *sname = ssliderKeys[i];
            //8/11 FIX[fanal updateSliderCount:sname:sChanges[i]];
        }
    }
    for (int i=0;i<MAX_CONTROL_PICKERS;i++)
    {
        if (pChanges[i] > 0) //report changes to analytics
        {
            //NSLog(@" picker[%d] %d",i,pChanges[i]);
            //NSString *pname = spickerKeys[i];
            //8/11 FIX[fanal updatePickerCount:pname:pChanges[i]];
        }
    }
    //8/11 FIX[fanal updateDiceCount : @"LDI" : diceRolls]; //9/9
    //8/11 FIX [fanal updateMiscCount : @"LRE" : resets]; //9/9
    [self clearAnalytics]; //9/9 clear for next session

} //end updateSessionAnalytics

//======(shapePanel)==========================================
- (NSString *)getPickerTitleForTagAndRow : (int)tag : (int)row
{
    //NSLog(@" get picker tag %d",tag);
    NSString *title = @"";
    if (tag == PICKER_BASE_TAG + 0)
    {
        title = _texNames[row];
    }
    if (tag == PICKER_BASE_TAG + 2) //rotation type
    {
        title = rotTypeParams[row];
    }

    return title;
}

#pragma UIPickerViewDelegate
 
//-------<UIPickerViewDelegate>-----------------------------
// 6/18 redo
- (void)pickerView:(UIPickerView *)pickerView didSelectRow: (NSInteger)row inComponent:(NSInteger)component {
    if (!_wasEdited) {_wasEdited = TRUE; resetButton.hidden = FALSE;} //9/8 show reset button now!
    //int which = 0;
    int liltag = (int)pickerView.tag - PICKER_BASE_TAG;
    if (liltag == 0)
        [self.delegate didSetShapeValue:liltag :(float)row:_texNames[row]: !rollingDiceNow && !resettingNow];   //7/11
    else
        [self.delegate didSetShapeValue:liltag :(float)row:spickerNames[liltag]: !rollingDiceNow && !resettingNow];   //7/11
//
//    //8/3 update picker activity count
//    int pMinusBase = (int)(pickerView.tag-PICKER_BASE_TAG);
//    if (pMinusBase>=0 && pMinusBase<MAX_CONTROL_PICKERS) pChanges[pMinusBase]++;
}


//-------<UIPickerViewDelegate>-----------------------------
// tell the picker how many rows are available for a given component
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    int tag = (int)pickerView.tag;
    NSLog(@" picker#rows for tag %d",tag);
    
    if ( tag == PICKER_BASE_TAG)  return _texNames.count;
    else if ( tag == PICKER_BASE_TAG+2)  return numRotTypeParams;
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
    [self.delegate didSetShapeValue:liltag :0.0:s:FALSE];
    return YES;
}



@end
