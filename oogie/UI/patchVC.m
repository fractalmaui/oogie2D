//               _       _    __     __ ____
//   _ __   __ _| |_ ___| |__ \ \   / // ___|
//  | '_ \ / _` | __/ __| '_ \ \ \ / /| |
//  | |_) | (_| | || (__| | | | \ V / | |___
//  | .__/ \__,_|\__\___|_| |_|  \_/   \____|
//  |_|
//
//  patchVC.m
//  oogie2D
//
//  Created by Dave Scruton on 12/13/21.
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//
//  12/16    add header w gradient
//  12/21    add paPanel resize in viewDidAppear
#import "patchVC.h"

@implementation patchVC

//----(patchVC)------------------------------------------------------------
-(id)init
{
    if (self = [super init])
    {
        NSLog(@"patchVC init...");
        [self initAllVars];
        CGSize screenSize   = [UIScreen mainScreen].bounds.size;
        viewWid = screenSize.width;
        viewHit = screenSize.height;
    }
    return self;
}

//----(patchVC)------------------------------------------------------------
-(void) loadView
{
    NSLog(@"patchVC loadView...");
    [super loadView];
    CGSize screenSize   = [UIScreen mainScreen].bounds.size;
    viewWid = screenSize.width;
    viewHit = screenSize.height;
    
    _patchPicker.delegate   = self;
    _patchPicker.dataSource = self;
    _packPicker.delegate    = self;
    _packPicker.dataSource  = self;

    float borderWid = 5.0f;
    UIColor *borderColor = [UIColor whiteColor];
    int xmargin = 20;
    UIColor* resetColor = [UIColor colorWithRed:0.99 green:0.7 blue:0.7 alpha:1];
    _resetButton.layer.cornerRadius   = xmargin;
    _resetButton.clipsToBounds        = TRUE;
    _resetButton.layer.borderWidth    = borderWid;
    _resetButton.titleLabel.textColor = resetColor;         //12/12
    _resetButton.layer.borderColor    = resetColor.CGColor;  //12/12

    _okButton.layer.cornerRadius    = xmargin;
    _okButton.clipsToBounds         = TRUE;
    _okButton.layer.borderWidth     = borderWid;
    _okButton.layer.borderColor     = borderColor.CGColor;
} //end loadView

//----(patchVC)------------------------------------------------------------
- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"patchVC viewDidLoad...");
    paPanel = [[patchPanel alloc] init];
    paPanel.delegate = self;
    CGRect rr2 = _editView.frame; //CGRectMake(0, 0, viewWid, ehit);
    [_editView addSubview:paPanel];
    //add controls to patchPanel, the frame is the WRONG SIZE at this point, see viewDidAppear
    [paPanel setupView:CGRectMake(0, 0, rr2.size.width, rr2.size.height)];
    //why do we need this inited agagin?
    [self initAllVars];
} //end viewDidLoad

//----(patchVC)------------------------------------------------------------
- (void)viewWillAppear:(BOOL)animated
{
    NSLog(@"patchVC viewWillAppear...");
    [super viewWillAppear:animated];

    // 12/16 add header w gradient
    CAGradientLayer *g = [CAGradientLayer layer];
    g.frame = _headerView.bounds;
    UIColor *deepPurple = [UIColor colorWithRed:0.2 green:0.0 blue:0.4 alpha:1]; //[UIColor blackColor].CGColor
    UIColor *blackColor = [UIColor blackColor];
    g.colors = @[ (id)blackColor.CGColor,(id)deepPurple.CGColor ];
    [_headerView.layer insertSublayer:g atIndex:0];
} //end viewWillAppear

//----(patchVC)------------------------------------------------------------
- (void)viewDidAppear:(BOOL)animated
{
    NSLog(@"patchVC viewDidAppear...");
    [super viewDidAppear:animated];
    //12/21 stretch patchpanel to fit editview now that screen is finalized
    CGRect rr2 = _editView.frame; //CGRectMake(0, 0, viewWid, ehit);
    //NSLog(@" editFrame3 %@",NSStringFromCGRect(_editView.frame));
    //NSLog(@" viewWH %d,%d",viewWid,viewHit);
    //WOW> we cant resize the panel UNTIL the view already has appeared!
    //  there HAS to be a better place, but NOT in viewWillAppear!
    [paPanel resizeView: CGRectMake(0, 0, rr2.size.width, rr2.size.height)];
    [self.delegate patchVCDidAppear]; //this triggers data loading of patch names, etc...
}

//----(patchVC)------------------------------------------------------------
-(void) initAllVars
{
    sfx = [soundFX sharedInstance];
    //               A  B  C  D  E  F   G   A
    noteOffsets = @[@0,@2,@3,@5,@7,@8,@10,@12];
    paramEdits = [edits sharedInstance]; //12/20
}

//----(patchVC)------------------------------------------------------------
// pass the buck down to papanel
-(void)configureView
{
    if (paPanel == nil)
    {
        NSLog(@" ERROR NIL PANEL");
        return;
    }
    paPanel.paramDict   = _paramDict;
    paPanel.sampleNames = _sampleNames; //perc sample names...
    [paPanel configureView];
    [_patchPicker reloadAllComponents];  
    [_packPicker  reloadAllComponents];
} //end configureView

//----(patchVC)------------------------------------------------------------
- (IBAction)noteSelect:(id)sender
{
    UIButton *b = (UIButton*)sender;
    int tag = (int)b.tag;
    int note = (tag % 1000);
    oldnote = note;
    NSNumber *nn = noteOffsets[note];
    int finalnote = 0;
    if ([self getSynthChoiceParam:[_paramDict objectForKey:@"type"]] == PERCKIT_VOICE)
        finalnote = note;
    else
        finalnote = 68 + nn.intValue; //hmmm starts at A -> G???
    [self playTestNote:finalnote];
} //end noteSelect

//----(patchVC)------------------------------------------------------------
- (IBAction)resetSelect:(id)sender
{
    [paramEdits removeAllEdits:patchName];
    [self.delegate didResetPatchVC ];    
    [self.delegate patchVCDidSetPatch:patchName]; //and get fresh patch...
}

//----(patchVC)------------------------------------------------------------
- (IBAction)okSelect:(id)sender {
    [self dismissVC];
}


//----(patchVC)------------------------------------------------------------
-(void) dismissVC
{
//    _isUp = FALSE; //8/21
    [self.delegate didDismissPatchVC];
    [self dismissViewControllerAnimated : YES completion:nil];
}

//----(patchVC)------------------------------------------------------------
-(int) getSynthNumericParam : (NSArray*)a
{
    if (a == nil)
    {
        NSLog(@" bad param");
        return 0;
    }
    NSNumber *nn = a.lastObject;
    return (int)(255.0 * nn.floatValue);
}

//----(patchVC)------------------------------------------------------------
-(int) getSynthPercentParam : (NSArray*)a
{
    if (a == nil)
    {
        NSLog(@" bad param");
        return 0;
    }
    NSNumber *nn = a.lastObject;
    return (int)(100.0 * nn.floatValue);
}


//----(patchVC)------------------------------------------------------------
-(int) getSynthChoiceParam : (NSArray*)a
{
    if (a == nil)
    {
        NSLog(@" bad param");
        return 0;
    }
    NSNumber *nn = a.lastObject;
    return  nn.intValue;
}

//----(patchVC)------------------------------------------------------------
-(NSString*) getSynthStringParam : (NSArray*)a
{
    if (a == nil)
    {
        NSLog(@" bad param");
        return 0;
    }
    NSString *s = a.lastObject;
    return s;
}

//----(patchVC)------------------------------------------------------------
// 12/30 for external patch select
-(void) setPatchAndPackPickersFor: (NSString*)patchName : (NSString*)packName
{
    unsigned long row = [_spNames indexOfObject:packName];
    [_packPicker selectRow:row inComponent:0 animated:NO];
    row = [_paNames indexOfObject:patchName];
    [_patchPicker selectRow:row inComponent:0 animated:NO];
}

//----(patchVC)------------------------------------------------------------
// 12/20 build up a synth voice from scratch and play a tone
- (void)playTestNote:(int)note
{
    int note2play = note;
    NSArray *pa; //handles each param
    
    int stype = [self getSynthChoiceParam:[_paramDict objectForKey:@"type"]];

    pa = [_paramDict objectForKey:@"attack"];
    // assume syhth type until proven udderwise
    int buffer = [self getSynthChoiceParam:[_paramDict objectForKey:@"wave"]];
    if (stype != PERCKIT_VOICE)
    {
        [sfx setSynthAttack:    [self getSynthNumericParam : [_paramDict objectForKey:@"attack"]]];
        [sfx setSynthDecay:     [self getSynthNumericParam : [_paramDict objectForKey:@"decay"]]];
        [sfx setSynthSustain:   [self getSynthNumericParam : [_paramDict objectForKey:@"sustain"]]];
        [sfx setSynthSustainL:  [self getSynthNumericParam : [_paramDict objectForKey:@"slevel"]]];
        [sfx setSynthRelease:   [self getSynthNumericParam : [_paramDict objectForKey:@"release"]]];
        [sfx setSynthDuty:      [self getSynthNumericParam : [_paramDict objectForKey:@"duty"]]];
        if (stype != SYNTH_VOICE) //sample / ercussion? get buffer
        {
            NSString *bufname = [self getSynthStringParam : [_paramDict objectForKey:@"name"]];
            NSNumber *NB = _patLookups[bufname];
            buffer = NB.intValue;
            //SAMPLE OFFSET produces no sound if set to nonzero, and sound doesnt come back either!
            [sfx setSynthSampOffset:[self getSynthPercentParam:[_paramDict objectForKey:@"sampleoffset"]]];
        }
        [sfx buildEnvelope : buffer : TRUE];
    }
    else //PercKit? 
    {
        [sfx setSynthAttack:    0];
        [sfx setSynthDecay:     0];
        [sfx setSynthSustain:   0];
        [sfx setSynthSustainL:  0];
        [sfx setSynthRelease:   0];
        NSString *pname = [NSString stringWithFormat:@"percloox_%d",note];
        NSString *sampName = [self getSynthStringParam : [_paramDict objectForKey:pname]];
        NSNumber *NB = _patLookups[sampName];
        buffer = NB.intValue;
        note2play = 64; //middle C?

        pname   = [NSString stringWithFormat:@"perclooxpans_%d",note];
        int pan = [self getSynthNumericParam : [_paramDict objectForKey:pname]];
        [sfx setPan:pan];
    }

    [sfx setSynthPLevel    :      [self getSynthPercentParam:[_paramDict objectForKey:@"plevel"]]];
    [sfx setSynthPKeyOffset:      [self getSynthPercentParam:[_paramDict objectForKey:@"pkeyoffset"]]];
    [sfx setSynthPKeyDetune:      [self getSynthPercentParam:[_paramDict objectForKey:@"pkeydetune"]]];
    
    //generic fields dont really change much?...
    [sfx setSynthPoly : 1];
    [sfx setSynthGain :   255.0]; //9/7
    
    [sfx playNote : note2play : buffer : stype];
} //end playTestnote


#pragma UIPickerViewDelegate

//-------<UIPickerViewDelegate>-----------------------------
- (void)pickerView:(UIPickerView *)pickerView didSelectRow: (NSInteger)row inComponent:(NSInteger)component {
    int tag = (int)pickerView.tag;
    if (tag == 1) //top field is patch
    {
        patchName = _paNames[row];
        paPanel.patchName = patchName;
        [self.delegate patchVCDidSetPatch:patchName];
    }
    else if (tag == 2) //  next is soundpack
    {
        NSString *spname = _spNames[row];
        [self.delegate patchVCDidSetPack:spname];
    }

}
 
//-------<UIPickerViewDelegate>-----------------------------
// tell the picker how many rows are available for a given component
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    int tag = (int)pickerView.tag;
    if (tag == 1) return _paNames.count;
    if (tag == 2) return _spNames.count;
    return 0;
}

//-------<UIPickerViewDelegate>-----------------------------
// always have ONE component per picker!
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

//-------<UIPickerViewDelegate>-----------------------------
- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view{
    UILabel* tView = (UILabel*)view;
    int tag = (int)pickerView.tag;
    if (!tView){
        tView = [[UILabel alloc] init];
            // Setup label properties - frame, font, colors etc
        tView.frame = CGRectMake(0,0,200,15); //5/24 shrinkem
        [tView setFont:[UIFont fontWithName:@"Helvetica Neue" size: 16.0]];
    }
    NSString *t = [NSString stringWithFormat:@"row %d",(int)row];
    // Fill the label text here
    if (tag == 1) t = _paNames[row];
    if (tag == 2) t = _spNames[row];

    tView.text = t;
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

//=====<patchPanelDelegate>====================================================
// this needs to loop over all voices with current patch and perform edit
-(void) didSetPatchValue  : (int) which : (float) newVal : (NSString*) pname : (NSString*) pvalue : (BOOL)undoable
{
    NSLog(@"patchVC: didsetPatchValue %d %f %@ %@ %d",which,newVal,pname,pvalue,undoable);
    [self.delegate patchVCChangedWorkPatch : pname : newVal :pvalue];
}

-(void) didSelectPatchDice
{
    
}
-(void) didSelectPatchReset ;
{
    
}
-(void) didSelectPatchDismiss
{
    
}


@end
