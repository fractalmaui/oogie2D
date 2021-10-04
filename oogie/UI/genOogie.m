//
//  genOogie.m
//  oogieCam
//
//  Created by Dave Scruton on 9/15/20.
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//
//  4/26 analyze cleanup, 4/28 fix typo from cleanup ;)
//  6/19/21 change label font, bolder
//  7/9  add oogieStyles
//  9/18 add configureViewFromVC, huge but effective, works on all control panels
//  10/3 addpickerSlider: unit sliders please!, also changed picker width
#import "genOogie.h"

@implementation genOogie

double drand(double lo_range,double hi_range );

static genOogie *sharedInstance = nil;

//=====(genOogie)======================================================================
// Get the shared instance and create it if necessary.
+ (genOogie *)sharedInstance {
    if (sharedInstance == nil) {
        sharedInstance = [[super allocWithZone:NULL] init];
    }    
    return sharedInstance;
}

//=====(genOogie)======================================================================
-(instancetype) init
{
    if (self = [super init])
    {
        //NSLog(@"genOogie is born");
    }
    return self;
}


//=====(genOogie)======================================================================
-(NSArray*) addPickerRow : (UIView*) parent : (int) tag : (NSString*) label :
                (int) yoff : (int) width : (int) ysize
{
    int xs,ys,xi,yi;
        
    xi = 0;
    yi = yoff;
    xs = width;
    ys = ysize;
    //9/16 everything lives in an UIView...
    UIView *pickerRow = [[UIView alloc] init];
    [pickerRow setFrame : CGRectMake(xi,yi,xs,ys)];
    pickerRow.backgroundColor = [UIColor clearColor]; // [UIColor colorWithRed:0 green:0 blue:.4 alpha:1];
    [parent addSubview:pickerRow];

    //get 3 columns...
    int x1 = 0.05 * width;
    int x2 = 0.30 * width;
    int x3 = 0.95 * width;
    
    xi = x1; //4/26
    yi = 0; //top of view
    xs = x2-x1 - 5; //4/26  and 7/9/21
    ys = ysize;  //label / slider hite
    
    UILabel *l = [[UILabel alloc] initWithFrame: //label goes from col 1 to 2
                  CGRectMake(xi,yi,xs,ys)];
    [l setTextColor : [UIColor whiteColor]];
    [l setFont:OOG_LABEL_FONT]; //7/9/21
    [l setTextAlignment:OOG_LABEL_ALIGN];  //7/9/21 testo
    l.text = label;
    [pickerRow addSubview : l];

    xi = x2;
    UIPickerView * picker = [[UIPickerView alloc] initWithFrame:CGRectMake(xi,yi,x3-x2,ys)];
    picker.tag = tag;
    picker.showsSelectionIndicator = YES;
    picker.backgroundColor = [UIColor colorWithRed:0.85 green:0.75 blue:0.75 alpha:1];
    [pickerRow addSubview:picker];

    return @[picker]; //maybe add more handles later?
} //end addPickerRow

//=====(genOogie)======================================================================
-(NSArray*) addPickerSliderRow : (UIView*) parent : (int) ptag : (int) stag : (NSString*) label :
                        (int) yoff : (int) width : (int) ysize
{
    int xs,ys,xi,yi;
    
    xi = 0;
    yi = yoff;
    xs = width;
    ys = ysize;
    //9/15 everything lives in an UIView...
    UIView *psRow = [[UIView alloc] init];
    [psRow setFrame : CGRectMake(xi,yi,xs,ys)];
    psRow.backgroundColor = [UIColor blueColor]; //was clear
    [parent addSubview:psRow];

    //get 4 columns...
    int x1 = 0.05 * width;
    int x2 = 0.3  * width;
    int x3 = 0.6  * width;
    int x4 = 0.95 * width;

    xi = x1; //4/26
    yi = 0; //top of form
    ys = ysize;  //label / slider hite
    xs = x2-x1 - 5;  //4/26, 4/28 fix typo and 7/9/21
    
    UILabel *l = [[UILabel alloc] initWithFrame: //label goes from col 1 to 2
                  CGRectMake(xi,yi,xs,ys)];
    [l setTextColor : [UIColor whiteColor]];
    [l setFont:OOG_LABEL_FONT]; //7/9/21
    [l setTextAlignment:OOG_LABEL_ALIGN];  //7/9/21 testo
    l.text = label;
    [psRow addSubview : l];
    
    xi = x2;
    xs = x3 - x2 + 140; //10/3 stretch to accomodate bug where labels get chopped of LH side
    UIPickerView * picker = [[UIPickerView alloc] initWithFrame:CGRectMake(xi,yi,xs,ys)];
    picker.tag = ptag;
    picker.showsSelectionIndicator = YES;
    picker.backgroundColor = [UIColor colorWithRed:0.75 green:0.95 blue:0.75 alpha:1];
    [psRow addSubview:picker];

    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(x3,yi,x4-x3,ys)];
    [slider setBackgroundColor:[UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1]];
    slider.minimumValue = 0.0;
    slider.maximumValue = 1.0; //10/3 unit sliders please!
    slider.continuous   = YES;
    slider.value        = 0;
    slider.tag          = stag;
    [psRow addSubview:slider];
    return @[picker , slider]; //maybe add more handles later?

} //end addPickerSliderRow



//=====(genOogie)======================================================================
// adds a canned label/slider set...
-(NSArray*) addSliderRow : (UIView*) parent : (int) tag : (NSString*) label :
            (int) yoff : (int) width : (int) ysize :
            (float) smin : (float) smax
{
    int xs,ys,xi,yi;
    
    //get 3 columns...
    int x1 = 0.0; //7/9/21 shrink LH margin
    int x2 = 0.30 * width;
    int x3 = 0.95 * width;
    
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
    xs = x2-x1-5; //7/9/21 test w/ RH align
    UILabel *l = [[UILabel alloc] initWithFrame: //label goes from col 1 to 2
                  CGRectMake(xi,yi,xs,ys)];
    [l setFont:OOG_LABEL_FONT];  //7/9/21
    [l setTextColor : [UIColor whiteColor]];
    [l setTextAlignment:OOG_LABEL_ALIGN];  //7/9/21 testo
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
    return @[slider]; //maybe add more handles later?
} //end addSliderRow

//=====(genOogie)======================================================================
// 9/11/21 new for oogieAR / 2D
-(NSArray*) addTextRow : (UIView*) parent : (int) tag : (NSString*) label :
                (int) yoff : (int) width : (int) ysize
{
    int xs,ys,xi,yi;
    
    //get 3 columns...
    int x1 = 0.0; //7/9/21 shrink LH margin
    int x2 = 0.30 * width;
    int x3 = 0.95 * width;
    
    xi = 0;
    yi = yoff;
    xs = width;
    ys = ysize;
    //9/15 everything lives in an UIView...
    UIView *textRow = [[UIView alloc] init];
    [textRow setFrame : CGRectMake(xi,yi,xs,ys)];
    textRow.backgroundColor = [UIColor clearColor]; //[UIColor colorWithRed:0.3 green:0 blue:0 alpha:1];
    [parent addSubview:textRow];
    // NSLog(@" addTextRow (xi %d yi %d  xs %d ys %d) [%@]", xi,yi,xs,ys,label);
    xi = x1; //4/26
    yi = 0; //back to top left...
    xs = x2-x1-5; //7/9/21 test w/ RH align
    UILabel *l = [[UILabel alloc] initWithFrame: //label goes from col 1 to 2
                  CGRectMake(xi,yi,xs,ys)];
    [l setFont:OOG_LABEL_FONT];  //7/9/21
    [l setTextColor : [UIColor whiteColor]];
    [l setTextAlignment:OOG_LABEL_ALIGN];  //7/9/21 testo
    l.text = label;
    [textRow addSubview : l];
    
    xi = x2;
    xs = x3-x2;
    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(xi,yi,xs,ys)];
    [textField setBackgroundColor:[UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1]];
    textField.text = @"test...";
    textField.tag          = tag;
    [textRow addSubview:textField];
    return @[textField]; //maybe add more handles later?

} //end addTextRow

//======(oogieCamGeneric)==========================================
// This thing is HUGE, but it should be able to set up any UI
//   given the right info:
//      reset: set controls to default values or current value
//      pDict: dictionary of parameter names,types,min/max,default, etc
//      allPick/allSlid/allText: arrays of pickers,sliders,text fields
//      noResetParams: parameters immune to reset

-(NSMutableDictionary*) configureViewFromVC : (BOOL) reset : (NSDictionary*) pDict : (NSArray*) allP :
                    (NSArray*) allPick : (NSArray*) allSlid : (NSArray*) allText :
                    (NSArray*)noResetParams : (NSDictionary*)pickerChoices
{
    NSMutableDictionary *resetDict = [[NSMutableDictionary alloc] init];
    //Now how do I peel this off? it needs a LOT of arguments!!
    //  but it would be easier to reuse this method across all panels!!!
    //make some dicts...
    NSMutableDictionary *tagsByName = [[NSMutableDictionary alloc] init];
    for (int i=0;i<allP.count;i++)
    {
        NSNumber *nn = [NSNumber numberWithInt:i];
        [tagsByName setObject:nn forKey:allP[i]];
    }
    NSMutableDictionary *controlsByTag = [[NSMutableDictionary alloc] init];
    //Note we are dealing with controls from the calling VC!!! Watch it!
    for (int i=0;i < allPick.count;i++)
    {
        UIPickerView *p = (UIPickerView*)allPick[i];
        NSNumber *nn = [NSNumber numberWithInt:(int)(p.tag % 1000)]; //only keep lsb of tag
        [controlsByTag setObject:p forKey:nn];
    }
    for (int i=0;i < allSlid.count;i++)
    {
        UISlider *s = (UISlider*)allSlid[i];
        NSNumber *nn = [NSNumber numberWithInt:(int)(s.tag % 1000)];
        [controlsByTag setObject:s forKey:nn];
    }
    for (int i=0;i < allText.count;i++)
    {
        UITextField *t = (UITextField*)allText[i];
        NSNumber *nn = [NSNumber numberWithInt:(int)(t.tag % 1000)];
        [controlsByTag setObject:t forKey:nn];
    }

    //look at incoming params dict...
    // Something funny going on with bottomMidi, tries to set slider negative.
    //  this means there is a bug converting this param from its stored value to
    //  a value the UI can use... most other double params look OK
    for (NSString*key in pDict.allKeys)
    {
        BOOL ok = TRUE;
        if (reset) //reset? make sure some stuff doesnt reset!
        {
            if ([noResetParams containsObject: key] ) //bad params!
                {NSLog(@" bing! bad param %@",key);ok=FALSE;}
        }
        if (!ok) continue;
        NSLog(@"key %@",key);
        NSNumber *tagnum = tagsByName[key];
        if (tagnum != nil) //Found it!?
        {
            int tag = tagnum.intValue;
            NSObject* genericControl = controlsByTag[tagnum];
            //our dict contains arrays, we want the last item
            NSArray* a = pDict[key];
            if (a.count > 1) //got something?
            {
                id<NSObject> value;
                if (!reset)
                    value = [a lastObject]; //get current value..
                else if (a.count > 4)
                    value = [a objectAtIndex:4]; //get default..
                NSString *ss = @"";
                NSNumber *nn = @0;
                if ([value isKindOfClass:[NSString class]]) ss = (NSString*) value;
                else                                        nn = (NSNumber*) value;
                NSLog(@"   match param %@ tag %d : %@ %@",key,tagnum.intValue,nn,ss);

                if ([genericControl isKindOfClass:[UISlider class]]) //setup slider
                {
                    double dval = nn.doubleValue;
                    UISlider *s = (UISlider*)genericControl;
                    if (reset) //reset? add to reset list
                    {
                        //10/3 convert from param to unit...
                        value = [a objectAtIndex:5]; // mult
                        nn = (NSNumber*) value;
                        double dmult = nn.doubleValue;
                        value = [a objectAtIndex:6]; // offset
                        nn = (NSNumber*) value;
                        double doff = nn.doubleValue;
                        if (dmult != 0.0)
                        {
                            dval = (dval - doff) / dmult;
                        }
                        [resetDict setObject:@[tagnum,[NSNumber numberWithDouble:dval],@""] forKey:key];
                    }
                    NSLog(@" ...set slider tag[%d] to %f",tag,dval);
                    [s setValue:dval];
                }
                else if ([genericControl isKindOfClass:[UIPickerView class]]) //setup picker
                    {
                        int row = 0;
                        if (!reset) //default picker val is 0 for now, not default? get value
                        {
                            if (ss != nil) //picker set via string? need to search...
                            {
                                //see if we have picker choices...
                                NSArray* pchoices = pickerChoices[tagnum];
                                if (pchoices != nil) //match? find our string!
                                {
                                    for (int i=0;i<pchoices.count;i++)
                                    {
                                        NSString *test = pchoices[i];
                                        // 10/3 case-insensitive check
                                        if ([[test lowercaseString] isEqualToString:[ss lowercaseString]])
                                            {row = i;break;}  //found our string choice? set row
                                    }
                                }
                                else row = ss.intValue; //try to get int from string
                            }
                            else //numeric? just pull it for picker...
                            {
                                row = nn.intValue;
                            }
                        } //end !reset
                        
                        UIPickerView *p = (UIPickerView*)genericControl;
                        if (reset) //reset? add to reset list
                            [resetDict setObject:@[tagnum,[NSNumber numberWithInt:row],@""] forKey:key];
                        NSLog(@" ...set picker tag[%d] to row %d",tag,row);
                        [p selectRow:row inComponent:0 animated:YES];
                    }
                else if ([genericControl isKindOfClass:[UITextField class]]) //setup text
                {
                    UITextField *t = (UITextField*)genericControl;
                    NSLog(  @".... set text tag[%d] to [%@]",tag,ss);
                    if (reset) //default text?
                    {
                        if ([key isEqualToString:@"name"]) ss = @"shape000"; //kinda clugey!
                    }
                    t.text = ss;
                    if (reset) //reset? add to reset list
                        [resetDict setObject:@[tagnum,@0,ss] forKey:key];
                }
            }
        } //end if tagnum
    } //end for key
    
    return resetDict;
}  //end configureViewFromVC

//======(oogieCamGeneric)==========================================
// 9/18 generic randomize, should work on all panels
-(NSMutableDictionary*) randomizeFromVC  : (NSArray*) allP :
                    (NSArray*) allPick : (NSArray*) allSlid :
                    (NSArray*)noRandomizeParams
{
    NSMutableDictionary *resetDict = [[NSMutableDictionary alloc] init];
    //ok randomize sliders...
    for (int i=0;i<allSlid.count;i++)  //ok randomize all sliders
    {
        UISlider *s = allSlid[i];
        if (s != nil)  //valid control?
        {
            int tag         = (int)s.tag % 1000;
            NSNumber *tagnum = [NSNumber numberWithInt:tag];
            NSString *pname = allP[tag];    //param name ...
            if ([noRandomizeParams containsObject:pname] )  //no randomize?
            {
                NSLog(@" bing! bad slider randomize  %d / %@ ",tag,pname);
            }
            else
            { //OK! diceit!
                double dval = drand(0.0,1.0);
                [s setValue: dval];   //set value, let parent know...
                [resetDict setObject:@[tagnum,[NSNumber numberWithDouble:dval],@""] forKey:pname];
            }
        }
    }
   for (int i=0;i<allPick.count;i++)  //ok randomize all pickers
    {
        UIPickerView *p = allPick[i];
        if (p != nil)  //valid control?
        {
            int tag          = (int)p.tag % 1000;
            NSNumber *tagnum = [NSNumber numberWithInt:tag];
            NSString *pname  = allP[tag];        //param name ...
            if ([noRandomizeParams containsObject:pname] )  //no randomize?
            {
                NSLog(@" bing! bad picker randomize  %d / %@ ",tag,pname);
            }
            else{ //OK! diceit!
                int numrows     = (int)[p numberOfRowsInComponent:0];
                int row         = ((int)(drand(0.0,(double)numrows)));
                // keep it clean
                row = MAX(0,MIN(numrows-1,row));
                [p selectRow:row inComponent:0 animated:YES];
                [resetDict setObject:@[tagnum,[NSNumber numberWithDouble:row],@""] forKey:pname];
            }
        }
    }
    return resetDict;
} //end RandomizeFromVC


@end
