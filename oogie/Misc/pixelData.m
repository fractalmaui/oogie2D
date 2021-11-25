//         _          _ ____        _
//   _ __ (_)_  _____| |  _ \  __ _| |_ __ _
//  | '_ \| \ \/ / _ \ | | | |/ _` | __/ _` |
//  | |_) | |>  <  __/ | |_| | (_| | || (_| |
//  | .__/|_/_/\_\___|_|____/ \__,_|\__\__,_|
//  |_|
//
//  pixelData.m
//  oogie2D
//
//  Created by Dave Scruton on 4/30/20.
//  Copyright © 2020 fractallonomy. All rights reserved.
//
//  5/14 add freeImageBitmap
//  11/16  fix memory leak in getImageBitmap

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "pixelData.h"


@implementation pixelData

//======(pixelData)==========================================
// PuzzleID is stored on parse. There must be one unique ID per puzzle, across all platforms.
-(instancetype) init
{
    if (self = [super init])
    {
        imageData = nil;
        twidth = theight = 0;
    }
    return self;
} //end init

//======(pixelData)==========================================
-(void) setupImageBitmap : (UIImage*) i
{
    
    twidth  = (int)CGImageGetWidth (i.CGImage);
    theight = (int)CGImageGetHeight(i.CGImage);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    imageData = malloc( theight * twidth * 4 );
    //Draw the image as a bitmap into the imageData area...
    CGContextRef tcontext = CGBitmapContextCreate( imageData, twidth, theight, 8, 4 * twidth, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big   );
    CGColorSpaceRelease( colorSpace );
    CGContextClearRect( tcontext, CGRectMake( 0, 0, twidth, theight ) );
    CGContextDrawImage( tcontext, CGRectMake( 0, 0, twidth, theight ), i.CGImage );
    CGContextRelease(tcontext); //11/16/21 wups, fix memory leak
} //end getImageBitmap


//======(pixelData)==========================================
// 5/14 new
-(void) freeImageBitmap
{
    free(imageData);
}

//======(pixelData)==========================================
-(UIColor*) getRGBAtPoint : (int) xc : (int) yc
{
    if (xc < 0 || xc >= twidth)  return [UIColor blackColor];
    if (yc < 0 || yc >= theight) return [UIColor blackColor];
    int ptr = 4*((yc*twidth) + xc);
    UIColor *c = [UIColor colorWithRed:(CGFloat)imageData[ptr]/255.0
                                 green:(CGFloat)imageData[ptr+1]/255.0
                                  blue:(CGFloat)imageData[ptr+2]/255.0
                                 alpha:1.0];
    return c;
}


@end
