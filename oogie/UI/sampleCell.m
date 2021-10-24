//                             _       ____     _ _
//   ___  __ _ _ __ ___  _ __ | | ___ / ___|___| | |
//  / __|/ _` | '_ ` _ \| '_ \| |/ _ \ |   / _ \ | |
//  \__ \ (_| | | | | | | |_) | |  __/ |__|  __/ | |
//  |___/\__,_|_| |_| |_| .__/|_|\___|\____\___|_|_|
//                      |_|
//  Created by Dave Scruton on 8/27/20
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//
// 9/11 add creation dates to sampleCell
// 4/26 add small margin right of play button/indicator
// 4/30 debug, remove redundant start call at init
#import "sampleCell.h"
@implementation sampleCell


//=====(sampleCell)=============================================
// Yup we create everything by hand...
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        UIScreen *sc = [UIScreen mainScreen];
        CGRect rt    = sc.bounds;
        CGSize csz   = rt.size;
        viewWid      = (int)csz.width;
        viewHit      = (int)csz.height;
        cellHit      = 60;
        int xymargin = 5;
        int xs,ys,xi,yi;
        //Each cell has 5 items: Title/Price/Blurb/Swatch/Buy Button

        xi = xymargin; //4/27 no icon here! scootch to LH side
        yi = xymargin;
        xs = viewWid/2; //4/26  - 10;
        ys = 25;
        _title = [[UILabel alloc] initWithFrame:CGRectMake(xi,yi,xs,ys)];
        [_title setFont:[UIFont fontWithName:@"AvenirNext-Bold" size:(int)17]];
        //_title.backgroundColor = [UIColor blueColor];
        _title.textColor = [UIColor whiteColor];
        [self.contentView addSubview:_title];

        // 4/27 add info label
        xs = viewWid * 0.35;
        xi = viewWid - xs - 70 - xymargin; // 5/19 account for RH buttonxs;
        _headerLabel = [[UILabel alloc] initWithFrame:CGRectMake(xi,yi,xs,ys)];
        [_headerLabel setFont:[UIFont fontWithName:@"AvenirNext-Bold" size:(int)12]];
        _headerLabel.textColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.6 alpha:1];
        _headerLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_headerLabel];

        xi = 5; //4/27 no icon here! scootch to LH side
        yi+=ys * 0.8;
        xs = viewWid/2; //4/26  - 10;
        _dateLabel = [[UILabel alloc] initWithFrame:CGRectMake(xi,yi,xs,ys)];
        [_dateLabel setFont:[UIFont fontWithName:@"AvenirNext-Bold" size:(int)12]];
        _dateLabel.textColor = [UIColor colorWithRed:0.4 green:0.5 blue:1.0 alpha:1];
        [self.contentView addSubview:_dateLabel];
//        xi+=xs;
        xs = viewWid * 0.35;
        xi = viewWid - xs - 70 - xymargin; // 5/19 account for RH buttonxs;
        _sizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(xi,yi,xs,ys)];
        [_sizeLabel setFont:[UIFont fontWithName:@"AvenirNext-Bold" size:(int)12]];
        _sizeLabel.textColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.6 alpha:1];
        _sizeLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_sizeLabel];

        xs = ys = cellHit; //40;  //5/19 try full cell hite for button/icon
//        ys = 40;
        xi = viewWid - xs - 10 ; //4/26 add small margin
        yi = 0;
        pli = [[playIndicator alloc] initWithFrame:CGRectMake(xi,yi, xs,ys)];
        [self.contentView addSubview:pli];
        pli.hidden = TRUE;
        
        _playButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_playButton setImage:[UIImage imageNamed:@"arrowRight"] forState:UIControlStateNormal];
        [_playButton setFrame:CGRectMake(xi,yi, xs,ys)];
        [self.contentView addSubview:_playButton];
    }
    
    return self;
} //end init...


//=====(sampleCell)=============================================
-(void) setPlayButtonHidden : (BOOL) hidden
{
    _playButton.hidden = hidden;
    hidden ? [pli start:@"gogo"] : [pli stop];    
    pli.hidden = !hidden;
}


@end
