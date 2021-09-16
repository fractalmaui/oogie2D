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
//
#import "genOogie.h"

@implementation genOogie

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
    psRow.backgroundColor = [UIColor clearColor]; //[UIColor colorWithRed:0.3 green:0 blue:0 alpha:1];
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
    xs = x3 - x2;
    UIPickerView * picker = [[UIPickerView alloc] initWithFrame:CGRectMake(xi,yi,xs,ys)];
    picker.tag = ptag;
    picker.showsSelectionIndicator = YES;
    picker.backgroundColor = [UIColor colorWithRed:0.75 green:0.95 blue:0.75 alpha:1];
    [psRow addSubview:picker];

    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(x3,yi,x4-x3,ys)];
    [slider setBackgroundColor:[UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1]];
    slider.minimumValue = 0.0;
    slider.maximumValue = 100.0;
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


@end
