//                             _         __     ______
//   ___  __ _ _ __ ___  _ __ | | ___  __\ \   / / ___|
//  / __|/ _` | '_ ` _ \| '_ \| |/ _ \/ __\ \ / / |
//  \__ \ (_| | | | | | | |_) | |  __/\__ \\ V /| |___
//  |___/\__,_|_| |_| |_| .__/|_|\___||___/ \_/  \____|
//                      |_|
//
//  samplesVC.h
//  oogieCam
//
//  Created by Dave Scruton on 6/22/20.
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "sampleCell.h"
#import "soundFX.h"
//#import "oogie2D-Swift.h" //10/23 why do we need this?

@protocol samplesVCDelegate;

@interface samplesVC : UIViewController <UITableViewDelegate,
                            UITableViewDataSource,UITextFieldDelegate>
{
    int viewWid,viewHit,buttonWid,buttonHit;
    UILabel *titleLabel;
    UITableView *table;
    UILabel *bottomInfoLabel;
    UIButton *importButton;
    UIButton *okButton;
    UIButton *cancelButton;
    UIView *header,*footer;
//    AllPatches *allp;
    NSArray *rawFileNames; //4/2/21
    NSMutableDictionary *fileDict;
    NSArray *fileNamesNoNumberSigns; //4/2/21
    NSString *docFolderFullPath;
    NSIndexPath* selectedIndexPath;
    BOOL changed; //7/13
    NSDateFormatter * dformatter;
    int selectedRow;
    NSNumber *selectedBufferNum;
    int samplesPlaying;
    double inv441;
    NSMutableArray *playing; //array of nsnumbers
    UIRefreshControl *refreshControl; //4/28 for pull to refresh
    soundFX *sfx;
}

//10/17 use allPatches @property (nonatomic, weak) NSMutableDictionary *bufLookups;
@property (nonatomic, strong) NSDictionary *patLookups;

@property (nonatomic, unsafe_unretained) id <samplesVCDelegate> delegate; // receiver of completion messages
@property(nonatomic,assign)   BOOL isUp; //8/21

-(void) initAllVars;


@end


@protocol samplesVCDelegate <NSObject>
@optional
-(void) didDismissSamplesVC: (BOOL)changed;
@end


