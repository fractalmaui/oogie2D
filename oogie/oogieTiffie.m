//
//     ____              _    _______ _________
//    / __ \____  ____ _(_)__/_  __(_) __/ __(_)__
//   / / / / __ \/ __ `/ / _ \/ / / / /_/ /_/ / _ \
//  / /_/ / /_/ / /_/ / /  __/ / / / __/ __/ /  __/
//  \____/\____/\__, /_/\___/_/ /_/_/ /_/ /_/\___/
//             /____/
//
//  oogieTiffie.m
//
//  Created by Dave Scruton on 4/23/15.
//
//  5/13 Added transition integer vals to keyframes
//  7/15 Added plugin support
//  2/4/18 Added GenUtils for genAlert message(s)

#import "OogieTiffie.h"
@implementation OogieTiffie

@synthesize delegate = _delegate;

#define IMAGEWH 512
//======(oogieTiffie)==========================================
-(instancetype) init
{
    if (self = [super init])
    {
        _tifCaption        = @"empty";
        isLoading = 0;

    }
    return self;
} //end init



//=====(roadietrip)============================================================
- (NSString*)readFromPhotos: (UIImage *)tifImage
{
    int tptr,iptr,loop,loop1,twidth,theight,dataRow,tint,jsonSize;
    unsigned int tuint;
    twidth  = tifImage.size.width;
    theight = tifImage.size.height;
    char rgba[4];
    unsigned int hdr[32];

    _tiffieError = @"";
    jsonSize     = 0;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *imageData = malloc( theight * twidth * 4 );
    
    CGContextRef tcontext = CGBitmapContextCreate( imageData, twidth, theight, 8, 4 * twidth, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big   );
    CGColorSpaceRelease( colorSpace );
    CGContextClearRect( tcontext, CGRectMake( 0, 0, twidth, theight ) );
    CGContextDrawImage( tcontext, CGRectMake( 0, 0, twidth, theight ), tifImage.CGImage );
    packInit(1024);
    tptr = iptr = 0;
    dataRow = 99999999; //funky init, huh?!
    //_numPlugins = 0;
    for (loop=0;loop<theight;loop++)
    {
        for (loop1=0;loop1<twidth;loop1++)
        {
            //if (loop < 10) NSLog(@" col %d",loop1);
            if (!loop && loop1 < 12) //look for header?
            {
                //if (!loop1) NSLog(@" unload first 8 pixels...");
                memcpy(rgba,imageData+tptr,4);  //get pixel out,
                memcpy(&tuint,rgba,4);
                hdr[loop1] = tuint;
                //NSLog(@" hdr[%d]; %x",loop1,hdr[loop1]);
                loadinPack(loop1,tuint);   //Load up unpacking system...
            }
            if (!loop && loop1 == 11) //OK, loaded in first 12 pixels
            {
                int okeydokey=0;
                //NSLog(@" look for header... FUCKED if this gets hit btw!");
                tint = unpackInt();
                if (tint == 83) okeydokey++;
                tint = unpackInt();
                if (tint == 77) okeydokey++;
                tint = unpackInt();
                if (tint == 65) okeydokey++;
                tint = unpackInt();
                if (tint == 82) okeydokey++;
                tint = unpackInt();
                if (tint == 84) okeydokey++;
                int versionA,versionB;
                versionA = unpackInt();
                versionB = unpackInt();
                tint = unpackInt();
                if (okeydokey == 5) //found 'SMART'?
                {
                    dataRow = tint;
                    //NSLog(@" SMART Header found, row...%d  %d/%d",dataRow,versionA,versionB);
                }
                else
                {
                    dataRow = TIFF_TOPROW;
                    //NSLog(@" SMART Header error, row %d",dataRow);
                    _tiffieError = @"error : Image is not a TIFFIE File";
                    return _tiffieError;
                }
                if (versionA != 65 || versionB != 65) //Not AA version? Error!
                {
                    _tiffieError = @"error : Bad TIFFIE Version";
                    return _tiffieError;
                }
                tint = unpackInt();
                if (tint > 0 && tint < 100000) //what should max be?
                    jsonSize = tint;
                else
                    jsonSize = 256;
                packInit(65536); //Re-init unpacking system...
            }
            if (loop >= dataRow && iptr < 65536)  //Read in all 1024!
            {
                memcpy(rgba,imageData+tptr,4);  //get from bitmap...
                memcpy(&tuint,rgba,4);         //and store as encoded val
                loadinPack(iptr,tuint);       //Load up unpacking system...
                iptr++;
            }
            tptr+=4;
        }
    }
    tint = unpackInt();
    if (tint != TIFF_HEADER_TEST) //BOGUS DATA? Bail!
    {
        //NSLog(@" Failed TIFF_HEADER_TEST(%d) %x vs %x",getPackPtr(),tint,TIFF_HEADER_TEST);
        _tiffieError = @"error : Bad TIFFIE Header";
        return _tiffieError;
    }

    NSString *result = @"";
    int jptr = 0;
    while (jptr < jsonSize)
    {
        int chunkSize = MIN(1024,jsonSize-jptr);
        NSString *nextChunk = [self unpackNSString : chunkSize]; //WTF? why 9!?!?!
        result = [result stringByAppendingString:nextChunk];
        jptr += chunkSize;
    }
    //NSLog(@" result len %d",(int)result.length);
    //NSLog(@" got string [%@]",result);
    //NSLog(@" stringlen %d vs %d",result.length,jsonSize);
    return result; //Indicate success!
} //end readFromPhotos


//======(oogieTiffie)==========================================
-(NSString *) paddStringToNearestWord : (NSString *)instring
{
    int slen = (int)instring.length;
    int slen4 = slen / 4;
    //NSLog(@" padd [%@] len %d",instring,slen);
    if (4*slen4 != slen) //needs padding?
    {
        slen4 *=4;
        //NSLog(@" ..neeeds padding %d vs %d",slen4 , slen);
        NSString *workString = [instring stringByPaddingToLength:(slen4+4) withString:@" " startingAtIndex:0];
        instring = workString;
    }
    //NSLog(@" result [%@] padded to length %d",instring,slen4+4);
    return instring;
} //end paddStringToNearestWord

//======(oogieTiffie)==========================================
// a RGBWord is a 3-letter combo!
-(NSString *) paddStringToNearestRGBWord : (NSString *)instring
{
    int slen = (int)instring.length;
    int slen3 = slen / 3;
    //NSLog(@" padd [%@] len %d",instring,slen);
    if (3*slen3 != slen) //needs padding?
    {
        slen3 *=3;
        NSString *workString = [instring stringByPaddingToLength:(slen3+3) withString:@" " startingAtIndex:0];
        instring = workString;
    }
    //NSLog(@" result [%@] padded to length %d",instring,slen3+3);
    return instring;
} //end paddStringToNearestWord


//======(oogieTiffie)==========================================
// OUCH! Looks like strings need to be multiples of 3 in length!
-(void) packNSString : (NSString *)stringie
{
    int loop,tint,ssptr = 0;
    int slen = (int)stringie.length;
//    if (slen % 3 != 0)  //Odd length? Paddit!
//    {
//        int paddlen = 3 + slen;
//        stringie = [stringie stringByPaddingToLength:(paddlen) withString:@" " startingAtIndex:0];
//    }

    const char *cstringie = [stringie UTF8String];
    for (loop=0;loop<slen;loop++)
    {
        tint = 0xff;
        tint = (tint << 8) + cstringie[ssptr++]; //pack R
        tint = (tint << 8) + cstringie[ssptr++]; //pack G
        tint = (tint << 8) + cstringie[ssptr++]; //pack B
        packInt(tint);
    }
} //end packNSString

//======(oogieTiffie)==========================================
// Needs to know how much to unpack!
//   Size should be multiple of 3!!
-(NSString *) unpackNSString : (int) size
{
    int loop,tint;
    int ssptr = 0;

    char pstr[65536];
    for (loop=0;loop<size;loop++)
    {
        tint = unpackInt();
        pstr[ssptr+2] = (char)(tint & 0xff);
        tint = tint >> 8;
        pstr[ssptr+1] = (char)(tint & 0xff);
        tint = tint >> 8;
        pstr[ssptr] = (char)(tint & 0xff);
        ssptr+=3;
    }
    pstr[ssptr-1] = 0;
    NSString *result = [NSString stringWithUTF8String:pstr];
    //NSLog(@" result len %d",result.length);
   return result;
}

//======(oogieTiffie)==========================================
-(void) packIntArray : (NSMutableArray *)iarray
{
    for (NSNumber *nn in iarray)
    {
        packInt(nn.intValue);
    }
} //end packIntArray

//======(oogieTiffie)==========================================
-(void) packFloatArray : (NSMutableArray *)iarray
{
    for (NSNumber *nn in iarray)
    {
        packFloat(nn.floatValue);
    }
} //end packFloatArray



//======(oogieTiffie)==========================================
// New Photo writer: uses a NSDictionary and metadata...
- (void)writeToPhotos : (NSString*) title : (NSString *)jsonString : (UIImage*) ss
{
    int i,iwid,jsonLen;
    NSString *workString;
    //First get our image
    int theight,twidth;
//    NSString *path  = [[NSBundle mainBundle] pathForResource:name ofType:ext];
//    NSData *texData = [[NSData alloc] initWithContentsOfFile:path];
    UIImage *image  = ss; //copyscreenshot to work image

    
    UIImage *w64  = [UIImage imageNamed:@"white64x64"];
    UIImage *bkgd = [UIImage imageNamed:@"bg128"];

    
    image = [image imageByScalingAndCroppingForSize : CGSizeMake(IMAGEWH,IMAGEWH)  ];

    int jsonWSize = (int)jsonString.length;
    int jwsize    = jsonWSize / 256;
    jwsize /= 256;
    jwsize++;
    jwsize*=256;
    //NSLog(@" write json, size %d wsize %d capacity %d",jsonWSize,jwsize,3*iwid*iwid);
    
    int w = image.size.width;
    int h = image.size.height;
    int previewCol = 20;
    int previewRow = 40;
    int previewHit = h / 2 - 80;
    if (w != IMAGEWH || h!= IMAGEWH)
    {
        NSLog(@"error: image must be %dx%d!",IMAGEWH,IMAGEWH);
        return;
    }
    //Draw bkgd image in full area...
    UIGraphicsBeginImageContext(image.size);
    [bkgd drawInRect:CGRectMake(0,0,w,h)];
    //White frame around actual image...
    [w64   drawInRect:CGRectMake(previewCol-3,previewRow-3,previewHit+6,previewHit+6) blendMode:kCGBlendModeNormal alpha:1.0];
    //Draw screenshot in small box at top left...
    [image drawInRect:CGRectMake(previewCol,previewRow,previewHit,previewHit) blendMode:kCGBlendModeNormal alpha:1.0];
    
    UIFont *font = [UIFont fontWithName:@"AvenirNext-Bold" size:28.0f];
    NSParagraphStyle *paragraphStyle = [NSParagraphStyle defaultParagraphStyle];
    NSDictionary *attributes = @{NSFontAttributeName : font, NSParagraphStyleAttributeName : paragraphStyle, NSForegroundColorAttributeName : [UIColor blackColor]};
    int titleX = 220;
    int titleH = 200;
    int titleW = w - titleX - 20;
    [title drawInRect:CGRectMake(titleX,previewRow, titleW, titleH) withAttributes:attributes];

    
    //Copy back to original image...
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    
    twidth  = (int)CGImageGetWidth (image.CGImage);
    theight = (int)CGImageGetHeight(image.CGImage);
    
    //It's Packing time!
    unsigned int hdr[16];
    int loop,tuint;
    packInit(1024);  //Max size of our packed buffer
    //First, let's create a 8-int header: (SMARTXX) S,M,A,R,T, (XX is version#) and start row...
    packInt(83);
    packInt(77);
    packInt(65);
    packInt(82);
    packInt(84);
    packInt(65);  //Version AA
    packInt(65);
    packInt(TIFF_TOPROW);
    packInt((int)jsonString.length); //Pack string size
    packInt(0);
    packInt(0);
    packInt(0);
    // Pull out our header info...
    for (loop=0;loop<12;loop++) //DHS was 8
    {
        tuint = pulloutPack(loop);
        //NSLog(@" pullout[%d] %x",loop,tuint);
        hdr[loop] = tuint;
    }
    //Re-init pack area...
    // HOW DO I GET THIS ON READ?????
    packInit(65536);  //Re-init for actual data read...
    //OK, pack up our data!
    packInt(TIFF_HEADER);
    //OK packitup! 1024 chars at a time...
    int jlen = (int)jsonString.length;
    int jptr = 0;
    while (jptr < jlen)
    {
        NSRange jrange = NSMakeRange(jptr,MIN(1024,jlen-jptr));
        NSString *jjj = [jsonString substringWithRange:jrange];
        NSLog(@" jjj len %d",jjj.length);
        [self packNSString:jjj];
        jptr += 1024;
    }
    
    //Padd to nearest multiple of 3 packs if needed....
    // 11/30 no need? packPaddIfNeeded();
    
    //Let's encode our data to pixels now! Embed data into image..
    int itotal,tptr,iptr,loop1;
    char rgba[4];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    void *imageData = malloc( theight * twidth * 4 );
    CGContextRef tcontext = CGBitmapContextCreate( imageData, twidth, theight, 8, 4 * twidth, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big  );
    CGColorSpaceRelease( colorSpace );
    CGContextClearRect( tcontext, CGRectMake( 0, 0, twidth, theight ) );
    CGContextDrawImage( tcontext, CGRectMake( 0, 0, twidth, theight ), image.CGImage );
    itotal = getPackPtr();
    tptr=iptr=0;
    for (loop=0;loop<theight;loop++)  //Colors are encoded R,G,B,A
    {
        for (loop1=0;loop1<twidth;loop1++)
        {
            //Store our header... top row, first 8 cols
            if (!loop && loop1<12) //DHS was 8
            {
                tuint = hdr[loop1];
                //NSLog(@" pack hdr %d [%d, %x]",loop1,tuint,tuint);
                memcpy(rgba,&tuint,4);     //get next encoded val
                memcpy(imageData+tptr,rgba,4);  //put into bitmap...
            }
            //last n rows, data area... start row is ARBITRARY,
            //  BUT must match across all reads/writes!
            if (loop >= TIFF_TOPROW && iptr < itotal)  //need to write more?
            {
                tuint = pulloutPack(iptr);
                memcpy(rgba,&tuint,4);           //get next encoded val
                memcpy(imageData+tptr,rgba,4);  //put into bitmap...
                iptr++;
            }
            tptr+=4;
        }
    }
    embedLabelInBmp(0,2,twidth,title,imageData);

    CGImageRef newImage = CGBitmapContextCreateImage(tcontext);
    UIImage*  timage    = [UIImage imageWithCGImage:newImage scale:1 orientation:0];
    NSData* imdata      = UIImagePNGRepresentation(timage); // get PNG representation
    UIImage* myImagePNG = [UIImage imageWithData:imdata]; // wrap UIImage around PNG representation
    CGImageRelease(newImage);
    UIImageWriteToSavedPhotosAlbum(myImagePNG, self,
                                   @selector(image:didFinishSavingWithError:contextInfo:),
                                   nil);
    packTerm();
    free(imageData);
    [_delegate didWriteRTTiffie];
} //end writeToPhotos




//======(oogieTiffie)==========================================
// convenience function: needed by createTIFFIE to handle image write
//    to photo album....
-(void)image:(UIImage *)image
didFinishSavingWithError:(NSError *)error
 contextInfo:(void *)contextInfo
{
    if (error) { //DHS 2/4/18
        NSLog(@" error saving tiffie!");
    }
}  //end didFinishSavingWithError


@end
