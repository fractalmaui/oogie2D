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
// 10/21 add delete button
// 10/27 add resetPatchPicker
// 10/28 fix layout bugs reset button / editlabel
// 10/29 close KB if panel closes, see lastSelectedTextField
// 10/30 add shouldChangeCharactersInRange delegate callback
// 11/1   shrink editLabel, repeat on other panels?
// 11/10 add quant field
// 11/29 for channel sliders, enable ONLY if picker is set to top value
//         weird cosmetic bug, slider doesnt gray out when it should!
//        pull demoNotification, add bottom bevel panel
// 12/15 pull which from didSetControlValue
// 12/21 remoe l/r buttons
#import "controlPanel.h"

@implementation controlPanel

//======(controlPanel)==========================================
- (id)init
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        goog = [genOogie sharedInstance];
        _spNames = @[];
        _paNames = @[];

        //8/3 flurry analytics
        //8/11 FIX fanal = [flurryAnalytics sharedInstance];
        allParams      = nil; // 10/1 new data structs
        sliderNames    = nil;
        pickerNames    = nil;
        textFieldNames = nil;
        allSliders     = [[NSMutableArray alloc] init];
        allPickers     = [[NSMutableArray alloc] init];
        allTextFields  = [[NSMutableArray alloc] init];
        
        lastSelectedTextField = nil; //10/29 indicate no select
        _wasEdited = FALSE; //9/8
        sfx   = [soundFX sharedInstance];  //8/27
        diceUndo = FALSE; //7/9
        rollingDiceNow = resettingNow = FALSE;
    }
    return self;
}

//======(controlPanel)==========================================
//10/1 new storage
-(void) setupCannedData
{
    if (allParams != nil) return; //only go thru once!
    //NSLog(@" setup canned voice Param data...");
    allParams      = @[@"patch",@"soundpack",@"latitude", @"longitude",
                       @"threshold",@"bottommidi",@"topmidi",@"keysig",@"poly",@"quant",
                       @"nchan",@"nfixed",@"vchan",@"vfixed",@"pchan",@"pfixed", //10/3
                       @"level",@"portamento",
                       @"viblevel" ,@"vibspeed",@"vibwave",
                       @"vibelevel" ,@"vibespeed",@"vibewave",
                       @"delaytime" ,@"delaysustain",@"delaymix",
                       @"name",@"comment"];
    sliderNames    = @[@"Latitude", @"Longitude",
                       @"Threshold",@"Bottom Note",@"Top Note",
                       @"NChannel", @"VChannel", @"PChannel",
                       @"Overdrive",@"Portamento",
                       @"FVib Level" ,@"FVib Speed" ,
                       @"AVib Level" ,@"AVib Speed",
                       @"Delay Time" ,@"Delay Sustain",@"Delay Mix"];
                       ;
    // note some picker names arent used...
    pickerNames    = @[@"Patch",@"SoundPack",@"KeySig",@"Mono/Poly",@"Quantize",@"mt",@"mt",@"mt",@"FVib Wave",@"AVib Wave"];
    textFieldNames = @[@"Name",@"Comments"];
    
    musicalKeys = @[@"C",@"C#",@"D",@"D#",@"E",@"F",@"F#",@"G",@"G#",@"A",@"A#",@"B"];
    keySigs = @[@"Major",@"Minor",@"Lydian",@"Phrygian",
                @"Mixolydian",@"Locrian",@"Egyptian",@"Hungarian",
                @"Algerian",@"Japanese",@"Chinese",@"Chromatic"];
    quants = @[@"None",@"1/1",@"1/2",@"1/4",
                @"1/8",@"1/16",@"1/32",@"1/64"];
    monoPoly = @[@"Mono",@"Poly"];
    vibratoWaves = @[ @"Sine",@"Saw",@"Square",@"Ramp"];
    //WTF? these pickers  fUCk up the text align, crop off first 4 chars
    colorChannels  = @[@"Red",@"Green",@"Blue",   //10 / 3Color channel choices...
                       @"Hue",@"Lum",@"Sat",
                       @"Cyan",@"Mag",@"Yel",
                       @"Slider"   ];

} //end setupCannedData


//======(controlPanel)==========================================
-(void) setupView:(CGRect)frame
{
    [self setupCannedData];
    //Add rounded corners to this view
    self.layer.cornerRadius = OOG_MENU_CURVERAD;
    self.clipsToBounds      = TRUE;

    //9/20 Wow. we dont have a frame here!!! get width at least!
    CGSize screenSize   = [UIScreen mainScreen].bounds.size;
    viewWid = screenSize.width;
    viewHit    = frame.size.height;
    buttonWid = viewWid * 0.12; //10/4 REDO button height,scale w/width
    buttonHit = OOG_HEADER_HIT; //buttonWid;
    
    //11/29 NO PRO BUTTON EVER
    proButton.hidden = TRUE; // 8/11 FIX gotPro;

    self.frame = frame;
    self.backgroundColor = [UIColor redColor]; // 6/19/21 colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.1];
    int xs,ys,xi,yi;
    
    xi = 0;
    yi = 0;
    xs = viewWid;
    ys = viewHit;
    
    int iSlider = 0; //10/3 keep slider / picker count
    int iPicker = 0;
    int iParam  = 0;
    scrollView = [[UIScrollView alloc] init];
    scrollView.frame = CGRectMake(xi,yi,xs,ys);
    scrollView.backgroundColor = [UIColor clearColor];
    scrollView.showsVerticalScrollIndicator = TRUE;
    [self addSubview:scrollView];

    int panelSkip = 5; //Space between panels
    int i=0; //6/8
    
    xi = 0;
    yi = 0;
    xs = viewWid;
    ys = OOG_MENU_CURVERAD;
    UILabel *editLabel = [[UILabel alloc] initWithFrame:
                   CGRectMake(xi,yi,xs,ys)];
    [editLabel setBackgroundColor : [UIColor redColor]];
    [editLabel setTextColor : [UIColor whiteColor]];
    [editLabel setFont:[UIFont fontWithName:@"Helvetica Neue" size: 22.0]]; //11/16 looks stupid small
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
    titleLabel.text = @"...";
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [header addSubview : titleLabel];
        
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

    //10/21 add delete button top RL
    xs = OOG_HEADER_HIT * 0.8;
    ys = xs;
    xi = viewWid - ys - 3*OOG_XMARGIN; //LH side, note inset
    deleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [deleteButton setImage:[UIImage imageNamed:@"redx.png"] forState:UIControlStateNormal];
    [deleteButton setFrame:CGRectMake(xi,yi,xs,ys)];
    [deleteButton addTarget:self action:@selector(deleteSelect:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:deleteButton];


    //Patch / Soundpack / latlon Panel...
    int panelY = 60; //10/3
    int pahit = 3*OOG_SLIDER_HIT + 2*OOG_PICKER_HIT + 2*OOG_YMARGIN;
    yi = panelY;
    ys = pahit;
    xi = OOG_XMARGIN;
    xs = viewWid-2*OOG_XMARGIN;
    UIView *paPanel = [[UIView alloc] init];
    [paPanel setFrame : CGRectMake(xi,yi,xs,ys)];
    paPanel.backgroundColor = [UIColor colorWithRed:0.41 green:0.41 blue:0.41 alpha:1];
    [scrollView addSubview : paPanel];
     yi = 10;
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
    [self addPickerRow:paPanel : iPicker : PICKER_BASE_TAG + iParam : pickerNames[iPicker] : yi : OOG_PICKER_HIT];
    iPicker++;
    iParam++;
    yi += ys;
    [self addPickerRow:paPanel : iPicker : PICKER_BASE_TAG + iParam : pickerNames[iPicker] : yi : OOG_PICKER_HIT];
    iPicker++;
    iParam++;
    yi += ys;
    ys = OOG_SLIDER_HIT;
    // 11/25 move lat/lon up to top of menu
    [self addSliderRow:paPanel : iSlider : SLIDER_BASE_TAG + iParam : @"Latitude (Y)" : yi :
        OOG_SLIDER_HIT: 0.0 : 1.0];
    iSlider++;
    iParam++;
    yi+=ys;
    [self addSliderRow:paPanel : iSlider : SLIDER_BASE_TAG + iParam : @"Longitude (X)" : yi :
        OOG_SLIDER_HIT:0.0 : 1.0];
    iSlider++;
    iParam++;

    //Add color panel-------------------------------------
    panelY += pahit;
    pahit = 3*OOG_SLIDER_HIT + 2*OOG_TEXT_HIT + 3*OOG_PICKER_HIT + 3*OOG_YSPACER + 2*OOG_YMARGIN;
    yi = panelY;
    ys = pahit;
    xi = OOG_XMARGIN;
    xs = viewWid-2*OOG_XMARGIN;
    UIView *cPanel = [[UIView alloc] init];
    [cPanel setFrame : CGRectMake(xi,yi,xs,ys)];
    cPanel.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1];
    [scrollView addSubview:cPanel];
    xi = OOG_XMARGIN;
    yi = OOG_XMARGIN;
    ys = OOG_SLIDER_HIT;
    xs = viewWid*0.9;
    UILabel *l5 = [[UILabel alloc] initWithFrame: CGRectMake(xi,yi,xs,ys)];
    [l5 setTextColor : [UIColor whiteColor]];
    l5.text = @"Basic Params";
    [cPanel addSubview : l5];

    xi = OOG_XMARGIN;
    yi+=ys;  //skip down below prev item
    // add threshold, lo/hi midi sliders
    for (i=0;i<3;i++)
    {
        [self addSliderRow:cPanel : iSlider : SLIDER_BASE_TAG + iParam : sliderNames[iSlider] : yi : OOG_SLIDER_HIT:0.0:1.0];
        yi += (OOG_SLIDER_HIT+OOG_YSPACER);
        iSlider++;
        iParam++;
    }
    // add keysig picker
    [self addPickerRow:cPanel : iPicker : PICKER_BASE_TAG + iParam : pickerNames[iPicker] : yi : OOG_PICKER_HIT];
    iPicker++;
    iParam++;
    yi += (OOG_PICKER_HIT+OOG_YSPACER);
    // add mono/poly picker
    [self addPickerRow:cPanel : iPicker : PICKER_BASE_TAG + iParam : pickerNames[iPicker] : yi : OOG_PICKER_HIT];
    iPicker++;
    iParam++;
    yi += (OOG_PICKER_HIT+OOG_YSPACER);
    // add quant picker
    [self addPickerRow:cPanel : iPicker : PICKER_BASE_TAG + iParam : pickerNames[iPicker] : yi : OOG_PICKER_HIT];
    iPicker++;
    iParam++;
    yi += (OOG_PICKER_HIT+OOG_YSPACER);

    // it was in the patch editor but that was the wrong place
    //Color Channels panel next... 3 groups of picker/slider pairs and one slider below that
    panelY += pahit;
    pahit = OOG_SLIDER_HIT + 3*OOG_PICKER_HIT + 3*OOG_YSPACER + 2*OOG_YMARGIN;
    yi = panelY;
    ys = pahit;
    xi = OOG_XMARGIN; //6/19/21
    xs = viewWid - 2*OOG_XMARGIN;
    // 7/9 calculate height based on controls
    cPanel = [[UIView alloc] init];
    [cPanel setFrame : CGRectMake(xi,yi,xs,ys)];
    cPanel.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.5 alpha:1];
    [scrollView addSubview:cPanel];
    yi = OOG_XMARGIN;
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
        [self addPickerSliderRow : cPanel : iParam : iParam+1 : sliderNames[iSlider] : yi :ys]; //i/j = picker / slider # 10/16
        iParam+=2; //skip down 2
        yi+=ys-18; //5/24 test squnch
        iSlider++;
        iPicker++;
    }
    
    //Add live controls panel-------------------------------------
    panelY += pahit;
    pahit = 11*OOG_SLIDER_HIT + 2*OOG_PICKER_HIT + 10*OOG_YSPACER + 2*OOG_YMARGIN;
    ys = pahit;
    yi = panelY;
    xi = OOG_XMARGIN;
    xs = viewWid - 2*OOG_XMARGIN;
    // 7/9 calculate height based on controls
    //  wouldnt it be nice to do this AFTER controls are created??
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
        [self addSliderRow:pPanel : iSlider : SLIDER_BASE_TAG + iParam : dog : yi : OOG_SLIDER_HIT:0.0:1.0];
        yi += (OOG_SLIDER_HIT+OOG_YSPACER);
        iSlider++;
        iParam++;
    }
    // add picker for viblevel
    [self addPickerRow:pPanel : iPicker : PICKER_BASE_TAG + iParam : pickerNames[iPicker] : yi : OOG_PICKER_HIT];
    iPicker++;
    iParam++;
    yi += 2* (OOG_SLIDER_HIT+OOG_YSPACER);
    //4/7/21 add vibe level/spped
    for (i=0;i<2;i++) //add 2 fx sliders,  FVIB wave, AVIB level/speed
    {
        NSString *dog = [NSString stringWithFormat:@"rowi %d",i];
        [self addSliderRow:pPanel : iSlider : SLIDER_BASE_TAG + iParam : dog : yi : OOG_SLIDER_HIT:0.0:1.0];
        yi += (OOG_SLIDER_HIT+OOG_YSPACER);
        iSlider++;
        iParam++;
    }
    // add picker for viblevel
    [self addPickerRow:pPanel : iPicker : PICKER_BASE_TAG + iParam : pickerNames[iPicker] : yi : OOG_PICKER_HIT];
    iPicker++;
    iParam++;

    yi += (OOG_PICKER_HIT+OOG_YSPACER);
    // 2/19/21 add 3 delay sliders
    for (i=0;i<3;i++)
    {
        NSString *dog = [NSString stringWithFormat:@"rowi %d",i];
        [self addSliderRow:pPanel : iSlider : SLIDER_BASE_TAG + iParam : dog : yi : OOG_SLIDER_HIT:0.0:1.0];
        yi += (OOG_SLIDER_HIT+OOG_YSPACER);
        iSlider++;
        iParam++;
    }
    
    xi = OOG_XMARGIN;
    //assume right below pPanel...
    yi = pPanel.frame.origin.y + pPanel.frame.size.height + panelSkip;
    xs = viewWid - 2*OOG_XMARGIN;
    ys = 2*OOG_TEXT_HIT + 3*OOG_YMARGIN; // + 2*OOG_PICKER_HIT + 10*OOG_YSPACER ;
    //11/29 add rounded panel beneath our last panel , cosmetic
    UIView *bevelPanel = [[UIView alloc] init]; //name / comments panel...
    [bevelPanel setFrame : CGRectMake(xi,yi+20,xs,ys)]; //asdf
    bevelPanel.backgroundColor = [UIColor colorWithRed:0.0 green:0.4 blue:0.4 alpha:1];
    bevelPanel.layer.cornerRadius = 20;
    bevelPanel.clipsToBounds      = TRUE;
    [scrollView addSubview:bevelPanel];
    //this is the panel controls are added to
    UIView *ncPanel = [[UIView alloc] init]; //name / comments panel...
    [ncPanel setFrame : CGRectMake(xi,yi,xs,ys)];
    ncPanel.backgroundColor = [UIColor colorWithRed:0.0 green:0.4 blue:0.4 alpha:1];
    [scrollView addSubview:ncPanel];

    //11/25 pulled lat/lon, now just name / comment fields
    yi = OOG_YMARGIN;
    [self addTextRow:ncPanel :0 :TEXT_BASE_TAG + iParam : textFieldNames[0] :yi :OOG_TEXT_HIT ];
    iParam++;
    yi += (OOG_TEXT_HIT+OOG_YSPACER);
    [self addTextRow:ncPanel :1 :TEXT_BASE_TAG + iParam : textFieldNames[1] :yi :OOG_TEXT_HIT ];
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
    int scrollHit = 1500; //11/13 add empty padding ab tobbom
    //if (cappDelegate.gotIPad) scrollHit+=120; //3/27 ipad needs a bit more room
    
    scrollView.contentSize = CGSizeMake(viewWid, scrollHit);
} //end setupView

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
        [allSliders addObject:slider];
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
        [allPickers addObject:picker];
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
          [allTextFields addObject:textField];
      }
} //end addTextRow


//======(controlPanel)==========================================
//  Updates our controls... LONG AND TEDIOUS,
//    takes incoming dictionary of name / value pairs, and
//    tries to find the proper control for each
//  NOTE: tag 0 cannot be used with buttons, makes bad stuff happen
-(void) configureView
{
    [allPickers[0] reloadAllComponents]; //patch/soundpack
    [allPickers[1] reloadAllComponents];
    NSString *s = @"no name"; //get voice name for title
    NSArray *a  = [_paramDict objectForKey:@"name"];
    if (a.count > 0) s = a.lastObject;
    titleLabel.text = s;
    [self configureViewWithReset : FALSE];
}

//======(controlPanel)==========================================
// 10/27 reset patch picker to desired index (parent should know?)
-(void) resetPatchPicker : (int)index
{
    int nrows = (int)[allPickers[0] numberOfRowsInComponent:0]; //see what we got...
    if (index >= nrows) return;
    [allPickers[0] selectRow:index inComponent:0 animated:FALSE];
}

//======(controlPanel)==========================================
// This is huge. it should be made to work with any control panel!
-(void) configureViewWithReset : (BOOL)reset
{
    NSArray *noresetparams = @[];
    //10/29 reset? dont change patch!
    if (reset) noresetparams = @[@"patch",@"soundpack",@"name"];
    else       noresetparams = @[@"soundpack",@"name"];
    NSMutableDictionary *pickerchoices = [[NSMutableDictionary alloc] init];
    [pickerchoices setObject:_paNames forKey:@0];  //patches are on picker 0
    [pickerchoices setObject:_spNames forKey:@1];  //soundpacks are on picker 1
    NSDictionary *resetDict = [goog configureViewFromVC:reset : _paramDict : allParams :
                     allPickers : allSliders : allTextFields :
               noresetparams : pickerchoices];
    if (reset) //reset? need to inform delegate of param changes...
    {
        [self sendUpdatedParamsToParent:resetDict];
    }
    //11/29 need to disable channel sliders if matching pickers arent at top setting
    for (int i=0;i<3;i++) //for each channel picker... 10,12,14
    {
        int pickerTag = 10 + 2*i;
        NSNumber*nn = [goog getNumberForParam : _paramDict : allParams[pickerTag]]; //get value for picker
        int matchingSlider = 5 + i;
        //NSLog(@" chan %d picker %d",i,nn.intValue);
        UISlider *s = (UISlider*)allSliders[matchingSlider];
        [s setEnabled : (nn.intValue == (colorChannels.count-1))];  //last item? enable slider
    }

    resetButton.hidden = !_wasEdited;
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
        [self.delegate didSetControlValue:nv.floatValue:key:ns:FALSE]; //12/15
    }
} //end sendUpdatedParamsToParent

//======(controlPanel)==========================================
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
    [self.delegate didSetControlValue:value:allParams[tagMinusBase]:name:TRUE]; //12/15
} //end updateSliderAndDelegateValue


//======(controlPanel)==========================================
- (IBAction)dismissSelect:(id)sender
{
    [lastSelectedTextField resignFirstResponder]; //10/29 Close keyboard if up
    [self.delegate didSelectControlDismiss];
}


//======(controlPanel)==========================================
// 9/18  make this generic too, and return a list of updates for delegate.
// THEN add a method to go thru the updates dict and pass to parent,
//    and reuse this method here and in configureView!
-(void) randomizeParams
{
    //NSLog(@" RANDOMIZE");
    NSArray *norandomizeparams = @[@"patch",@"soundpack",@"name",@"comment",@"delaysustain",@"threshold"];

    NSMutableDictionary *resetDict = [goog randomizeFromVC : allParams : allPickers : allSliders : norandomizeparams];
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
// 10/21 delete this voice
- (IBAction)deleteSelect:(id)sender
{
    [self.delegate didSelectControlDelete];
} //end deleteSelect

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
    [self configureViewWithReset: TRUE];
    _wasEdited         = FALSE;
    resetButton.hidden = TRUE;
    resettingNow       = FALSE;
} //end resetControls


//======(controlPanel)==========================================
- (NSString *)getPickerTitleForTagAndRow : (int)tag : (int)row
{
    NSString *title = @"";
    //tags pickers, 0 / 1  / 7,8,9 / 10,12,14 / 20 / 23
    if (tag == PICKER_BASE_TAG) //patch
    {
        if (_paNames != nil) title = _paNames[row];
    }
    else if (tag == PICKER_BASE_TAG+1) //soundpack
    {
        if (_spNames != nil) title = _spNames[row];
    }
    if (tag == PICKER_BASE_TAG+7)
    {
        title = keySigs[row];
    }
    if (tag == PICKER_BASE_TAG+8)
    {
        title = monoPoly[row];
    }
    if (tag == PICKER_BASE_TAG+9) //11/10 add quant cboice
    {
        title = quants[row];
    }
    else if ( tag == PICKER_BASE_TAG+10 || tag == PICKER_BASE_TAG+12 || tag == PICKER_BASE_TAG+14)
    {
        title = colorChannels[row];
    }
    else if (tag == PICKER_BASE_TAG+20 || tag == PICKER_BASE_TAG+23)
    {
        title = vibratoWaves[row];
    }
    else if (tag == PICKER_BASE_TAG+20 || tag == PICKER_BASE_TAG+23)
    {
        title = vibratoWaves[row];
    }
    //NSLog(@" picker %d row %d title %@",tag,row,title);
    return title;
}

#pragma UIPickerViewDelegate

//-------<UIPickerViewDelegate>-----------------------------
// 6/18 redo
- (void)pickerView:(UIPickerView *)pickerView didSelectRow: (NSInteger)row inComponent:(NSInteger)component {
    if (!_wasEdited) {_wasEdited = TRUE; resetButton.hidden = FALSE;} //9/8 show reset button now!
    int liltag = (int)pickerView.tag - PICKER_BASE_TAG; //just pass tags to parent now
    NSString *patchName = @"";
    //NSLog(@" chose t %d r %d",liltag,row);
    if (liltag == 0) //patch? pass back our name...
    {
        if (row > 0)
        {
            patchName = _paNames[row];
        }
        else patchName = @"random";
    }
    //11/29  for pickers 10,12,14 disable sliders 5,6,7 (index not tag!) if set to row 9
    // NOTE THIS will break if you add any pickers or sliders above this point in the UI!
    if (liltag == 10 || liltag == 12 || liltag == 14)
    {
        int whichSlider = 5 + (liltag-10)/2; //need slider 5,6,7 for picker 10,12,14
        UISlider *s = (UISlider*)allSliders[whichSlider];
        [s setEnabled : (row == (colorChannels.count-1))];  //last item? enable slider
        [s setNeedsDisplay];
    }
    [self.delegate didSetControlValue:(float)row : allParams[liltag] : patchName :
                                    !rollingDiceNow && !resettingNow];   //12/15
}

 
//-------<UIPickerViewDelegate>-----------------------------
// tell the picker how many rows are available for a given component
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    int tag = (int)pickerView.tag;
    //tags pickers, 0 / 1  / 7,8,9 / 10,12,14 / 20 / 23
    if ( tag == PICKER_BASE_TAG) //patch
        {
            if (_paNames != nil) return _paNames.count;
        }
    else if ( tag == PICKER_BASE_TAG+1) //soundpack
        {
            if (_spNames != nil) return _spNames.count;
        }
    else if ( tag == PICKER_BASE_TAG + 7)
        return keySigs.count; //keysig
    else if ( tag == PICKER_BASE_TAG + 8)
        return monoPoly.count; //10/3 mono/poly
    else if ( tag == PICKER_BASE_TAG + 9)
        return quants.count; //11/10 quantize
    // 10/3 color channels
    else if ( tag == PICKER_BASE_TAG+10 || tag == PICKER_BASE_TAG+12 || tag == PICKER_BASE_TAG+14)
        return colorChannels.count; //keysig
    else if ( tag == PICKER_BASE_TAG+20 || tag == PICKER_BASE_TAG+23 )  //vib ratos
        return vibratoWaves.count;
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

#pragma mark - UITextFieldDelegate

//==========<UITextFieldDelegate>====================================================
// 10/30 for displaying text entry on mainVC
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    NSLog(@" begin");
    [self.delegate didStartTextEntry:allParams[(textField.tag % 1000)]];  //pass field name
    lastSelectedTextField = textField;  //10/29
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
    [self.delegate didSetControlValue: 0.0 : allParams[liltag] : s: FALSE];  //12/15
    // 9/21 take care of name update at top of menu
    if ([allParams[liltag] isEqualToString:@"name"]) titleLabel.text = s;
    return YES;
}

//======(patchPanel)==========================================
// 9/16 redo adds a canned label/picker/slider set...
-(void) addPickerSliderRow : (UIView*) parent : (int)pindex : (int) sindex : (NSString*) label : (int) yoff : (int) ysize
{
    NSArray* A = [goog addPickerSliderRow:parent :
                  PICKER_BASE_TAG+pindex :
                  SLIDER_BASE_TAG+sindex :
                  label :yoff :viewWid :ysize];
    if (A.count > 1)
    {
        UIPickerView * picker = A[0];
        picker.delegate       = self;
        picker.dataSource     = self;
        [allPickers addObject: picker];  //10/3

        UISlider     *slider  = A[1];
        [slider addTarget:self action:@selector(sliderAction:) forControlEvents:UIControlEventValueChanged];
        [slider addTarget:self action:@selector(sliderStoppedDragging:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
        [allSliders addObject: slider]; //10/3
    }
} //end addPickerSliderRow



@end
