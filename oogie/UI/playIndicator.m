//         _             ___           _ _           _
//   _ __ | | __ _ _   _|_ _|_ __   __| (_) ___ __ _| |_ ___  _ __
//  | '_ \| |/ _` | | | || || '_ \ / _` | |/ __/ _` | __/ _ \| '__|
//  | |_) | | (_| | |_| || || | | | (_| | | (_| (_| | || (_) | |
//  | .__/|_|\__,_|\__, |___|_| |_|\__,_|_|\___\__,_|\__\___/|_|
//  |_|            |___/
//
//  playIndicator.m
//  playIndicator
//
//  Created by Dave Scruton on 1/31/21
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//
//  adopted from spinnerView, just plays canned frames
//  4/26 cleanup
//  5/19 set to frame image immediately in start
#import "playIndicator.h"

@implementation playIndicator

//==========playIndicator======================================================
- (void)baseInit
{
    _message = @"";
    animTick = 0;
    self.backgroundColor = [UIColor clearColor];
    self.frame = cframe;
    _borderColor  = [UIColor colorWithRed:1 green:1 blue:1 alpha:1];
    _borderWidth  = 0;
    
    //where our animation lives... 4 lil frames
    frames = [[NSMutableArray alloc] init];
    for (int i=0;i<4;i++)
    {
        NSString *fname = [NSString stringWithFormat:@"spkr%d.png",i];
        UIImage *ii = [UIImage imageNamed:fname];
        if (ii != nil) [frames addObject:ii]; //10/23 fixit for bad icons
    }
        
    int xi,yi,xs,ys;
    xs = ys = hvsize; //logoSize;
    xi = 0; //(hvsize - logoSize)/2;
    yi = 0; //(hvsize - logoSize)/2;
    NSString *logoName = @"spkr0"; // @"4colorLogo"
    spView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:logoName]];
    [spView setFrame:CGRectMake(xi,yi, xs, ys)];
    [self addSubview : spView];
    xs = hvsize;
    ys = 40;
    yi = (xs - ys)/2;
    spLabel =  [[UILabel alloc] initWithFrame:  CGRectMake(0,yi, xs,ys)];
    spLabel.text = _message;
    [spLabel setFont: [UIFont systemFontOfSize:ys*0.7 weight:UIFontWeightBold]];
    spLabel.textAlignment   = NSTextAlignmentCenter ;
    spLabel.textColor       = [UIColor whiteColor];
    spLabel.backgroundColor = [UIColor blackColor];
    spLabel.alpha = 0.8;
    spLabel.clipsToBounds   = TRUE;
    spLabel.layer.cornerRadius = 10;
    spLabel.hidden = TRUE;  //1/31 no label for now
     
    [self  addSubview:spLabel];
    self.hidden = TRUE;
    spinning = FALSE;
}

//==========spinnerView=========================================================================
// Frame is assumed to be FULL SCREEN
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        hvsize = frame.size.width; //256; can blow up to any size
        logoSize  = hvsize; //128;
        //cframe = CGRectMake((w-hvsize)/2,(h-hvsize)/2,hvsize,hvsize);
        cframe = frame;
        [self baseInit];
    }
    return self;
}

//==========spinnerView=========================================================================
- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder])) {
        [self baseInit];
    }
    return self;
}



//==========spinnerView=========================================================================
- (void)drawRect:(CGRect)rect
{
    CGContextRef contextRef = UIGraphicsGetCurrentContext();
    
    // Set the border width
    CGContextSetLineWidth(contextRef,_borderWidth);
    
    // Set the border color...
    CGFloat red, green, blue, alpha;
    [_borderColor getRed:&red green:&green blue:&blue alpha:&alpha];
    CGContextSetRGBStrokeColor(contextRef, red,green,blue,alpha);
    
    // Draw the border along the view edge
    CGContextStrokeRect(contextRef, rect);
} //end drawRect


//==========spinnerView=========================================================================
-(void) start : (NSString *) ms;
{
    //NSLog(@" start play indicator %@",self);
     frameNum = 0;
    _message     = ms;
    spLabel.text = _message;
    UIImage *ii = frames[0]; // 5/19 get frame 0 NOW
    [spView setImage: ii];  //  5/19

    spView.transform  = CGAffineTransformMakeRotation(0); //Reset rotations
    //Trigger indicator animation..
    animTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(animtimerTick:) userInfo:nil repeats:YES];
    animTick = 0;
    spinning = TRUE;
} //end start

//==========spinnerView=========================================================================
-(void) stop
{
    //NSLog(@"    STOP play indicator %@",self);
    [animTimer invalidate]; //DHS 2/19/18 Stop load animation
    self.hidden  = TRUE; //DHS 2/19/18
    spinning     = FALSE;
} //end stop

//==========spinnerView=========================================================================
// Cutsie speaker animation...
- (void)animtimerTick:(NSTimer *)ltimer
{
    if (animTick == 1 && spinning)
    {
       // NSLog(@" show spv");
        self.hidden  = FALSE; //1/9/20 show only after 2nd tick
    }
    animTick++;
    frameNum = (frameNum+1)%4;
    UIImage *ii = frames[frameNum];
    //NSLog(@" frame %d",frameNum);
    [spView setImage: ii];
} //end animtimerTick



@end
