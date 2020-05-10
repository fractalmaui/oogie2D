//
//     ____              _    _______ _________
//    / __ \____  ____ _(_)__/_  __(_) __/ __(_)__
//   / / / / __ \/ __ `/ / _ \/ / / / /_/ /_/ / _ \
//  / /_/ / /_/ / /_/ / /  __/ / / / __/ __/ /  __/
//  \____/\____/\__, /_/\___/_/ /_/_/ /_/ /_/\___/
//             /____/
//
//  ogieTiffie.m
//
//  Created by Dave Scruton on 5/10/2020 (redone for oogie)
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h> 
#import "tiffie.h"
#import "UIImageExtras.h"

@protocol oogieTiffieDelegate;


//This is retarded, for now we have to define pro version
//  HERE and in swift separately!!
#define PRO_VERSION

//TIFFIE fileTypes, just in case there are different formats...
#define ROADIETRIP_BASIC  800
#define ROADIETRIP_PRO    801
#define ROADIETRIP_DELUXE 800

@interface OogieTiffie : NSObject
{
    int isLoading;
    int numKeyframes;
}

@property (nonatomic, unsafe_unretained) id <oogieTiffieDelegate> delegate; // receiver of completion messages


@property (nonatomic , strong) NSString *tiffieError;
@property (nonatomic , strong) NSString *tifCaption;
@property (nonatomic , strong) UIImage *screenShot;

- (void)writeToPhotos : (NSString*) title : (NSString *)jsonString : (UIImage*) ss;
- (NSString*)readFromPhotos: (UIImage *)tifImage;

@end

@protocol oogieTiffieDelegate <NSObject>
@optional
-(void) didReadRTTiffie;
-(void) didWriteRTTiffie;


//DHS 11/23
-(NSUInteger) indexOfID : (NSString *)id;

@end

