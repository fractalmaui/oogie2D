//
//
//  settingsVC.m
//  oogieCam
//
//  Created by Dave Scruton on 6/22/20.
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//
//  10/23/21 copy fresh from oogieCam, pull all appDelegate refs for now

#import "settingsVC.h"
#import "oogie2D-Swift.h"

@implementation settingsVC
                   // A,B,C,D,E,F,G,A

//======(settingsVC)==========================================
- (instancetype)init
{
    self = [super init];
    [self initAllVars];
    return self;
}

//======(controlsVC)==========================================
-(void) loadView
{
    [super loadView];
    float borderWid = 5.0f;
    UIColor *borderColor = [UIColor whiteColor];
    int xmargin = 20;

    _resetButton.layer.cornerRadius = xmargin;
    _resetButton.clipsToBounds      = TRUE;
    _resetButton.layer.borderWidth  = borderWid;
    _resetButton.layer.borderColor  = borderColor.CGColor;

    _okButton.layer.cornerRadius    = xmargin;
    _okButton.clipsToBounds         = TRUE;
    _okButton.layer.borderWidth     = borderWid;
    _okButton.layer.borderColor     = borderColor.CGColor;
} //end loadView


//======(controlsVC)==========================================
-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    AppDelegate *sappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    tempo = (int)sappDelegate.masterTempo;
    tune  = (int)sappDelegate.masterTune;
    
    oldnote = 0;
    octave  = 0;

    [self configureView];
}

//======(controlsVC)==========================================
-(void) configureView
{
    //set up sliders / etc
    [_tempoSlider setValue:(float)tempo];
    _tempoLabel.text = [NSString stringWithFormat:@"%d",tempo];
    [_tuneSlider   setValue:(float)tune];
    _tuneLabel.text = [NSString stringWithFormat:@"%d",tune];
    
    [_statsSwitch setOn : _showStatistics];
}


//======(storeVC)==========================================
-(id)initWithCoder:(NSCoder *)aDecoder {
    if ( (self = [super initWithCoder:aDecoder]) )
    { [self initAllVars]; }
    return self;
}

//======(settingsVC)==========================================
-(void) initAllVars
{
    tempo = tune = 0;
    sfx = [soundFX sharedInstance];
    //               A  B  C  D  E  F   G   A
    noteOffsets = @[@0,@2,@3,@5,@7,@8,@10,@12];
}

//======(settingsVC)==========================================
-(void) updateAppDelegate
{
    AppDelegate *sappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [sappDelegate updateMasterTempoWithValue:tempo];
    [sappDelegate updateMasterTuneWithValue :tune];
    [self.delegate settingsVCChanged];

}

//======(settingsVC)==========================================
-(void) dismissVC
{
    [self dismissViewControllerAnimated : YES completion:nil];
}

//======(settingsVC)==========================================
- (IBAction)tempoSliderChanged:(id)sender
{
    UISlider *s = (UISlider*)sender;
    float v = s.value;
    tempo = (int)v;
    _tempoLabel.text = [NSString stringWithFormat:@"%d",tempo];
    [self updateAppDelegate];
}

//======(settingsVC)==========================================
- (IBAction)tuneSliderChanged:(id)sender {
    UISlider *s = (UISlider*)sender;
    float v = s.value;
    tune = (int)v;
    _tuneLabel.text = [NSString stringWithFormat:@"%d",tune];
    [self updateAppDelegate];
}

//======(settingsVC)==========================================
- (IBAction)noteSelect:(id)sender {
    UIButton *b = (UIButton*)sender;
    int tag = (int)b.tag;
    int note = (tag % 1000);
    if (note == oldnote) //advance octave
    {
        octave++;
        if (octave > 1) octave = -1;
    }
    else octave = 0;  //new note, back to orig. octave
    oldnote = note;
    NSNumber *nn = noteOffsets[note];
    int finalnote = 68 + 12*octave + nn.intValue; //hmmm starts at A -> G???
    //NSLog(@" note %d -> %d",note,finalnote);
    [self playNote:finalnote];
}
//======(settingsVC)==========================================
- (IBAction)statsSwitchChanged:(id)sender
{
    UISwitch *sw = (UISwitch*)sender;
    _showStatistics = sw.on;
    [self.delegate settingsVCChanged];

}

//======(settingsVC)==========================================
- (IBAction)resetSelect:(id)sender {
    tempo = 135;
    tune  = 0;
    [self configureView];
    [self updateAppDelegate];
}


//======(settingsVC)==========================================
- (IBAction)okSelect:(id)sender {
    [self dismissVC];
}

//======(samplesVC)==========================================
- (void)playNote:(int)note
{
    [sfx setSynthGain :   255.0]; //9/7
    [sfx setSynthMono :     0];
    [sfx setSynthAttack:    0];
    [sfx setSynthDecay:     0];
    [sfx setSynthSustain:   0];
    [sfx setSynthSustainL:  0];
    [sfx setSynthRelease:   0];
    [sfx setSynthSampOffset:0];
    [sfx playNote : note : 0 : SYNTH_VOICE];
} //end playnote



@end
