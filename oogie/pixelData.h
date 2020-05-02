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

-(void) getImageBitmap : (UIImage*) i;
-(UIColor*) getRGBAtPoint : (int) xc : (int) yc;
@end
//-(void) pixAlert : (UIViewController *) parent : (NSString *) title : (NSString *) message : (BOOL) yesnoOption;

