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
//  12/3 renamed -> loadEditsFromDocs
#import <Foundation/Foundation.h>

@interface edits : NSObject
{
    NSString *docPath;
    NSMutableDictionary *editDict;
    NSMutableDictionary *savedEdits;
}

+ (id)sharedInstance;

-(void) loadEditsFromDocs;
-(void) saveToDocs;
-(void) addEdit : (NSString *) patchName :(NSString *) paramName : (NSString *) value;
-(void) factoryReset;
-(void) removeAllEdits : (NSString *) patchName;
-(void) removeEdit : (NSString *) patchName :(NSString *) paramName;
-(NSArray *) getEditKeys : (NSString *) patchName;
-(NSString*) getValueForKey : (NSString *)patchName : (NSString *) key;
-(NSDictionary*) getEditsForPatch: (NSString *) patchName;
-(void) pushEditForPatch : (NSString *)pname;
-(void) popEditForPatch : (NSString *)pname;
-(BOOL) wasEdited : (NSString*) patchName;


@end

