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
//  https://sodocumentation.net/ios/topic/1409/uiimage
//  simple image editor, for changing rgb channels / brightness/contrast/hue
//  11/16/21  fix memory leak in processChannels, flipChannels,getImageFromData
//  12/16 change brightness default
//  12/21 add reset

#import "imageEditVC.h"

@interface imageEditVC ()

@end

@implementation imageEditVC

//----(imageEditVC)------------------------------------------------------------
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    coreImage = [[CIImage alloc] init];
    int xmargin = 20;
    float borderWid = 5.0f;
    UIColor *borderColor = [UIColor whiteColor];
    
    _resetButton.layer.cornerRadius = xmargin;
    _resetButton.clipsToBounds      = TRUE;
    _resetButton.layer.borderWidth  = borderWid;
    _resetButton.layer.borderColor  = [UIColor redColor].CGColor;

    _cancelButton.layer.cornerRadius = xmargin;
    _cancelButton.clipsToBounds      = TRUE;
    _cancelButton.layer.borderWidth  = borderWid;
    _cancelButton.layer.borderColor  = borderColor.CGColor;

    _okButton.layer.cornerRadius = xmargin;
    _okButton.clipsToBounds      = TRUE;
    _okButton.layer.borderWidth  = borderWid;
    _okButton.layer.borderColor  = borderColor.CGColor;
}

//----(imageEditVC)------------------------------------------------------------
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self clearSettings];
    changed     = FALSE;
    [self allocateBuffersForImage : _image2edit];

    [self configureControls];
}

//----(imageEditVC)------------------------------------------------------------
//12/21 clear edit vars
-(void) clearSettings
{
    vBrightness = 0.0;   //12/16 brightness range is -1.0 ... 1.0
    vContrast   = 1.0;   //      contrast is          0.0 ... 1.0   or 2?
    vSaturation = 1.0;   //      saturation           0.0 ... 1.0
    vRed = vGreen = vBlue = 1.0;

}
 
//----(imageEditVC)------------------------------------------------------------
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//----(imageEditVC)------------------------------------------------------------
-(void) configureControls
{
    _brightnessSlider.value = 0.5;
    _contrastSlider.value   = 0.5;
    _saturationSlider.value = 1.0;
    _redSlider.value        = 1.0;
    _greenSlider.value      = 1.0;
    _blueSlider.value       = 1.0;
    [_rgSwitch setOn:FALSE];
    [_bgSwitch setOn:FALSE];
    [_rbSwitch setOn:FALSE];
    _workImage.image = _image2edit; //start w/ input
}

//----(imageEditVC)------------------------------------------------------------
// 12/21 new
- (IBAction)resetSelect:(id)sender {
    [self clearSettings];
    [self configureControls];
    [self processImageAndUpdate];
}

//----(imageEditVC)------------------------------------------------------------
- (IBAction)okSelect:(id)sender {
    if (changed) [self.delegate didEditImage : _editedImage];  //12/16
    [self dismissVC];
}

//----(imageEditVC)------------------------------------------------------------
- (IBAction)cancelSelect:(id)sender {
    [self dismissVC];
}

//----(imageEditVC)------------------------------------------------------------
-(void) dismissVC
{
    //this starts up audio again and lets mainVC know if something was changed
    [self freeImageBuffers]; //11/16
    _isUp = FALSE; //8/21
    [self dismissViewControllerAnimated : YES completion:nil];
}


//----(imageEditVC)------------------------------------------------------------
- (IBAction)sliderChanged:(id)sender {
    
    UISlider *s = (UISlider*)sender;
    int tag = (int)s.tag;
    switch(tag)
    {
        case 1000:  vBrightness = -1.0 + 2.0*s.value;
            break;
        case 1001:  vContrast = 2.0 * s.value;
            break;
        case 1002:  vSaturation = 2.0 * s.value;
            break;
        case 1003:  vRed = s.value;
            break;
        case 1004:  vGreen = s.value;
            break;
        case 1005:  vBlue = s.value;
            break;
    }
    [self processImageAndUpdate];
    changed     = TRUE;

} //end sliderChanged

//----(imageEditVC)------------------------------------------------------------
- (IBAction)testSelect:(id)sender {
    
  //  UIImage *image = [_image2edit a
                      
    //                  levels:45 mid:0.95 white:238];
    NSLog(@" duh");
    //[self getProcessedImageBkgd];
}


//----(imageEditVC)------------------------------------------------------------
- (IBAction)rgChanged:(id)sender {
    UISwitch *sw = (UISwitch*)sender;
    flipRG = sw.on;
    if (flipRG) //turn others off
    {
        [_rbSwitch setOn : FALSE]; flipRB = FALSE;
        [_bgSwitch setOn : FALSE]; flipBG = FALSE;
    }
    [self processImageAndUpdate];
    changed     = TRUE;
}

//----(imageEditVC)------------------------------------------------------------
- (IBAction)bgChanged:(id)sender {
    UISwitch *sw = (UISwitch*)sender;
    flipBG = sw.on;
    if (flipBG) //turn others off
    {
        [_rgSwitch setOn : FALSE]; flipRG = FALSE;
        [_rbSwitch setOn : FALSE]; flipRB = FALSE;
    }
    [self processImageAndUpdate];
    changed     = TRUE;
}

//----(imageEditVC)------------------------------------------------------------
- (IBAction)rbChanged:(id)sender {
    UISwitch *sw = (UISwitch*)sender;
    flipRB = sw.on;
    if (flipRB) //turn others off
    {
        [_rgSwitch setOn : FALSE]; flipRG = FALSE;
        [_bgSwitch setOn : FALSE]; flipBG = FALSE;
    }
    [self processImageAndUpdate];
    changed     = TRUE;
}


//----(imageEditVC)------------------------------------------------------------
-(void) processImageAndUpdate
{
    if (processing) return; //no double calls
    processing = TRUE;
    UIImage *tempImage = [self changeBrightnessContrastSaturation: _image2edit];
    tempImage = [self processChannels:tempImage:vRed:vGreen:vBlue];
    tempImage = [self flipChannels:tempImage :flipRG :flipBG :flipRB];
    _editedImage = tempImage;
    self->_workImage.image = tempImage;
    processing = FALSE;
} //end processImageAndUpdate


//----(imageEditVC)------------------------------------------------------------
// Does it matter in which order the filters are applied?
-(UIImage*) changeBrightnessContrastSaturation : (UIImage*)inputImage
{
    coreImage = [coreImage initWithImage:inputImage];
    float cont_intensity  = self->vContrast; //was  1.1f;
    float sat_intensity   = self->vSaturation; //was 1.15f;
    float brit_intensity  = self->vBrightness;
    NSNumber *workNumBrit = [NSNumber numberWithFloat:brit_intensity];
    NSNumber *workNumCont = [NSNumber numberWithFloat:cont_intensity];
    NSNumber *workNumSat  = [NSNumber numberWithFloat:sat_intensity];
    CIFilter *filterCont  = [CIFilter filterWithName:@"CIColorControls"
                                       keysAndValues: kCIInputImageKey, self->coreImage,
                             @"inputSaturation", workNumSat,
                             @"inputContrast", workNumCont,
                             @"inputBrightness", workNumBrit,
                             nil];
    CIImage *workCoreImage = [filterCont outputImage];
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgimage = [context createCGImage:workCoreImage fromRect:[workCoreImage extent] format:kCIFormatRGBA8 colorSpace:CGColorSpaceCreateDeviceRGB()];
    UIImage *result = [UIImage imageWithCGImage:cgimage scale:0 orientation:[self->_image2edit imageOrientation]];
    CGImageRelease(cgimage);  //1/1/20 warning about CGColorSpaceRef memory leak??
    return result;
} //end changeBrightnessContrastSaturation


//----(imageEditVC)------------------------------------------------------------
- (UIImage *)gradientImageWithBounds:(CGRect)bounds colors:(NSArray *)colors {
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    gradientLayer.frame = bounds;
    gradientLayer.colors = colors;
    
    UIGraphicsBeginImageContext(gradientLayer.bounds.size);
    [gradientLayer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

//----(imageEditVC)------------------------------------------------------------
-(void) allocateBuffersForImage : (UIImage*) inputImage
{
    int width  = inputImage.size.width;
    int height = inputImage.size.height;
    int bsize  = height * width * 4;
    imageData  = (unsigned char *)malloc( bsize );
    targetData = (unsigned char *)malloc( bsize );
}

//----(imageEditVC)------------------------------------------------------------
-(void) freeImageBuffers
{
    free(targetData);
    free(imageData);
    targetData = nil;
    imageData  = nil;
}

//----(imageEditVC)------------------------------------------------------------
//Processes color channels, returns image as a result....
-(UIImage*) processChannels : (UIImage*) inputImage : (float)rlevel : (float)glevel : (float)blevel
{
    int width  = inputImage.size.width;
    int height = inputImage.size.height;
    int bprow  = 4*width;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef tcontext = CGBitmapContextCreate( imageData, width, height, 8, bprow, colorSpace,
                                                  kCGImageAlphaNoneSkipFirst);
    CGColorSpaceRelease( colorSpace );
    CGContextClearRect( tcontext, CGRectMake( 0, 0, width, height ) );
        CGContextDrawImage( tcontext, CGRectMake( 0, 0, width, height ), inputImage.CGImage );
    UInt8 r,g,b;
    uint offset;
    for (uint y = 0; y < height; y++)
    {
        for (uint x = 0; x < width; x++)
        {
            offset = y * (int)width + x;
            if (offset+2 < width * height) //superstitious range check
            {
                int tptr = 4*(offset);
                r = imageData[tptr+1];
                g = imageData[tptr+2];
                b = imageData[tptr+3];
                targetData[tptr++] = 0;
                targetData[tptr++] = (unsigned char)((float)r * rlevel);
                targetData[tptr++] = (unsigned char)((float)g * glevel);
                targetData[tptr++] = (unsigned char)((float)b * blevel);
            }
        }
    }
    UIImage *resultImage = [self getImageFromData : targetData : width : height];
    CGContextRelease(tcontext); //11/16 wups, fix memory leak

    return resultImage;
} //end processChannels

//----(imageEditVC)------------------------------------------------------------
// ONLY flips ONE channel pair, ignores other flags after first if found
-(UIImage*) flipChannels : (UIImage*) inputImage : (BOOL) frg : (BOOL) fbg : (BOOL) frb
{
    int width  = inputImage.size.width;
    int height = inputImage.size.height;
    int bprow  = 4*width;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    char *imageData = malloc( height * width * 4 );
    CGContextRef tcontext = CGBitmapContextCreate( imageData, width, height, 8, bprow, colorSpace,
                                                  kCGImageAlphaNoneSkipFirst);
    CGColorSpaceRelease( colorSpace );
    CGContextClearRect( tcontext, CGRectMake( 0, 0, width, height ) );
    CGContextDrawImage( tcontext, CGRectMake( 0, 0, width, height ), inputImage.CGImage );
    
    unsigned char *targetData = (unsigned char *)malloc(width*height*4);
    
    UInt8 r,g,b;
    uint offset;
    for (uint y = 0; y < height; y++)
    {
        for (uint x = 0; x < width; x++)
        {
            offset = y * (int)width + x;
            if (offset+2 < width * height) //superstitious range check
            {
                int tptr = 4*(offset);
                r = imageData[tptr+1];
                g = imageData[tptr+2];
                b = imageData[tptr+3];

                uint rgbt;
                if (frg) //flip rg
                {
                    rgbt = r;
                    r    = g;
                    g    = rgbt;
                }
                else if (fbg) //flip bg
                {
                    rgbt = b;
                    b    = g;
                    g    = rgbt;
                }
                else if (frb) //flip rb
                {
                    rgbt = r;
                    r    = b;
                    b    = rgbt;
                }
                
                targetData[tptr++] = 0;
                targetData[tptr++] = r;
                targetData[tptr++] = g;
                targetData[tptr++] = b;
            }
        }
    }
    UIImage *resultImage = [self getImageFromData : targetData : width : height];
    free(targetData);
    free(imageData);
    CGContextRelease(tcontext); //11/16 wups, fix memory leak
    return resultImage;
} //end flipChannels

//----(imageEditVC)------------------------------------------------------------
//assumes ARGB input / output
-(UIImage*) getImageFromData : (unsigned char *)rgbData : (int) width : (int) height
{
    CGContextRef context;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    context = CGBitmapContextCreate(rgbData,
                                    width, height,
                                    8, 4*width,
                                    colorSpace,
                                    kCGImageAlphaNoneSkipFirst);
    CGImageRef imageRef = CGBitmapContextCreateImage (context);
    CGContextRelease(context); //11/16 wups, fix memory leak
    return  [UIImage imageWithCGImage:imageRef];
}

@end




                      
                      
