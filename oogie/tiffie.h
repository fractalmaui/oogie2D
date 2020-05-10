//
//
//   _   _  __  __ _
//  | |_(_)/ _|/ _(_) ___
//  | __| | |_| |_| |/ _ \
//  | |_| |  _|  _| |  __/
//   \__|_|_| |_| |_|\___|
// Tiffie: Smart Images
//
//  Created by dave scruton on 5/29/13.
//  Copyright (c) 2013 fractallonomy. All rights reserved.
//

#ifndef generic_TIFFIE_h
#define generic_TIFFIE_h
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

void tiffieInit(void);
void tiffieTerm(void);
#define TIFF_TOPROW       256
#define TIFF_HEADER       0xeaebecff
#define TIFF_HEADER_TEST  0xeaebecff
#define TIFF_TOPLABEL     120

void embedLabelInBmp(int x,int y,int twidth,NSString *label,void *imageData);

int getPackPtr(void);
unsigned int pulloutPack(int index);
void loadinPack(int index,unsigned int ival);
void packInit(int size);
void packTerm(void);
void packInt(int ival);
void packFloat(float rval);
void packString(NSString *pstr);
void packPixels(void);
int unpackInt(void);
float unpackFloat(void);
NSString *unpackString(void);
void unpackPixels(void);

#endif
