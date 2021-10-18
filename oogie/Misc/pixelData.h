//         _          _ ____        _
//   _ __ (_)_  _____| |  _ \  __ _| |_ __ _
//  | '_ \| \ \/ / _ \ | | | |/ _` | __/ _` |
//  | |_) | |>  <  __/ | |_| | (_| | || (_| |
//  | .__/|_/_/\_\___|_|____/ \__,_|\__\__,_|
//  |_|
//
//  pixelData.h
//  oogie2D
//
//  Created by Dave Scruton on 4/30/20.
//  Copyright © 2020 fractallonomy. All rights reserved.
//


@interface pixelData : NSObject
{
    unsigned char *imageData;  
    int twidth,theight;
}

-(void) setupImageBitmap : (UIImage*) i;
-(void) freeImageBitmap;

-(UIColor*) getRGBAtPoint : (int) xc : (int) yc;
@end
//-(void) pixAlert : (UIViewController *) parent : (NSString *) title : (NSString *) message : (BOOL) yesnoOption;

