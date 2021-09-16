//            _ _ _
//    ___  __| (_) |_ ___
//   / _ \/ _` | | __/ __|
//  |  __/ (_| | | |_\__ \
//   \___|\__,_|_|\__|___/
//
//  edits.m
//
//  Created by Dave Scruton on 6/27/20.
//  Copyright © 1990 - 2021 fractallonomy, inc. All Rights Reserved.
//
//  edits are stored in a file, they consist of a key (patchname) followed
//    by a sequence of name value pairs.
//  one line example:  (case OK for key? but names should be lowercase)
//    SineWave>attack:23,decay:22,sustain:6
//  9/8 added removeAllEdits
//  4/26 cleanup
//  5/15 add nil key check in loadFromDocs
#import "edits.h"

@implementation edits

static edits *sharedInstance = nil;

//======<edits>========================================================
// Get the shared instance and create it if necessary.
+ (edits *)sharedInstance {
    if (sharedInstance == nil) {
        sharedInstance = [[super allocWithZone:NULL] init];
    }
    return sharedInstance;
}

//======<edits>========================================================
-(instancetype) init
{
    if (self = [super init])
    {
        NSArray  *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);

        docPath    = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"edits"];
        editDict   = [[NSMutableDictionary alloc] init];
        savedEdits = [[NSMutableDictionary alloc] init]; // for restoring edits after a cancel
        [self loadFromDocs];
    }
    return self;
}

//======<edits>========================================================
-(void) loadFromDocs
{
    NSError *error;
    NSURL *url = [NSURL fileURLWithPath:docPath];
    NSString *fileContentsAscii = [NSString stringWithContentsOfURL:url encoding:NSASCIIStringEncoding error:&error];
    NSArray *editItems    = [fileContentsAscii componentsSeparatedByString:@"\n"];
    for (NSString *s in editItems) //loop over records
    {
        //split key from rest of record
        NSArray *lineItems    = [s componentsSeparatedByString:@">"];
        if (lineItems.count > 1) // should be patchname>item,item,item
        {
            NSString *patchName = lineItems[0];
            if (patchName != nil) //5/15 nil check
            {
                NSString *items     = lineItems[1];
                NSArray *paramItems = [items componentsSeparatedByString:@","];
                NSMutableDictionary *patchDict = [[NSMutableDictionary alloc] init];
                for (NSString *item in paramItems) //loop over items
                {
                    NSArray *keyValuePair = [item componentsSeparatedByString:@":"];
                    if (keyValuePair.count == 2) //should be name:value
                    {
                        NSString *key = keyValuePair[0];
                        NSString *val = keyValuePair[1];
                        if (key != nil) //5/15 nil key check
                            [patchDict setObject:val forKey:key.lowercaseString];
                    }
                } //done with items
                [editDict setObject:patchDict forKey:patchName];
            }
            else NSLog(@" ERROR: loadFromDocs nil patchname key");  //5/15
        } //end lineitems.count
    } // end for string s
} //end loadFromDocs

//======<edits>========================================================
-(void) pushEditForPatch : (NSString *)pname
{
    savedEdits[pname] = editDict[pname];
}

//======<edits>========================================================
-(void) popEditForPatch : (NSString *)pname
{
    if (savedEdits[pname] != nil)
    {
        editDict[pname] = savedEdits[pname];
        [self saveToDocs]; //update storage
    }
}

//======<edits>========================================================
// assemble string from dict of items, save to file
-(void) saveToDocs
{
    NSString *output = @"";
    for (NSString* key in editDict)
    {
        NSDictionary *patchDict = editDict[key];
        // Form start of line record...
        NSString *line = [NSString stringWithFormat:@"%@>",key];
        int count = 0;
        for (NSString* pkey in patchDict) // now add each edit item to this line
        {
            NSString *value = patchDict[pkey];
            NSString *comma = @"";
            if (count > 0) comma = @",";
            line = [line stringByAppendingFormat:@"%@%@:%@",comma,pkey,value];
            count++;
        }
        output = [output stringByAppendingFormat:@"%@\n",line];
    }
    //NSLog(@" write to %@",docPath);
    [output writeToFile: docPath atomically: NO];
} //end saveToDocs

//======<edits>========================================================
// add a new edited value to save for given patch
-(void) addEdit : (NSString *) patchName :(NSString *) paramName : (NSString *) value
{
    if (paramName == nil || patchName == nil) return;  //5/15 add nil checks
    BOOL newDict = FALSE;
    //NSLog(@" addedit %@ : %@ : %@",patchName,paramName,value);
    NSMutableDictionary *d = [editDict objectForKey:patchName];
    if (d == nil) //Nothing? Create new dict!
    {
        newDict = TRUE;
        d = [[NSMutableDictionary alloc] init];
    }
    [d setObject:value forKey:paramName.lowercaseString];
    if (newDict) [editDict setObject:d forKey:patchName];
} //end addEdit

// 8/12/21 oogie2D Version: PULL THIS, wrong oogieVoice definition here!
//======<edits>========================================================
//-(void) applyEditsToVoice : (NSString *) patchName : (oogieVoice*) ov
//{
//    NSMutableDictionary *d = [editDict objectForKey:patchName];
//    if (d != nil) //Found?
//    {
//        for (NSString* pkey in d) // for each edit, set voice param
//        {
//            //NSLog(@" applyedit [%@] : %@",pkey,[d objectForKey : pkey]);
//            [ov setParamFromString : pkey : [d objectForKey : pkey]];
//        }
//    }
//}

//======<edits>========================================================
// 9/8 just get rid of edits for one patch...
-(void) removeAllEdits : (NSString *) patchName
{
    if (patchName == nil)
    {
        NSLog(@" ERROR REMOVE ALL EDITS!");
        return;
    }
    NSMutableDictionary *d = [editDict objectForKey:patchName];
    if (d == nil) return; //bail on fail
    [d removeAllObjects]; //Found? clear!
    [self saveToDocs];                  //update storage
} //end removeAllEdits

//======<edits>========================================================
// remove an edited value for a patch...
-(void) removeEdit : (NSString *) patchName :(NSString *) paramName
{
    if (patchName == nil || paramName == nil)
    {
        NSLog(@" ERROR REMOVE EDIT!");
        return;
    }
    NSMutableDictionary *d = [editDict objectForKey:patchName];
    if (d != nil) //Found?
    {
        [d removeObjectForKey:paramName.lowercaseString]; //clobber entry
    }
}

//======<edits>========================================================
// get edit keys for a patch...
-(NSArray *) getEditKeys : (NSString *) patchName
{
    NSMutableDictionary *d = [editDict objectForKey:patchName];
    if (d == nil) return @[]; //Nothing? return empty array 4/26
    return [d allKeys];
}

//======<edits>========================================================
-(NSString*) getValueForKey : (NSString *)patchName : (NSString *) key
{
    NSMutableDictionary *d = [editDict objectForKey:patchName];
    if (d == nil) return @""; //Nothing? empty return
    return d[key];
}


//======<edits>========================================================
// 7/8
-(BOOL) wasEdited : (NSString*) patchName
{
    NSMutableDictionary *d = [editDict objectForKey:patchName];
    if (d == nil) return FALSE;
    if ([d count] == 0) return FALSE; //may just have a patchName w/ no edits!
    return TRUE;
}


@end
