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
//  9/21 remove footer, add curved top title
//  10/1 redo with NSArrays instead of C-arrays
//  10/3 add indices to sliders/pickers
//  10/13 CLUGE for now, call sendUpdatedParamsToParent 2X in reset, otherwise
//          some pipes dont get placed correctly, it has to do with a race condition
//            between marker update and pipe update.!?!?!?!?
//  10/28 add image indicator over texture picker
//  10/29 close KB if panel closes, see lastSelectedTextField , move sPanel down
// 10/30 add shouldChangeCharactersInRange delegate callback
#import "shapePanel.h"

@implementation shapePanel

//======(shapePanel)==========================================
- (id)init
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        // 9/15 add UI utilities
        goog = [genOogie sharedInstance];

        allParams      = nil; // 10/1 new data structs
        sliderNames    = nil;
        pickerNames    = nil;
        textFieldNames = nil;
        allSliders     = [[NSMutableArray alloc] init];
        allPickers     = [[NSMutableArray alloc] init];
        allTextFields  = [[NSMutableArray alloc] init];
        defaultImage   = [UIImage imageNamed : @"spectrumOLD"]; //11/15 should get from textureCache, swift?
        lastSelectedTextField = nil; //10/29 indicate no select

        //8/3 flurry analytics
        //8/11 FIX fanal = [flurryAnalytics sharedInstance];
        _texNames = @[]; //empty array for now
        _wasEdited = FALSE; //9/8
        sfx   = [soundFX sharedInstance];  //8/27
        diceUndo = FALSE; //7/9
        rollingDiceNow = resettingNow = FALSE;
        
        topTexSlider = 0;
        ucoord = vcoord = 0.0;
        uscale = vscale = 1.0;

    }
    return self;
}

//======(pipePanel)==========================================
//10/1 new storage
-(void) setupCannedData
{
    if (allParams != nil) return; //only go thru once!
    //NSLog(@" setup canned shape Param data...");
    allParams      = @[@"texture",@"rotation",@"rotationtype",@"xpos",@"ypos",@"zpos",
                       @"texxoffset",@"texyoffset",@"texxscale",@"texyscale",@"name",@"comment"];
    sliderNames    = @[@"Rotation",@"Shape XPos",@"Shape YPos",@"Shape ZPos",
                       @"Tex UPos",@"Tex YPos",@"Tex UScale",@"Tex VScale"];
    pickerNames    = @[@"Texture",@"RotType"];
    textFieldNames = @[@"Name",@"Comments"];
    
    rotTypeParams = @[@"Manual", @"BPMX1", @"BPMX2", @"BPMX3", @"BPMX4", @"BPMX5", @"BPMX6", @"BPMX7", @"BPMX8"];

} //end setupCannedData

//======(shapePanel)==========================================
-(void) setupView:(CGRect)frame
{
    [self setupCannedData]; //10/1 new

    //Add rounded corners to this view
    self.layer.cornerRadius = OOG_MENU_CURVERAD;
    self.clipsToBounds      = TRUE;

    //9/20 Wow. we dont have a frame here!!! get width at least!
    CGSize screenSize   = [UIScreen mainScreen].bounds.size;
    viewWid = screenSize.width;
    viewHit    = frame.size.height;
    buttonWid = viewWid * 0.12; //10/4 REDO button height,scale w/width
    buttonHit = OOG_HEADER_HIT; //buttonWid;
    
    self.frame = frame;
    self.backgroundColor = [UIColor greenColor]; // 6/19/21 colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.1];
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
    

    //int panelSkip = 5; //Space between panels
    int i=0; //6/8
    
    xi = 0;
    yi = 0;
    xs = viewWid;
    ys = OOG_MENU_CURVERAD;
    UILabel *editLabel = [[UILabel alloc] initWithFrame:
                   CGRectMake(xi,yi,xs,ys)];
    [editLabel setBackgroundColor : [UIColor greenColor]];
    [editLabel setTextColor : [UIColor blackColor]];
    [editLabel setFont:[UIFont fontWithName:@"Helvetica Neue" size: 22.0]];   //11/19
    editLabel.text = @"Edit Shape";
    editLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview : editLabel];
    
    // 9/24 add dismiss button for oogieAR only
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
    [titleLabel setFont:[UIFont fontWithName:@"Helvetica Neue" size: 22.0]];   //11/19
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
   
    int iSlider = 0; //10/3 keep slider / picker count
    int iPicker = 0;
    int iParam  = 0;
    int iText   = 0;

    //Add shape controls panel-------------------------------------
    xi = OOG_XMARGIN;
    yi = 90; //10/29 move down a bit
    xs = viewWid-2*OOG_XMARGIN;
    ys = 2*OOG_PICKER_HIT +  8*OOG_SLIDER_HIT + 2*OOG_TEXT_HIT + 2*OOG_PICKER_HIT + 2*OOG_YMARGIN;
    UIView *sPanel = [[UIView alloc] init];
    [sPanel setFrame : CGRectMake(xi,yi,xs,ys)];
    sPanel.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1];
    [scrollView addSubview:sPanel];
    
    xi = OOG_XMARGIN;
    yi = xi; //top of form
    // texture picker
    [self addPickerRow:sPanel : iPicker : PICKER_BASE_TAG + iParam : pickerNames[iPicker] : yi : OOG_PICKER_HIT];

    //10/28 add image indicator on top of texture picker
    xs = ys = OOG_PICKER_HIT;
    xi = viewWid - 4*OOG_XMARGIN - xs;
    thumbView = [[UIImageView alloc] initWithImage:defaultImage];
    [thumbView setFrame:CGRectMake(xi,yi,xs,ys)];
    [sPanel addSubview:thumbView];

    yi +=  (OOG_PICKER_HIT+OOG_YSPACER);
    iPicker++;
    iParam++;

    // rotation slider
    [self addSliderRow:sPanel : iSlider : SLIDER_BASE_TAG + iParam : sliderNames[iSlider] : yi : OOG_SLIDER_HIT:0.0:1.0];
    yi += (OOG_SLIDER_HIT+OOG_YSPACER);
    iSlider++;
    iParam++;

    // rotation type picker
    [self addPickerRow:sPanel : iPicker : PICKER_BASE_TAG + iParam : pickerNames[iPicker] : yi : OOG_PICKER_HIT];
    yi +=  (OOG_PICKER_HIT+OOG_YSPACER);
    iPicker++;
    iParam++;

    // XYZ position
    for (i=0;i<3;i++)
    {
        [self addSliderRow:sPanel : iSlider : SLIDER_BASE_TAG + iParam : sliderNames[iSlider] : yi : OOG_SLIDER_HIT:0.0:1.0];
        yi += (OOG_SLIDER_HIT+OOG_YSPACER);
        iSlider++;
        iParam++;
    }
    
    //Original texture view: never changes
    int texWid = 80;
    otView = [[UIImageView alloc] initWithImage:nil];     //[UIImage imageNamed:logoName]];
    xs = ys = texWid;
    xi = 120; //(viewWid - xs) * 0.5;
    [otView setFrame:CGRectMake(xi,yi, xs, ys)];
    [sPanel addSubview : otView];

//wtf, why doesnt arrow show up?
    xi += xs;
    UIImageView *arrowView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"icon256"]];
    [arrowView setFrame:CGRectMake(xi,yi, xs, ys)];
    [sPanel addSubview : arrowView];

    // Scaled / Panned texture view: shows texture map xy offsets and scaling
    xi += xs;
    textureView = [[UIImageView alloc] initWithImage:nil];
    [textureView setFrame:CGRectMake(xi,yi, xs, ys)];
    [sPanel addSubview : textureView];
    yi+=texWid;
    
    topTexSlider = iParam;
    // U/V offset , U/V scale
    for (i=0;i<4;i++)
    {
        [self addSliderRow:sPanel : iSlider : SLIDER_BASE_TAG + iParam : sliderNames[iSlider] : yi : OOG_SLIDER_HIT:0.0:1.0];
        yi += (OOG_SLIDER_HIT+OOG_YSPACER);
        iSlider++;
        iParam++;
    }

    //9/11 text entry fields... 9/20 fix yoffset bug
    [self addTextRow:sPanel :iText :TEXT_BASE_TAG + iParam : textFieldNames[iText] : yi : OOG_TEXT_HIT ];
    yi += (OOG_TEXT_HIT+OOG_YSPACER);
    iText++;
    iParam++;
    [self addTextRow:sPanel :iText :TEXT_BASE_TAG + iParam : textFieldNames[iText] : yi : OOG_TEXT_HIT ];
    iText++;
    iParam++;

    //Scrolling area...
    CGRect rrr = sPanel.frame;
    int scrollHit = rrr.size.height + 180;  //11/13 add room at bottom
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
//    for (int i=0;i<MAX_SHAPE_SLIDERS;i++) sChanges[i] = 0;
//    for (int i=0;i<MAX_SHAPE_PICKERS;i++) pChanges[i] = 0;
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
// 9/15 redo w/ genOogie method!
-(void) addSliderRow : (UIView*) parent : (int) index : (int) tag : (NSString*) label :
(int) yoff : (int) ysize : (float) smin : (float) smax
{
    //9/12 note we user smin/smax here
    NSArray* A = [goog addSliderRow : parent : tag : label :
                               yoff : viewWid: ysize :smin: smax];
    if (A.count > 0)
    {
        UISlider* slider = A[0];
        // hook it up to callbacks
        [slider addTarget:self action:@selector(sliderAction:) forControlEvents:UIControlEventValueChanged];
        [slider addTarget:self action:@selector(sliderStoppedDragging:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
        [allSliders addObject:slider];
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

//======(shapePanel)==========================================
// adds a canned label/picker set...
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
        [allPickers addObject:picker];
    }
} //end addPickerRow


//======(shapePanel)==========================================
-(void) addTextRow : (UIView*) parent : (int) index : (int) tag : (NSString*) label :
(int) yoff : (int) ysize
{
    //9/15 new UI element...
    NSArray* A = [goog addTextRow : parent : tag : textFieldNames[index] : yoff : viewWid : ysize];
    if (A.count > 0)
    {
        UITextField * textField = A[0]; //9/20
        textField.delegate     = self;
        [allTextFields addObject:textField];
    }
} //end addSliderRow

//======(shapePanel)==========================================
-(void) configureView
{
    [allPickers[0] reloadAllComponents]; //load textures
    NSString *s = @"no name"; //get voice name for title
    NSArray *a  = [_paramDict objectForKey:@"name"];
    if (a.count > 0) s = a.lastObject;
    titleLabel.text = s;
    NSArray *aa  = [_paramDict objectForKey:@"texture"];
    if (aa != nil) //11/9 update thumb to match setting
    {
        NSString *s = aa.lastObject;   //should be our setting?
        NSLog(@"texture %@",s);
        [self updateThumbImageByKey : s : 1]; //11/9 do not use row 0 here!
    }
    [self updateTextureDisplay];
    [self configureViewWithReset : FALSE];
}

//======(controlPanel)==========================================
// This is huge. it should be made to work with any control panel!
-(void) configureViewWithReset : (BOOL)reset
{
    //NOTE this may have to handle randomizer calls?? no texture change then!
    NSArray *noresetparams;
    if (reset)  noresetparams = @[@"texture",@"name",@"comment"]; // 11/9 dont change texture on reset!
    else        noresetparams = @[@"name",@"comment"];
    NSMutableDictionary *pickerchoices = [[NSMutableDictionary alloc] init];
    [pickerchoices setObject:_texNames forKey:@0];  //textures are on picker 8
    [pickerchoices setObject:rotTypeParams forKey:@2];  //rotation types are on picker 2
    NSDictionary *resetDict = [goog configureViewFromVC:reset : _paramDict : allParams :
                     allPickers : allSliders : allTextFields :
               noresetparams : pickerchoices];
    if (reset) //reset? need to inform delegate of param changes...
    {
        [self sendUpdatedParamsToParent:resetDict];
        //10/13 WTF???  TEST 2x to fix pipe weirdness
        NSLog(@" NOTE: sending second shape param update to parent: KLUGE!");
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
        [self.delegate didSetShapeValue : nt.intValue : nv.floatValue:key:ns:FALSE];
    }
} //end sendUpdatedParamsToParent

//======(controlPanel)==========================================
// 9/18  make this generic too, and return a list of updates for delegate.
// THEN add a method to go thru the updates dict and pass to parent,
//    and reuse this method here and in configureView!
-(void) randomizeParams
{
    NSLog(@" RANDOMIZE SHAPE");
    // we have more params to NOT randomize than ones we want TO randomize...
    NSArray *norandomizeparams = @[@"texture",@"name",@"comment",@"xpos",@"ypos",@"zpos"];
    NSMutableDictionary *resetDict = [goog randomizeFromVC : allParams : allPickers : allSliders : norandomizeparams];
    [self sendUpdatedParamsToParent:resetDict];
    [self.delegate didSelectShapeDice]; //4/29
    diceRolls++; //9/9 for analytics
    diceUndo = FALSE;
    rollingDiceNow = FALSE;

} //end randomizeParams


//======(shapePanel)==========================================
// 8/3 update session analytics here..
-(void)sliderStoppedDragging:(id)sender
{
    [self updateSliderAndDelegateValue : sender : FALSE];
}

//======(shapePanel)==========================================
-(void)sliderAction:(id)sender
{
    UISlider *s = (UISlider*)sender;
    int tag = s.tag % 1000;
    if ( tag >= topTexSlider && tag < topTexSlider+4) //texture coord?
    {
        int liltag = (tag % 1000) - topTexSlider;
        float v = s.value;
        if (liltag > 1) //scale: fit to 0.1 to 10
        {
            v = 0.1 + 9.9 * v;
        }
        switch(liltag)
        {
            case 0: ucoord = v; break;
            case 1: vcoord = v; break;
            case 2: uscale = v; break;
            case 3: vscale = v; break;
        }
        [self updateTextureDisplay];
    }
    [self updateSliderAndDelegateValue : sender : FALSE]; //9/23
}

//======(shapePanel)==========================================
-(void) updateTextureDisplay
{
    otView.image = _texture;
    UIImage *ii = [self makeTexturedImage : _texture : 320 : 320 : ucoord : vcoord : uscale : vscale];
    textureView.image = ii;
}

//======(shapePanel)==========================================
//called when slider is moved and on dice/resets!
-(void) updateSliderAndDelegateValue :(id)sender : (BOOL) dice
{
    if (!_wasEdited) {_wasEdited = TRUE; resetButton.hidden = FALSE;} //9/8 show reset button now!
    UISlider *slider = (UISlider*)sender;
    int tagMinusBase = ((int)slider.tag % 1000); // 7/11 new name
    float value = slider.value;
    NSString *name = dice ? @"" : allParams[tagMinusBase];
    [self.delegate didSetShapeValue:tagMinusBase:value:allParams[tagMinusBase]:name:TRUE];
} //end updateSliderAndDelegateValue


//======(controlPanel)==========================================
- (IBAction)dismissSelect:(id)sender
{
    [lastSelectedTextField resignFirstResponder]; //10/29 Close keyboard if up
    [self.delegate didSelectShapeDismiss];
}

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
    [self randomizeParams];
} //end diceSelect

//======(shapePanel)==========================================
// 10/21 delete this shape
- (IBAction)deleteSelect:(id)sender
{
    [self.delegate didSelectShapeDelete];
} //end deleteSelect

//======(shapePanel)==========================================
- (IBAction)resetSelect:(id)sender
{
    [self resetControls];
    ucoord = vcoord = 0.0; //11/9 reset texture size for display
    uscale = vscale = 1.0;
    [self updateTextureDisplay];
    [self.delegate didSelectShapeReset]; //7/11 for undo
}

//======(shapePanel)==========================================
// 4/3 reset called via button OR end of proMode demo
-(void) resetControls
{
    resettingNow = TRUE; //used w/ undo
    [self configureViewWithReset: TRUE];
    _wasEdited         = FALSE;
    resetButton.hidden = TRUE;
    resettingNow       = FALSE;
} //end resetControls


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
-(void) updateThumbImageByKey : (NSString*)key : (int) row
{
    UIImage *kk = _thumbDict[key];
    if ([key isEqualToString: @"default"]) //11/9
          kk = defaultImage;
    //10/28 add thumb....
    thumbView.image = kk;
}
 
//-------<UIPickerViewDelegate>-----------------------------
// 6/18 redo
- (void)pickerView:(UIPickerView *)pickerView didSelectRow: (NSInteger)row inComponent:(NSInteger)component {
    if (!_wasEdited) {_wasEdited = TRUE; resetButton.hidden = FALSE;} //9/8 show reset button now!
    //int which = 0;
    int liltag = (int)pickerView.tag % 1000;
    if (liltag == 0)
    {
        NSString *txt = [self getPickerTitleForTagAndRow:(int)pickerView.tag:(int)row];
        if (pickerView.tag % 1000 == 0) //which picker?
        {
            [self updateThumbImageByKey : txt : (int)row]; //11/9 move to method
        }
        [self.delegate didSetShapeValue:liltag :(float)row: allParams[liltag] : _texNames[row] :  !rollingDiceNow && !resettingNow];
    }
    else
        [self.delegate didSetShapeValue:liltag :(float)row:allParams[liltag]: rotTypeParams[row] : !rollingDiceNow && !resettingNow];    
}


//-------<UIPickerViewDelegate>-----------------------------
// tell the picker how many rows are available for a given component
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    int tag = (int)pickerView.tag;
    //NSLog(@" picker#rows for tag %d",tag);
    
    if ( tag == PICKER_BASE_TAG)  return _texNames.count;
    else                          return rotTypeParams.count; //10/1
//    return 0; //empty (failed above test?)
    
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
    NSString *txt = [self getPickerTitleForTagAndRow:(int)pickerView.tag:(int)row];
    tView.text = txt;
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

//==========<UITextFieldDelegate>=====================================================
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    //NSLog(@" begin");
    [self.delegate didStartTextEntry:allParams[(textField.tag % 1000)]];  //10/30 pass field name
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

//==========<UITextFieldDelegate>=====================================================
- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    NSLog(@" clear");

    return YES;
}

//==========<UITextFieldDelegate>=====================================================
// It is important for you to hide the keyboard
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    //NSLog(@" return");
    [textField resignFirstResponder]; //Close keyboard
    NSString *s = textField.text;
    int liltag = (int)textField.tag - TEXT_BASE_TAG;
    [self.delegate didSetShapeValue:liltag :0.0: allParams[liltag] : s : FALSE];   //9/20
    // 9/21 take care of name update at top of menu
    if ([allParams[liltag] isEqualToString:@"name"]) titleLabel.text = s;
    return YES;
}



//=====<DUH>======================================================================
// Only assumes square puzzles... colors already set up too!
-(UIImage *) makeTexturedImage : (UIImage *)i : (int) bwid : (int) bhit :
                    (float) ucoord : (float) vcoord :
                    (float) uscale : (float) vscale
{
    if (uscale == 0.0 || vscale == 0.0) return [UIImage imageNamed:@"arrowLeft.png"]; //should be empty image??

    CGRect rect = CGRectMake(0, 0, bwid, bhit ); //fit our target output
    UIGraphicsBeginImageContext(rect.size);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetShouldAntialias(context, NO);
    CGContextSetInterpolationQuality( UIGraphicsGetCurrentContext() , kCGInterpolationNone );

    int xstride = (int)(float)bwid / uscale;
    int ystride = (int)(float)bhit / vscale;
    int x0 = -(int)((float)xstride * ucoord);
    int y  = -(int)((float)ystride * vcoord);

    while (y <= bhit)
    {
        int x = x0;
        while (x <= bwid)
        {
            [i drawInRect:CGRectMake(x,y,xstride,ystride) blendMode:kCGBlendModeNormal alpha:1.0];
            x+=xstride;
        }
        y+=ystride;
    }

    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
} //end makeBitmap




@end
