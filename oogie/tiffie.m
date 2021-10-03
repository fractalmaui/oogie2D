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
// DHS 5/30/13: READY FOR RELEASE! 
// DHS 5/31/13: flipped sphere texture vertically, now it matches other shapes
//=========================================================================
// APP submittal to Apple, June 13th!!!
//=========================================================================
// DHS 7/4...6 Added float/int conversion to/from 24-bit pixel data,
//              used by read/write setups in main...
// DHS 7/11/13: After a trip to the library and heatstroke, it looks like
//               the second try at packing/unpacking to pixels works!
//               we will use the 3-value pack -> 4 color pixel scheme.
//=========================================================================
//#import <OpenGLES/ES1/gl.h>
//#import <OpenGLES/ES1/glext.h>
//#import <OpenGLES/ES2/gl.h>
//#import <OpenGLES/ES2/glext.h>

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include "tiffie.h"
#include "cheat.h"
//Font used to write text into bitmap...
#include "alpha5x7.h"

#define PI						3.141592627
#define TWOPI					PI * 2.0
#define DEGREES_TO_RADIANS		PI / 180.0



int packSize,packPtr,packMod;
unsigned int *packData;
unsigned char r0,r1,r2,r3;
unsigned char g0,g1,g2,g3;
unsigned char b0,b1,b2,b3;
unsigned char b4[4];


//---------(packpixels)----------------(packpixels)--------
void tiffieInit(void)
{
//    texSphereDrawn  = 0;
//    texConeDrawn    = 0;
    
} //end tiffieInit


//---------(packpixels)----------------(packpixels)--------
void embedLabelInBmp(int x,int y,int twidth,NSString *label,void *imageData)
{
    
    int slen,loop;
    int aptr,optr,ooptr,loop3,loop4;
    unsigned char rgba[4]; //10/1/21 OK now? was seeing warnings
    
    NSString *tlab =[NSString stringWithFormat:@".%@",label];
    slen = (int)[tlab length];
    if (slen > 32) slen = 32;   //5/10 enlarge!
    LOOPIT(slen)
    {
        char tchar;
        tchar = (int)( [tlab characterAtIndex: loop] );
        // NSLog(@"...char[%d] %d",loop,tchar);
        //lowercase is 97 - 122
        //uppercase is 65 - 90
        //digits 0-9   48 - 57
        //letters are 5x7, across, then down...
        if (tchar != 32) //lowercase is above 90!
        {
            //if ((tchar > 32)&&(tchar < 32+87))  //lowercase?
            //{
                //tchar -= 33;
            //}
            //NSLog(@" final tchar %d",(int)tchar);
            aptr = 35 * (tchar-33); //point to glyph start...
            optr = 4 * y * twidth; //point to TOP LEFT of output bitmap...
            optr+=(20 + 28*loop); //move over to next glyph...
            ooptr = optr; //remember start
            for(loop3=0;loop3<7;loop3++) //for each row of glyph..
            {
                optr = ooptr + 4*twidth*loop3; //get next starting spot...
                for(loop4=0;loop4<5;loop4++) //for each col of glyph..
                {
                    rgba[0] = 0;
                    rgba[1] = 0;
                    rgba[2] = 0;
                    rgba[3] = 255;
                    if (alpha5x7[aptr]) //ONE? set to WHITE
                    {
                        rgba[0] = 20; //Need a color that looks good everywhere....
                        rgba[1] = 23;
                        rgba[2] = 23;
                        rgba[3] = 255;
                        memcpy(imageData+optr,rgba,4);
                    }
                    optr+=4;
                    aptr++;
                } //end loop4
                
            }    //end loop3
        } //end if tchar
    }  //end loop
    
} // end embedLabelInBmp




//---------(packpixels)----------------(packpixels)--------
int getPackPtr(void)
{
    return packPtr ;
}

//---------(packpixels)----------------(packpixels)--------
unsigned int pulloutPack(int index)
{
    if (index >= packSize ) return 0;  //out of bounds
    return packData[index] ;
}

//---------(packpixels)----------------(packpixels)--------
void loadinPack(int index,unsigned int ival)
{
    if (index >= packSize ) return;  //out of bounds
    packData[index]=ival;
}

//---------(packpixels)----------------(packpixels)--------
void packInit(int size)
{
    int size16;
    packPtr = 0;
    packMod = 0;
    r0 = r1 = r2 = r3 =0;
    g0 = g1 = g2 = g3 =0;
    b0 = b1 = b2 = b3 =0;
    
    if (packData !=NULL)
    {
        //NSLog(@" packInit, free old data...");
        free(packData );
        packData = NULL;
    }
    size16 = 16*size;
    packData = (unsigned int *)malloc(size16);
    if (packData != NULL)
    {
        //NSLog(@" packInit, got %d bytes...",size4);
        packSize = 4*size;
    }
    else 
    {
        packSize = 0;
    }
}  // end packInit 

//---------(packpixels)----------------(packpixels)--------
void packTerm(void)
{
    if (packData !=NULL)
    {
        free(packData );
        packData = NULL;
    }
}  // end packTerm


//---------(packpixels)----------------(packpixels)--------
void packInt(int ival)
{
    int tint;
    tint = ival;
    //NSLog( @" pI[%d ] %x %d",packPtr,tint,tint);
    memcpy(b4,&tint,4);  // copy to work
    packPixels();
}//end packInt


//---------(packpixels)----------------(packpixels)--------
void packFloat(float rval)
{
    unsigned int uint;
    float tf;
    tf = rval;
    memcpy(&uint,&tf,4);
    //NSLog( @" pf[%d ] %x %f",packPtr,uint,tf);
    memcpy(b4,&tf,4);  // copy to work
    packPixels();
}//end packFloat

//---------(packpixels)----------------(packpixels)--------
void packString(NSString *pstr)
{
    int loop,tint,plen = (int)[pstr length];
    char pathstr[1024];  //Note limit!
    //add our name to the bitmap too!
    memset(pathstr,0,1024); //clearitout!
    sprintf(pathstr,"%s   ",
            [pstr cStringUsingEncoding:NSASCIIStringEncoding ]) ;
    if (plen % 3 != 0) //make sure length is multiple of 3!
    {
        plen++;
    }
    if (plen % 3 != 0) //make sure length is multiple of 3!
    {
        plen++;
    }
    //Need to pack up the string into pixels, WEIRD. Skip alphas...
    packInt(plen);  //pack length first!
    int ssptr = 0;
    for(loop=0;loop<plen/3;loop++)
        {
            tint = 0xff;
            tint = (tint << 8) + pathstr[ssptr++]; //pack R
            tint = (tint << 8) + pathstr[ssptr++]; //pack G
            tint = (tint << 8) + pathstr[ssptr++]; //pack B
            packInt(tint);
        }
} //end packString


//---------(packpixels)----------------(packpixels)--------
void packPixels(void)
{
    unsigned char workc[4]; //10/1/21 was getting warning
    if (packPtr > packSize -4) return;//out of space!
    if (packMod %3 == 0)
    { 
        r0=b4[0];
        r1=b4[1];
        r2=b4[2];
        r3=b4[3];
    }
    if (packMod %3 == 1)
    { 
        g0=b4[0];
        g1=b4[1];
        g2=b4[2];
        g3=b4[3];
    }
    if (packMod %3 == 2)
    { 
        b0=b4[0];
        b1=b4[1];
        b2=b4[2];
        b3=b4[3];
    }
    packMod++;
    if (packMod %3 == 0) //time to write pixels
    {
        //NSLog(@" -----p ");
        //NSLog(@"  r %x %x %x %x g %x %x %x %x b %x %x %x %x",
        //      r0,r1,r2,r3,g0,g1,g2,g3,b0,b1,b2,b3);
        workc[0]=r0;
        workc[1]=g0;
        workc[2]=b0;
        workc[3]=255;   //alpha first or last?
        memcpy(packData + packPtr ,workc,4);
        packPtr++;
        workc[0]=r1;
        workc[1]=g1;
        workc[2]=b1;
        workc[3]=255;   //alpha first or last?
        memcpy(packData + packPtr ,workc,4);
        packPtr++;
        workc[0]=r2;
        workc[1]=g2;
        workc[2]=b2;
        workc[3]=255;   //alpha first or last?
        memcpy(packData + packPtr ,workc,4);
        packPtr++;
        workc[0]=r3;
        workc[1]=g3;
        workc[2]=b3;
        workc[3]=255;   //alpha first or last?
        memcpy(packData + packPtr ,workc,4);
        packPtr++;
    }
}//end packPixels


 //---------(packpixels)----------------(packpixels)--------
int unpackInt(void)
{
    int tint;
    unpackPixels();
    memcpy(&tint,b4,4);
    //NSLog( @" Upi[%d ] %x %d",packPtr,tint,tint);
    return tint;
} //end unpackint

//---------(packpixels)----------------(packpixels)--------
float unpackFloat(void)
{
    float tf;
    unsigned int uint;
    unpackPixels();
    memcpy(&uint,b4,4);
    memcpy(&tf,b4,4);
    //NSLog( @" Upf[%d ] %x %f",packPtr,uint,tf);
    return tf;
} //end unpackFloat


//---------(packpixels)----------------(packpixels)--------
NSString *unpackString(void)
{
    int loop,ntint;
    char pstr[1024];
    NSString *result;  
    int slen = unpackInt();  //Get string length first!
    //OK, unpack our string!
    int ssptr = 0;
    memset(pstr,0,1024);
    for(loop=0;loop<slen/3;loop++)
    {
        unpackPixels();
        memcpy(&ntint,b4,4);
        pstr[ssptr+2] = (char)(ntint & 0xff);
        ntint = ntint >> 8;
        pstr[ssptr+1] = (char)(ntint & 0xff);
        ntint = ntint >> 8;
        pstr[ssptr] = (char)(ntint & 0xff);
        ssptr+=3;
    }
    result = [NSString stringWithCString:pstr
                                   encoding:NSUTF8StringEncoding];

    
    ///NSLog(@" ...unpackString %@",result);
    return result;
    
} //end unpackString


//---------(packpixels)----------------(packpixels)--------
void unpackPixels(void)
{
    unsigned int ruint;
    char workc[4];
    if (packMod % 3 ==0) //need to unload pixels?
    {
        memcpy(workc,packData + packPtr ,4);
        //memcpy(&ruint,workc,4);
        //NSLog(@" u0 %x",ruint);
        packPtr++;
        r0=  workc[0];
        g0=  workc[1];
        b0=  workc[2];
        memcpy(workc,packData + packPtr ,4);
        //memcpy(&ruint,workc,4);
        //NSLog(@" u1 %x",ruint);
        packPtr++;
        r1=  workc[0];
        g1=  workc[1];
        b1=  workc[2];
        memcpy(workc,packData + packPtr ,4);
        //memcpy(&ruint,workc,4);
        //NSLog(@" u2 %x",ruint);
        packPtr++;
        r2=  workc[0];
        g2=  workc[1];
        b2=  workc[2];
        memcpy(workc,packData + packPtr ,4);
        //memcpy(&ruint,workc,4);
        //NSLog(@" u3 %x",ruint);
        packPtr++;
        r3=  workc[0];
        g3=  workc[1];
        b3=  workc[2];
        //NSLog(@" -----U ");
        //NSLog(@"  r %x %x %x %x g %x %x %x %x b %x %x %x %x",
        //      r0,r1,r2,r3,g0,g1,g2,g3,b0,b1,b2,b3);
    } //end unload pixels
    if (packMod %3 == 0)
    { 
        b4[0]= r0;
        b4[1]= r1;
        b4[2]= r2;
        b4[3]= r3;
    }
    if (packMod %3 == 1)
    { 
        b4[0]= g0;
        b4[1]= g1;
        b4[2]= g2;
        b4[3]= g3;
    }
    if (packMod %3 == 2)
    { 
        b4[0]= b0;
        b4[1]= b1;
        b4[2]= b2;
        b4[3]= b3;
    }
    memcpy(&ruint,b4,4);
    //NSLog(@" unp %x",ruint);
    packMod ++;
    
} //end unpackPixels 

 




//--------(GENogl)------------------------------------------------
void tiffieTerm(void)
{

    
} //end tiffieTerm

 //END tiffie stuff....
