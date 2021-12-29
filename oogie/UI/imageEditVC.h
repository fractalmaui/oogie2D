//
//   _                            _____    _ _ _ __     ______
//  (_)_ __ ___   __ _  __ _  ___| ____|__| (_) |\ \   / / ___|
//  | | '_ ` _ \ / _` |/ _` |/ _ \  _| / _` | | __\ \ / / |
//  | | | | | | | (_| | (_| |  __/ |__| (_| | | |_ \ V /| |___
//  |_|_| |_| |_|\__,_|\__, |\___|_____\__,_|_|\__| \_/  \____|
//                     |___/
//
//  imageEditVC.h
//  oogie2D / AR
//
//  Created by dave scruton on 11/13/21.
//  Copyright © 2021 fractallonomy. All rights reserved.
//
//  simple image editor, for changing rgb channels / brightness/contrast/hue

#import <UIKit/UIKit.h>

@protocol imageEditVCDelegate;


@interface imageEditVC : UIViewController
{
    CIImage* coreImage;
    UIImage *processedImage;
    float vBrightness ;
    float vContrast ;
    float vSaturation ;
    
    float vRed,vGreen,vBlue;
    BOOL flipRG,flipBG,flipRB;
    unsigned char *imageData;  //11/16 mallocs!
    unsigned char *targetData;
    
    BOOL loaded;
    BOOL changed;
    BOOL processing;
}

@property (nonatomic, unsafe_unretained) id <imageEditVCDelegate> delegate;  

@property (weak, nonatomic) IBOutlet UIImageView *workImage;

@property (weak, nonatomic) IBOutlet UISlider *brightnessSlider;
@property (weak, nonatomic) IBOutlet UISlider *contrastSlider;
@property (weak, nonatomic) IBOutlet UISlider *saturationSlider;

@property (weak, nonatomic) IBOutlet UISlider *redSlider;
@property (weak, nonatomic) IBOutlet UISlider *greenSlider;
@property (weak, nonatomic) IBOutlet UISlider *blueSlider;
@property (weak, nonatomic) IBOutlet UIButton *resetButton;

@property (weak, nonatomic) IBOutlet UIButton *okButton;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;

@property (weak, nonatomic) IBOutlet UISwitch *rgSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *bgSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *rbSwitch;

@property (strong, nonatomic) UIImage *image2edit;
@property (strong, nonatomic) UIImage *editedImage;

@property(nonatomic,assign)   BOOL isUp;


- (IBAction)sliderChanged:(id)sender;
- (IBAction)testSelect:(id)sender;


@end

@protocol imageEditVCDelegate <NSObject>
@optional
-(void) didEditImage : (UIImage*) i;
@end

