//                             _         __     ______
//   ___  __ _ _ __ ___  _ __ | | ___  __\ \   / / ___|
//  / __|/ _` | '_ ` _ \| '_ \| |/ _ \/ __\ \ / / |
//  \__ \ (_| | | | | | | |_) | |  __/\__ \\ V /| |___
//  |___/\__,_|_| |_| |_| .__/|_|\___||___/ \_/  \____|
//                      |_|
//
//
//  samplesVC.m
//  oogieCam
//
//  Created by Dave Scruton on 6/22/20.
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//
//  10/23/21 copy fresh from oogieCam, pull all appDelegate refs for now

#import "samplesVC.h"
//#import "AppDelegate.h" //KEEP this OUT of viewController.h!!


@implementation samplesVC
//AppDelegate *sappDelegate;

//======(samplesVC)==========================================
- (instancetype)init
{
    self = [super init];
//    sappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    rawFileNames = [[NSMutableArray alloc] init];
    
    playing       = [[NSMutableArray alloc] init];

    fileDict      = [[NSMutableDictionary alloc] init];

    dformatter =  [[NSDateFormatter alloc] init]; //9/11
    [dformatter setDateFormat:@"EEEE, MM/d/YYYY h:mma"];

    fileNamesNoNumberSigns = [[NSMutableArray alloc] init];
    sfx = [soundFX sharedInstance];

    inv441 = 1.0 / 44100.0; //for computing sample time interval...
    _isUp = FALSE; //8/21
    // 8/12 add notification for ProMode demo...
    [[NSNotificationCenter defaultCenter]
                            addObserver: self selector:@selector(demoNotification:)
                                   name: @"demoNotification" object:nil];
    return self;
}

//======(samplesVC)==========================================
// 7/13 new
-(void) loadView
{
    [super loadView];
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    viewWid = screenSize.width;
    viewHit = screenSize.height;
    buttonWid = viewWid * 0.17; //10/4 REDO button height,scale w/width
//    if (sappDelegate.gotIPad) buttonWid = viewWid * 0.08; //3/27 smaller buttons on ipad
    buttonHit = buttonWid;
    
    self.view.backgroundColor = [UIColor blackColor];
    
    int xs,ys,xi,yi;
    yi = 0;
    yi += 32; //10/23 just account for top notch for now...
//    if (sappDelegate.hasTopNotch) yi += 32; //watch out for top notch
    xs = viewWid;
    ys = 40;
    xi = viewWid * 0.5 - xs*0.5;;
    titleLabel = [[UILabel alloc] initWithFrame:
                  CGRectMake(xi, yi, xs , ys)];
    //7/14 redo look
    [titleLabel setFont: [UIFont systemFontOfSize:28 weight:UIFontWeightBold]];
    [titleLabel setTextColor:[UIColor whiteColor]];
    [titleLabel setBackgroundColor:[UIColor blackColor]];
    [titleLabel setText:@"Sample Manager"];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [[self view] addSubview:titleLabel];

    int footerHit = buttonHit;

    yi += ys; //skip down below title
    xs = viewWid;
    ys = viewHit - yi - footerHit; //4/26 better fit
    ys -= 32; //10/23 just account for top notch for now...

//    if ([sappDelegate hasTopNotch]) ys-=32; //4/26

    table = [[UITableView alloc] initWithFrame:CGRectMake(xi, yi, xs, ys)];
    table.backgroundColor = [UIColor blackColor]; //colorWithRed:0.95 green:0.95 blue:1.0 alpha:1];
    [[self view] addSubview:table];
    table.delegate = self;
    table.dataSource = self;
    selectedIndexPath = [NSIndexPath indexPathWithIndex:0];
    
    xs = viewWid;
    xi = 0;
    ys = footerHit;
    yi = viewHit-ys;
    ys -= 32; //10/23 just account for top notch for now...
//    if ([sappDelegate hasTopNotch]) yi-=32;
    footer = [[UIView alloc] init];
    [footer setFrame : CGRectMake(xi,yi,xs,ys)];
    footer.clipsToBounds = FALSE;
    footer.layer.shadowColor = [UIColor blackColor].CGColor;
    footer.layer.shadowOffset = CGSizeMake(0,-12);
    footer.layer.shadowOpacity = 0.3;
    footer.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:1];
    [self.view addSubview:footer];
    
    //Add OK button
    float borderWid = 5.0f;
    UIColor *borderColor = [UIColor whiteColor];
    int xmargin = 20;
    int ymargin = 8;
    
    // 7/20 import button hidden for now, no cloud entitlements!
//    xs = viewWid*0.35;
//    ys = buttonHit * 0.9 - 2*ymargin;
//    xi = xmargin;
//    yi = ymargin;
//    importButton = [UIButton buttonWithType:UIButtonTypeCustom];
//    [importButton setTitle:@"TEST" forState:UIControlStateNormal]; //7/13
//    [importButton setFrame:CGRectMake(xi, yi, xs, ys)];
//    [importButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
//    importButton.backgroundColor    = [UIColor blackColor];
//    importButton.layer.cornerRadius = xmargin;
//    importButton.clipsToBounds      = TRUE;
//    importButton.layer.borderWidth  = borderWid;
//    importButton.layer.borderColor  = borderColor.CGColor;
//    [importButton addTarget:self action:@selector(testSelect:) forControlEvents:UIControlEventTouchUpInside];
//    [footer addSubview:importButton];
//    importButton.hidden = TRUE;
    
    // 4/26 add helpful info
    xi = xmargin;
    xs = viewWid*0.75 - xmargin;
    yi = ymargin;
    ys = 40;
    bottomInfoLabel = [[UILabel alloc] initWithFrame:  CGRectMake(xi, yi, xs , ys)];
    [bottomInfoLabel setFont:[UIFont fontWithName:@"AvenirNext-Bold" size:(int)12]];
    [bottomInfoLabel setTextColor:[UIColor colorWithRed: 0.5 green: .9 blue:.9 alpha: 1.0f]];
    [bottomInfoLabel setBackgroundColor:[UIColor clearColor]];
    [bottomInfoLabel setText:@"Samples can be found in the Files App\n  under oogieCam/samples"];
    [bottomInfoLabel setNumberOfLines : 0];
    bottomInfoLabel.textAlignment = NSTextAlignmentLeft;
    [footer addSubview:bottomInfoLabel];
    //TEST 5/17
    //bottomInfoLabel.hidden = TRUE;
    
    // 2/6/21 change to Done label, match size in storeVC
    ys =  buttonHit * 0.9 - 2*ymargin;
    yi = ymargin;
    xs = viewWid*0.20;
    xi = viewWid - xs - xmargin;
    okButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [okButton setTitle:@"Done" forState:UIControlStateNormal];
    [okButton setFrame:CGRectMake(xi, yi, xs, ys)];
    [okButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    okButton.backgroundColor    = [UIColor blackColor];
    okButton.layer.cornerRadius = xmargin;
    okButton.clipsToBounds      = TRUE;
    okButton.layer.borderWidth  = borderWid;
    okButton.layer.borderColor  = borderColor.CGColor;
    [okButton addTarget:self action:@selector(dismissSelect:) forControlEvents:UIControlEventTouchUpInside];
    [footer addSubview:okButton];
 } //end loadView

//======(samplesVC)==========================================
// Boilerplate code from stackoverflow
- (void)viewDidLoad {
    [super viewDidLoad];
    refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(refreshTable) forControlEvents:UIControlEventValueChanged];
    if (@available(iOS 10.0,*))
    {
        table.refreshControl = refreshControl;
    }
    else{
        [table addSubview:refreshControl];
    }
} //end viewDidLoad

//======(samplesVC)==========================================
// 4/28 for pull to refresh
-(void) refreshTable
{
    [refreshControl endRefreshing];
    [self getSampleFolder];
    [table reloadData];
}

//======(samplesVC)==========================================
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    //7/31 hide until we know about sample files
//    [sappDelegate purgeSamplesFolder]; //5/17 prevent files from piling up!
    cancelButton.hidden = TRUE;
    [playing removeAllObjects]; //5/12 make sure no playing leftovers!
    [self clearAllPlayRows]; //5/17
    [self getSampleFolder];
    [table reloadData];
    changed = FALSE; //7/13
    samplesPlaying = 0;
    [self resetTitle];
}

//======(controlsVC)==========================================
-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    _isUp = TRUE; //8/21
}


//======(samplesVC)==========================================
// 9/24
- (BOOL)prefersStatusBarHidden
{
    return YES;
}

//======(samplesVC)==========================================
-(void) resetTitle
{
    [titleLabel setText:@"Sample Manager"];
    [titleLabel setTextColor : [UIColor whiteColor]];
}

int tval = 320;
//======(samplesVC)==========================================
- (IBAction)testSelect:(id)sender
{
    [sfx setSynthGain :  255.0]; //9/7
    [sfx setSynthMono :    0];
    [sfx setSynthAttack:   0];
    [sfx setSynthDecay:    0];
    [sfx setSynthSustain:  0];
    [sfx setSynthSustainL: 0];
    [sfx setSynthRelease:  0];
    [sfx setSynthSampOffset:0];
    [sfx playNote : 64 : tval : SAMPLE_VOICE]; //Middle C
    NSLog(@" test %d",tval);
    tval++;
    if (tval > 340) tval = 320;
}

//======(samplesVC)==========================================
- (IBAction)dismissSelect:(id)sender
{
    [self dismissVC];
}   //end dismiss

//======(samplesVC)==========================================
// this is called from more than one place!
-(void) dismissVC
{
    [self clearAllPlayRows]; //5/12 make sure nothing left playing!
    //this starts up audio again and lets mainVC know if something was changed
    _isUp = FALSE; //8/21
    [self.delegate didDismissSamplesVC:changed];
    [self dismissViewControllerAnimated : YES completion:nil];
}

//======(samplesVC)==========================================
-(void) displayEmptyFolderAlert
{
    NSString *titleStr = @"No Samples...";
    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:
                                            titleStr];
    [tatString addAttribute : NSForegroundColorAttributeName value:[UIColor blackColor]
                       range:NSMakeRange(0, tatString.length)];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:30]
                      range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(titleStr,nil)
                                message:@"The User Samples folder is empty...\nTo add new Samples you can either\nrecord live oogieCam samples\n or import WAV files from Documents\nusing the Files App.\nNext, these samples here form the UserSamples SoundPack"
                                preferredStyle:UIAlertControllerStyleAlert];
    [alert setValue:tatString forKey:@"attributedTitle"];
    alert.view.tintColor = [UIColor blackColor]; //lightText, works in darkmode

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                    [self dismissVC]; //7/17
                                              }]];
    
//    if (sappDelegate.gotIPad) // 3/27 need popover for ipad!
//    {
//        UIPopoverPresentationController *popPresenter = [alert popoverPresentationController];
//        popPresenter.sourceView = self.view;
//        //Put it in Center... (NO ARROW)
//        popPresenter.sourceRect = CGRectMake( self.view.bounds.size.width/2,self.view.bounds.size.height/2 ,   0,   0);
//        popPresenter.permittedArrowDirections = 0;
//    }

    [self presentViewController:alert animated:YES completion:nil];

} //end displayEmptyFolderAlert


//======(samplesVC)==========================================
-(void) displayActionMenu : (int) row
{
    selectedRow = row;

    NSString *titleStr = fileNamesNoNumberSigns[row];
    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:
                                            titleStr];
    [tatString addAttribute : NSForegroundColorAttributeName value:[UIColor blackColor]
                       range:NSMakeRange(0, tatString.length)];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:30]
                      range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(titleStr,nil)
                                message:@"You can rename, delete or share samples here..."
                                preferredStyle:UIAlertControllerStyleActionSheet];
    [alert setValue:tatString forKey:@"attributedTitle"];
    
    
    alert.view.tintColor = [UIColor blackColor]; //lightText, works in darkmode
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Rename",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        [self clearAllPlayRows]; //4/5 stop all play on rename
        [self renameMenu : row];
        
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Delete NOW",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        [self clearAllPlayRows]; //4/5 stop all play on delete
        [self markSampleFileForDeletion: row];
        self->changed = TRUE; //7/13
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Play",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        NSString *sname = self->fileNamesNoNumberSigns[row];
        NSIndexPath *ip = [NSIndexPath indexPathForRow:row inSection:0];
        sampleCell *scell = [self->table cellForRowAtIndexPath:ip];
        NSLog(@" hide pb %d",row);
        [scell setPlayButtonHidden:TRUE]; //Hide cells play button!
        [self playUserSample:sname];
    }]];
    if (samplesPlaying > 0) //1/31/21 add stop option
    {
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Stop Play",nil)
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            [self->sfx  releaseAllNotes];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Share...",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
         [self clearSelection];
         [self shareit : row];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        [self->sfx  releaseAllNotes]; //7/10
                                                  [self clearSelection];
                                              }]];
//    if (sappDelegate.gotIPad) // 3/27 need popover for ipad!
//    {
//        UIPopoverPresentationController *popPresenter = [alert popoverPresentationController];
//        popPresenter.sourceView = self.view;
//        //Put it in Center... (NO ARROW)
//        popPresenter.sourceRect = CGRectMake( self.view.bounds.size.width/2,self.view.bounds.size.height/2 ,   0,   0);
//        popPresenter.permittedArrowDirections = 0;
//    }
    [self presentViewController:alert animated:NO completion:nil];

}

//======(samplesVC)==========================================
-(void) shareit : (int) row
{
     NSString *fname = fileNamesNoNumberSigns[row];
     NSString *fullFname = [docFolderFullPath stringByAppendingPathComponent:fname];
    NSMutableArray *shareItems = [[NSMutableArray alloc] init];
    [shareItems addObject:fullFname];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:shareItems applicationActivities:nil];

    activityVC.excludedActivityTypes = @[UIActivityTypePrint, UIActivityTypeCopyToPasteboard, UIActivityTypeAssignToContact, UIActivityTypeSaveToCameraRoll, UIActivityTypeAirDrop];
//    if (sappDelegate.gotIPad) // 3/27 need popover for ipad!
//    {
//        UIPopoverPresentationController *popPresenter = [activityVC popoverPresentationController];
//        popPresenter.sourceView = self.view;
//        //Put it in Center... (NO ARROW)
//        popPresenter.sourceRect = CGRectMake( self.view.bounds.size.width/2,self.view.bounds.size.height/2 ,   0,   0);
//        popPresenter.permittedArrowDirections = 0;
//    }
    [self presentViewController:activityVC animated:YES completion:nil];
    
}

//======(samplesVC)==========================================
// 6/23 needs bufLookups, passed from parent
-(void) playUserSample : (NSString *)fname
{
  //problem: need access to allpatches or at least sample buffer numbers!!
    
    //try to get sample number from patLookups
    NSNumber *lookup = @320; /// KLUBE TES [sappDelegate.allp getSampleNumberByNameWithSs:fname];
    lookup = _patLookups[fname];
    if (lookup == nil)
    {
        NSLog(@" no buffer found for %@",fname);
        return;
    }
    
    [titleLabel setText:fname];
    [titleLabel setTextColor : [UIColor yellowColor]];
    samplesPlaying++;
    // 10/17 use allpatches 1/28 use local allp
    NSLog(@" play %@ : %d ",fname,lookup.intValue);

    //NSLog(@" get lookup for %@ : %@",fname,lookup);
    if (lookup == nil || lookup.intValue == 0)
    {
        NSLog(@" ERROR: failure finding sample %@",fname);
        return;
    }
    if (sfx == nil)
    {
        NSLog(@" NIL SFX!!! get fresh");
        sfx = [soundFX sharedInstance];

    }
        

    [sfx setSynthGain :  255.0]; //9/7
    [sfx setSynthMono :    0];
    [sfx setSynthAttack:   0];
    [sfx setSynthDecay:    0];
    [sfx setSynthSustain:  0];
    [sfx setSynthSustainL: 0];
    [sfx setSynthRelease:  0];

    NSDictionary *d = [fileDict objectForKey:fname];
    NSNumber *fsecs = d[@"fseconds"];
    float fplaytime = fsecs.floatValue;
    int bufnum = lookup.intValue;
    int bsize = [sfx getBufferSize:bufnum ];
    double btime = (double)bsize * inv441 * 0.5;
    btime = (double)fplaytime; //4/29 compute properly for all sample rates!
    NSLog(@" playUserSample from buf %d, size %d time %f",bufnum,bsize,btime);
    [sfx playNote : 64 : bufnum : SAMPLE_VOICE]; //Middle C

    //pass row to timer, used for UI update
    NSNumber *nrow = [NSNumber numberWithInt:selectedRow];
    [playing addObject:nrow];
    //2/5 got rid of buftimer var
    [NSTimer scheduledTimerWithTimeInterval:btime target:self
                                                       selector:@selector(buftimerTick:) userInfo:nrow repeats:NO];

} //end playUserSample

//======(samplesVC)==========================================
// 1/28 called when a sample is done playing
- (void)buftimerTick:(NSTimer *)timer
{
    NSNumber *nn = [timer userInfo];
    NSUInteger nindex = [playing   indexOfObject:nn]; //find entry in playing table
    [playing removeObjectAtIndex:nindex];            // remove from playing array
    NSIndexPath *ip = [NSIndexPath indexPathForRow:nn.intValue inSection:0];
    sampleCell *scell = [table cellForRowAtIndexPath:ip];
    [scell setPlayButtonHidden:FALSE];  //OK show play button again
    samplesPlaying--;
    // Done playing all samples? clear title
    if (samplesPlaying == 0) [self resetTitle];
}

//======(samplesVC)==========================================
// 4/5 halt all playing rows, clean up UI
-(void) clearAllPlayRows
{
    // 5/17 brute force clear!
    for (int i=0;i<(int)fileNamesNoNumberSigns.count;i++)
    {
        NSIndexPath *ip = [NSIndexPath indexPathForRow:i inSection:0];
        sampleCell *scell = [table cellForRowAtIndexPath:ip];
        [scell setPlayButtonHidden:FALSE];  //OK show play button again
    }
//    for (NSNumber* nn in playing)
//    {
//        NSIndexPath *ip = [NSIndexPath indexPathForRow:nn.intValue inSection:0];
//        sampleCell *scell = [table cellForRowAtIndexPath:ip];
//        NSLog(@" show pb %d",nn.intValue);
//        [scell setPlayButtonHidden:FALSE];  //OK show play button again
//    }
    samplesPlaying = 0;
    [sfx  releaseAllNotes];
}

//======(samplesVC)==========================================
-(NSDate*) getCreationDateForFile : (NSString*) path : (NSString*) fileName
{
    NSFileManager* fm = [NSFileManager defaultManager];
    NSDictionary* attrs = [fm attributesOfItemAtPath:path error:nil];
    if (attrs != nil) {
        NSDate *date = (NSDate*)[attrs objectForKey: NSFileCreationDate];
        //NSNumber *fsize = (NSNumber*)[attrs objectForKey: NSFileSize];
        //NSLog(@"file %@ Date Created: %@ size %d", path,[date description],fsize.intValue);
        return date;
    }
    return [NSDate date]; //bail w/ current date
} //end getCreationDateForFile

//======(samplesVC)==========================================
-(NSNumber*) getSizeForFile : (NSString*) path : (NSString*) fileName
{
    NSFileManager* fm = [NSFileManager defaultManager];
    NSDictionary* attrs = [fm attributesOfItemAtPath:path error:nil];
    if (attrs != nil) {
        NSNumber *fsize = (NSNumber*)[attrs objectForKey: NSFileSize];
        return fsize;
    }
    return @0; //return 0 on fail
} //end getSizeForFile


//======(samplesVC)==========================================
// 4/27 for holding date/size/header info
-(void) addStatsToDict : (NSString *)fname : (NSDate *)date : (NSNumber*) size :
            (NSNumber*) chans : (NSNumber*) fseconds : (NSNumber*) samplerate
{
    if (fname == nil) return; //5/15 add nil check
    NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:
                       date,      @"date",
                       size,      @"size",
                       chans,     @"chans",
                       fseconds,  @"fseconds",
                       samplerate,@"samplerate",
                       nil];
    //NSLog(@" add stats %@ for name %@",d,fname);
   [fileDict setObject:d forKey:fname]; //destructively overwrite!
} //end addStatsToDict

//======(samplesVC)==========================================
-(void) getFileStatsToDict
{
    // loop over all files,
    for (NSString *s in rawFileNames)
    {
        if (fileDict[s] == nil) //Dont dupe it!
        {
            // pack up file info ...
            NSString *fullPath = [NSString stringWithFormat: @"%@/%@",docFolderFullPath,s];
            NSDate *d = [self getCreationDateForFile : fullPath : s];
            NSNumber *nn = [self getSizeForFile:fullPath :s];
            //Call SFX and get audio statistics from file header...
            NSDictionary *ddd = [sfx getSampleHeader:fullPath];
            NSNumber *chans      = @0;
            NSNumber *fseconds   = @0;
            NSNumber *samplerate = @0;
            if (ddd != nil)
            {
                chans = ddd[@"channels"];
                NSNumber *packets    = ddd[@"packets"];
                samplerate = ddd[@"samplerate"];
                int ipac   = packets.intValue;
                int irat   = samplerate.intValue;
                if (irat > 0)
                {
                    float fsecs = (float)ipac / (float)irat;
                    fseconds = [NSNumber numberWithFloat:fsecs];
                }
            }
            [self addStatsToDict:s :d :nn : chans : fseconds : samplerate];
        }
    }
} //end getFileStatsToDict

//======(samplesVC)==========================================
// 7/31 also hides the Cancel button
-(void) getSampleFolder
{
    NSArray  *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    docFolderFullPath = [documentsDirectory stringByAppendingPathComponent:@"samples"];
    rawFileNames = [[NSFileManager defaultManager]
                                    contentsOfDirectoryAtPath:docFolderFullPath error:Nil];
    //Need to alert user on empty folder!
    if (rawFileNames.count == 0)
    {
        cancelButton.hidden = TRUE;
        [self displayEmptyFolderAlert];
    }
    else //ok to filter?
    {
        NSMutableArray *filteredNames = [[NSMutableArray alloc] init];
        // 4/29 filter out non WAV  /  CAF files
        for (NSString *fname in rawFileNames)
        {
            NSString *flower = [fname lowercaseString];
            if (( [flower containsString:@".wav"] ||
                  [flower containsString:@".caf"] ) &&
                  ![fname containsString : @"#"] //previously deleted file...
            )
                [filteredNames addObject:fname];
            //NSNumber *lookup = [sappDelegate.allp getSampleNumberByNameWithSs:fname];
            //NSLog(@"   lookup fname %@ buf %@",fname,lookup);
        }
        [self getFileStatsToDict];
        cancelButton.hidden = FALSE;
        // 1/29/21
        fileNamesNoNumberSigns = [filteredNames sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        //NSLog(@" gotfilenames %@",fileNamesNoNumberSigns);
    } //end else
} //end getSampleFolder

//======(samplesVC)==========================================
// 7/14
-(void) clearSelection
{
    [table deselectRowAtIndexPath:selectedIndexPath animated:TRUE]; //7/14
}

//======(samplesVC)==========================================
-(void) deleteSelectedFile : (int) row
{
    NSString *fname = fileNamesNoNumberSigns[row];
    NSError *error;
    NSString *fullName = [docFolderFullPath stringByAppendingPathComponent:fname];
    if ([[NSFileManager defaultManager] fileExistsAtPath:fullName]) {
        [[NSFileManager defaultManager] removeItemAtPath:fullName error:&error];
        if (error != nil)
            NSLog(@" ERROR deleting file %@",fullName);
        else{
            // 4/27 delete stats too
            [fileDict removeObjectForKey:fname];
            [self getSampleFolder];
            [table reloadData];
        }
    }
    
} //end deleteSelectedFile

//======(samplesVC)==========================================
-(void) renameMenu : (int) row
{
    NSString *dtitle = [NSString stringWithFormat:@"Rename File..."];
    UIAlertController * alert=   [UIAlertController alertControllerWithTitle:dtitle
                                                                     message:@"Enter new name..."
                                                              preferredStyle:UIAlertControllerStyleAlert];
    //Text String for search..., note keyboard type can be set!
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder     = @"new filename...";
        textField.textColor       = [UIColor blackColor];
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.borderStyle     = UITextBorderStyleRoundedRect;
    }];
    // need a handle to this action for preferredAction below...
    UIAlertAction *renameAction =  [UIAlertAction actionWithTitle:@"Rename" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSArray * textfields = alert.textFields;
        UITextField * firstField = textfields[0];
        NSString *newName = firstField.text;
        // 5/18 strip punctuation and illegal chars from name!!!
        NSString *punct = @"`~!@#$%^&*()=+[]{}|;:,.<>/?'\"\\";
        //Crude and ugly: get rid of punctuation in filename
        for (int i=0;i<punct.length;i++)
        {
            NSString *lilstr = [punct substringWithRange:NSMakeRange(i, 1)];
            newName = [newName   stringByReplacingOccurrencesOfString:lilstr withString:@""]; //Get rid of
        }
        if (newName != nil &&  newName.length > 2) //at least 3 char for search 5/15 nil check
        {
//            NSString *oldName = self->fileNamesNoNumberSigns[row];
//            //4/27 update stats too
//            NSDictionary *fileInfo = self->fileDict[oldName];
//            NSNumber *lookup = [sappDelegate.allp getSampleNumberByNameWithSs:oldName];
//
//            if ([self renameSampleFile:oldName:newName])
//            {
//                [self->fileDict removeObjectForKey:oldName];  //5/15 remove old name HERE not above here!
//                [self getSampleFolder];
//                //make sure allpatches knows about namechange//  4/20 fix warnings inside closures, added self-> etc as needed
//                newName = [newName stringByAppendingString : @".caf"]; //add suffix as needed
//                [self->fileDict setObject:fileInfo forKey:newName];
//                [sappDelegate.allp linkBufferToPatchWithNn:lookup ss:newName];
//                [sappDelegate.allp unlinkOldBufferByNameWithSs:oldName];
//                [self->table reloadData];
//                self->changed = TRUE; //7/13
//            }
//            else
//            {
//                [self errorMessage:@"File Already Exists" :@"Please pick a new filename or delete the old file first"];
//                //NSLog(@"Error renaming file");
//            }
//            [self clearSelection];
        }
     }];
     [alert addAction: renameAction]; //7/17 note rename action now dismisses alert!
     [alert addAction: [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
         [self clearSelection];

     }]];

    alert.preferredAction = renameAction;
    
    [self presentViewController:alert animated:YES completion:nil];
} //end renameMenu

//======(samplesVC)==========================================
-(BOOL) renameSampleFile : (NSString *)oldName : (NSString *) newName
{
    //7/20 make sure we have an audio suffix!
    NSString *finalNewName = newName;
    if (![newName containsString: @".caf"])
    {
        finalNewName = [newName stringByAppendingString : @".caf"]; //add suffix as needed
    }
    if ([finalNewName isEqualToString:oldName]) return FALSE; //1/29 ERROR on dupe
    NSString *foldName = [docFolderFullPath stringByAppendingPathComponent:oldName];
    NSString *fnewName = [docFolderFullPath stringByAppendingPathComponent:finalNewName];
    NSError  * err = NULL;
    NSFileManager * fm = [[NSFileManager alloc] init];
    return( [fm moveItemAtPath:foldName toPath:fnewName error:&err] );
}

//======(samplesVC)==========================================
//NOTE: this has a flaw, in that it cannot destructively RENAME
//  a file, so if oogie0001 was deleted, it becomes #oogie0001.
//  now if a new sample is recorded as oogie0001 we have a problem
//  the next time use tries to delete!
-(void) markSampleFileForDeletion : (int)row
{
    NSString *fname = fileNamesNoNumberSigns[row];
    NSString *dfname = [NSString stringWithFormat:@"#%@",fname];
    [self renameSampleFile:fname :dfname];
    [self getSampleFolder];
    [table reloadData];
} //end markSampleFileForDeletion


//======(samplesVC)==========================================
- (IBAction)playSelect:(id)sender
{
    selectedRow = [self getCellRow:sender];
    sampleCell *clickedCell = (sampleCell *)[[sender superview] superview];
    [clickedCell setPlayButtonHidden:TRUE]; //Hide cells play button!
    NSString *sname = fileNamesNoNumberSigns[selectedRow];
    [self playUserSample:sname];
}

//======(samplesVC)==========================================
-(int) getCellRow : (id) sender
{
    return (int)[self getCellIndexPath:sender].row;
}

//======(samplesVC)==========================================
// Helps calculate which row a cell is on...
-(NSIndexPath *) getCellIndexPath : (id) sender
{
    UITableViewCell *clickedCell = (UITableViewCell *)[[sender superview] superview];
    NSIndexPath *clickedButtonPath = [table indexPathForCell:clickedCell];
    return clickedButtonPath;
}

//======(samplesVC)==========================================
-(NSString*) getSizeText : (NSNumber*)nn
{
    float size = (float)(nn.intValue) / 1024.0;
    NSString *result = [NSString stringWithFormat:@"%3.1fkb",size];
    if (size >= 1024.0)
        result = [NSString stringWithFormat:@"%3.1fMb",size/1024.0];
    return result;
}

//======(samplesVC)==========================================
// may return nil...
-(NSDictionary*) getFileInfo : (NSString*)fname
{
    NSDictionary *d = [fileDict objectForKey:fname];
    return d;
}


//=========<UITableViewDelegate>===========================================
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    int row = (int)indexPath.row;
    sampleCell *cell = (sampleCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
    {
        cell = [[sampleCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    // 5/15 change selected bkgd color, first make sure component exists
    if (cell.selectedBackgroundView == nil)  cell.selectedBackgroundView = [[UIView alloc] init];
    cell.selectedBackgroundView.backgroundColor = [UIColor colorWithRed:0.4 green:0 blue:0.6 alpha:1];
    cell.backgroundColor   = [UIColor blackColor];
    cell.title.text        = fileNamesNoNumberSigns[row];
    cell.title.textColor   = [UIColor yellowColor];
    // unpack file info , indexed by fname
    NSDictionary *fileinfo = [self getFileInfo:fileNamesNoNumberSigns[row]];
    NSDate *ddd            = fileinfo[@"date"];
    cell.dateLabel.text    = [dformatter stringFromDate:ddd];
    NSNumber *nn           = fileinfo[@"size"];;

    cell.sizeLabel.text = [self getSizeText:nn];
// Debug, show buffer number
//    NSString *fname = fileNamesNoNumberSigns[row];
//    NSNumber *lookup = [sappDelegate.allp getSampleNumberByNameWithSs:fname];
//    cell.sizeLabel.text = [NSString stringWithFormat:@"buf:%d",lookup.intValue];

    NSNumber *chans = fileinfo[@"chans"];
    NSNumber *fsecs = fileinfo[@"fseconds"];
    NSNumber *srate = fileinfo[@"samplerate"];

    int khz = srate.intValue / 1000;
    NSString *chanString = @"stereo";
    if (chans.intValue == 1) chanString = @"mono";
    cell.headerLabel.text = [NSString stringWithFormat:
                             @"%4.1fsec %@ %dkhz",
                             fsecs.floatValue,chanString,khz];
    
    [cell.playButton     addTarget:self action:@selector(playSelect:)      forControlEvents:UIControlEventTouchUpInside];

    return cell;
 } //end cellForRowAtIndexPath


//=========<UITableViewDelegate>===========================================
//  5/17 handle cell going out of focus, clobber any animations!
- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    sampleCell *scell = (sampleCell *)cell;
    [scell setPlayButtonHidden : FALSE]; // show play button; hide animation
}

//=========<UITableViewDelegate>===========================================
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}

//=========<UITableViewDelegate>===========================================
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

//=========<UITableViewDelegate>===========================================
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return fileNamesNoNumberSigns.count;
}

//=========<UITableViewDelegate>===========================================
// Handles any click on bottom table... just goes to actVC
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    int row = (int)indexPath.row;
//    NSDictionary *fileinfo = [self getFileInfo:fileNamesNoNumberSigns[row]];
//    NSNumber *srate = fileinfo[@"samplerate"];
//    int srateInt = srate.intValue;
//    if (srateInt != 44100 && srateInt != 11025 && srateInt != 16000)
//    {
//        [self errorMessage:@"Unsupported file" :@"oogieCam can't load this file.\nMake sure your audio files are all 44 or 11 khz and have 16-bit audio"];
//    }
//    else{
        [self displayActionMenu : row];
        selectedIndexPath = indexPath;
//    }
    
}

// 8/12 for now just dismiss this panel!
- (void)demoNotification:(NSNotification *)notification
{
     [self dismissViewControllerAnimated : YES completion:nil];
}


//====(OOGIECAM MainVC)============================================
-(void) errorMessage : (NSString *)title : (NSString *)message
{
    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:
                                            title];
    [tatString addAttribute : NSForegroundColorAttributeName value:[UIColor blackColor]
                       range:NSMakeRange(0, tatString.length)];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:30]
                      range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(title,nil)
                                message:message
                                preferredStyle:UIAlertControllerStyleAlert];
    [alert setValue:tatString forKey:@"attributedTitle"];
    alert.view.tintColor = [UIColor blackColor]; //lightText, works in darkmode

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                              }]];
    [self presentViewController:alert animated:YES completion:nil];

} //end errorMessage


@end
