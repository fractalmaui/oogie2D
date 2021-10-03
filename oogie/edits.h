//            _ _ _
//    ___  __| (_) |_ ___
//   / _ \/ _` | | __/ __|
//  |  __/ (_| | | |_\__ \
//   \___|\__,_|_|\__|___/
//
//  edits.h
//  edits
//
//  Created by Dave Scruton on 6/27/20.
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//

#import <Foundation/Foundation.h>
//#import "oogieVoice.h"  //8/12/21 DHS oogieCam -> oogie2D

NS_ASSUME_NONNULL_BEGIN

@interface edits : NSObject
{
    NSString *docPath;
    NSMutableDictionary *editDict;
    NSMutableDictionary *savedEdits;
}

+ (id)sharedInstance;

-(void) loadFromDocs;
-(void) saveToDocs;
-(void) addEdit : (NSString *) patchName :(NSString *) paramName : (NSString *) value;
//-(void) applyEditsToVoice : (NSString *) patchName : (oogieVoice*) ov;
-(void) removeAllEdits : (NSString *) patchName;
-(void) removeEdit : (NSString *) patchName :(NSString *) paramName;
-(NSArray *) getEditKeys : (NSString *) patchName;
-(NSString*) getValueForKey : (NSString *)patchName : (NSString *) key;
-(NSDictionary*) getEditsForPatch: (NSString *) patchName;
-(void) pushEditForPatch : (NSString *)pname;
-(void) popEditForPatch : (NSString *)pname;
-(BOOL) wasEdited : (NSString*) patchName;


@end

NS_ASSUME_NONNULL_END
