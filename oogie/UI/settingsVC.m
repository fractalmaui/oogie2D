//
//            _   _   _               __     ______
//   ___  ___| |_| |_(_)_ __   __ _ __\ \   / / ___|
//  / __|/ _ \ __| __| | '_ \ / _` / __\ \ / / |
//  \__ \  __/ |_| |_| | | | | (_| \__ \\ V /| |___
//  |___/\___|\__|\__|_|_| |_|\__, |___/ \_/  \____|
//                            |___/
//
//  settingsVC.m
//  oogieCam
//
//  Created by Dave Scruton on 6/22/20.
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//
//  10/23/21 copy fresh from oogieCam, pull all appDelegate refs for now
//  11/29    add liveMarkers, viewWillAppear
//  12/2     add haltAudio flag
//  12/9     add verbose flag/switch
//  12/12    add more functions to reset, now factory reset
//  12/16    add header w gradient, add version label
//  12/29    add promptForDeletes
#import "settingsVC.h"
//NOTE this varies between 2D and AR versions!
//#import "oogie-Swift.h"
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


//======(controlsVC)==========================================
-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    // 11/29 moved stuff here from viewDidAppear
    AppDelegate *sappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    // 12/16 add header w gradient
    CAGradientLayer *g = [CAGradientLayer layer];
    g.frame = _headerView.bounds;
    UIColor *deepPurple = [UIColor colorWithRed:0.2 green:0.0 blue:0.4 alpha:1]; //[UIColor blackColor].CGColor
    UIColor *blackColor = [UIColor blackColor];
    g.colors = @[ (id)blackColor.CGColor,(id)deepPurple.CGColor ];
    [_headerView.layer insertSublayer:g atIndex:0];

    tempo            = (int)sappDelegate.masterTempo;
    tune             = (int)sappDelegate.masterTune;
    liveMarkers      = (int)sappDelegate.liveMarkers; //11/29
    haltAudio        = (int)sappDelegate.haltAudio; //12/2
    promptForDeletes = (int)sappDelegate.promptForDeletes; //12/29
    oldnote = 0;
    octave  = 0;
    
    //12/16 get version#, NOTE in project General settings we need to set the Build field to see this!,
    //           NOT the version field. WTF??? how do i get the version field?
    // NSString *bv =   [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
    //_bundleLabel.text = [NSString stringWithFormat:@"Build : %@  Bundle : %@",[self GetBuildDate],bv];
    _versionLabel.text = sappDelegate.versionStr;

    [self configureView];
} //end viewWillAppear


//======(controlsVC)==========================================
-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

//======(controlsVC)==========================================
-(void) configureView
{
    //set up sliders / etc
    [_tempoSlider setValue:(float)tempo];
    _tempoLabel.text = [NSString stringWithFormat:@"%d",tempo];
    [_tuneSlider   setValue:(float)tune];
    _tuneLabel.text = [NSString stringWithFormat:@"%d",tune];
    
    [_statsSwitch setOn            : _showStatistics];
    [_liveMarkersSwitch setOn      : ( liveMarkers == 1)];
    [_haltAudioSwitch setOn        : ( haltAudio == 1)];
    [_verboseSwitch setOn          : _verbose];
    [_promptForDeletesSwitch setOn : ( promptForDeletes == 1)];

    //12/1 add bkgd color, still looks bad
    [_statsSwitch            setBackgroundColor:[UIColor darkGrayColor]];
    [_liveMarkersSwitch      setBackgroundColor:[UIColor darkGrayColor]];
    [_haltAudioSwitch        setBackgroundColor:[UIColor darkGrayColor]];
    [_verboseSwitch          setBackgroundColor:[UIColor darkGrayColor]];
    [_promptForDeletesSwitch setBackgroundColor:[UIColor darkGrayColor]];
} //end configureView


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
    [sappDelegate updateMasterTempoWithValue      : tempo];
    [sappDelegate updateMasterTuneWithValue       : tune];
    [sappDelegate updateLiveMarkersWithValue      : liveMarkers ]; //11/29
    [sappDelegate updateHaltAudioWithValue        : haltAudio ]; //12/2
    [sappDelegate updatePromptForDeletesWithValue : promptForDeletes ]; //12/29
    
    [self.delegate settingsVCChanged];
}

//======(settingsVC)==========================================
-(void) dismissVC
{
    [self.delegate didDismissSettingsVC];
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
} //end noteSelect

//======(settingsVC)==========================================
- (IBAction)statsSwitchChanged:(id)sender
{
    UISwitch *sw = (UISwitch*)sender;
    _showStatistics = sw.on;
    [self.delegate settingsVCChanged];
}

//======(settingsVC)==========================================
// 11/29 new
- (IBAction)liveMarkersSwitchChanged:(id)sender
{
    UISwitch *sw = (UISwitch*)sender;
    liveMarkers = sw.on ? 1 : 0;
    [self updateAppDelegate]; //let app know this switch got changed
    [self.delegate settingsVCChanged];
}

//======(settingsVC)==========================================
- (IBAction)haltAudioswitchChanged:(id)sender
{
    UISwitch *sw = (UISwitch*)sender;
    haltAudio = sw.on ? 1 : 0;
    [self updateAppDelegate]; //let app know this switch got changed
    [self.delegate settingsVCChanged];
}

//======(settingsVC)==========================================
- (IBAction)verboseSwitchChanged:(id)sender
{
    UISwitch *sw = (UISwitch*)sender;
    _verbose = sw.on;
    [self.delegate settingsVCChanged];
}

//======(settingsVC)==========================================
// 12/29 new
- (IBAction)promptForDeletesSwitchChanged:(id)sender
{
    UISwitch *sw = (UISwitch*)sender;
    promptForDeletes = sw.on ? 1 : 0;
    [self updateAppDelegate]; //let app know this switch got changed

}


//======(settingsVC)==========================================
// 12/12 redo for factory reset
- (IBAction)resetSelect:(id)sender {
    
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                    NSLocalizedString(@"Perform Factory Reset",nil)
                                    message:@"This will delete all patch edits, reset all settings and re-initialize all built-in scenes..."
                                    preferredStyle:UIAlertControllerStyleAlert];
    //12/19 test for dark mode    alert.view.tintColor = [UIColor blackColor]; //lightText, works in darkmode
    
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil)
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            tempo       = 135;
            tune        = 0;
            haltAudio   = 1; //12/2
            liveMarkers = 0;
            promptForDeletes = 1; //12/29
            [self configureView];
            [self updateAppDelegate];
            [self.delegate didResetSettingsVC];
            [self dismissVC];  //12/12 OK we are done!
                                                  }]];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                  }]];
        [self presentViewController:alert animated:YES completion:nil];

}


//======(settingsVC)==========================================
- (IBAction)okSelect:(id)sender {
    [self dismissVC];
}

//======(settingsVC)==========================================
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


//======(settingsVC)==========================================
// 12/16 from HDK
- (NSString *)GetBuildDate
{
    NSString *buildDate;
    
    // Get build date and time, format to 'yyMMddHHmm'
    NSString *dateStr = [NSString stringWithFormat:@"%@ %@", [NSString stringWithUTF8String:__DATE__], [NSString stringWithUTF8String:__TIME__]];
    
    // Convert to date
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"LLL d yyyy HH:mm:ss"];
    NSDate *date = [dateFormat dateFromString:dateStr];
    
    // Set output format and convert to string
    //    [dateFormat setDateFormat:@"yyMMddHHmm"];
    [dateFormat setDateFormat:@"EEE, MMM d, yyyy"];
    buildDate = [dateFormat stringFromDate:date];
    
    return buildDate;
}


@end
