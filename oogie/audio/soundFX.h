//
//                             _ _______  __
//   ___  ___  _   _ _ __   __| |  ___\ \/ /
//  / __|/ _ \| | | | '_ \ / _` | |_   \  /
//  \__ \ (_) | |_| | | | | (_| |  _|  /  \
//  |___/\___/ \__,_|_| |_|\__,_|_|   /_/\_\
//
//
//  soundFX: encapsulates synth and audio buffer objects...
//  Created by dave scruton on 3/2/16
//  Copyright (C) fractallonomy, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AudioBufferPlayer.h"
#import "SynthDave.h"
#import "GMidi.h"
@protocol sfxDelegate;

#define NUM_ANALSESSION_INTS    32
#define NUM_ANALSESSION_DOUBLES 16

#define MAX_SOUNDFILES 64

@interface soundFX : NSObject <AudioBufferPlayerDelegate>
{
    //Synth/SFX is managed by top VC, is it smarter to put in AppDelegate?
    NSLock* synthLock;
    float sampleRate;
    AudioBufferPlayer* player;
    Synth* synth;
    NSString *soundFileNames[MAX_SOUNDFILES];
    BOOL soundFileLoaded[MAX_SOUNDFILES];
    int soundFileCount;
    UIColor *puzzleColors[36]; //CLugey! needs puzzle colors
    
    //DHS 9/21 Sample Offsets (percussion, general Midi, etc..._)
    int PSampleOffset;
    int GMSampleOffset;
    
    //Lookup dictionaries for samples by category 9/22
    NSMutableDictionary <NSString *,NSNumber *> *percBufferDict; 
    NSMutableDictionary <NSString *,NSNumber *> *percMidiKeyDict;
    NSMutableDictionary <NSString *,NSNumber *> *GMBufferDict;
    NSMutableDictionary <NSString *,NSString *> *GMNamesDict;
}
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) double soundRandKey;
@property (nonatomic, unsafe_unretained) id <sfxDelegate> delegate; // receiver of completion messages



+ (id)sharedInstance;
-(void) loadAudio;
-(void) loadAudioBKGD : (int) immediateSampleNum;
-(void) loadAudioBKGDForOOGIE : (int) immediateSampleNum;
-(void) loadAudioForOOGIE;
-(NSMutableDictionary*) loadGeneralMidiNames;
-(void) copyBuffer : (int) from : (int) to : (BOOL) clear;
-(void) copyEnvelope : (int) from : (int) to;

- (void) dumpBuffer : (int) which : (int) dsize;

-(void) glintmusic : (int) whichizzit : (int) psx;
-(NSString*) getGMName : (int) buffer;
-(NSArray *) getEnvelopeForDisplay: (int) which : (int) size;
-(int) getPercussionTriggerKey : (NSString *)name;
-(int) getPercussionBuffer     : (NSString *)name;
-(int) getGMBuffer     : (NSString *)name;
-(int) getWorkBuffer;
-(NSArray*) getGMBufferNames;
-(NSArray*) getPercussionBufferNames;
- (void)makePercSound : (int) which : (int) note; //DHS 9/22 test

- (void) makeTicSoundWithXY : (int) which : (int) x : (int) y;
- (void) makeTicSoundWithPitchandLevel : (int) which : (int) ppitch : (int) level;
- (void) makeTicSoundWithPitchandLevelandPan : (int) which : (int) ppitch : (int) level : (int) pan;
- (void) makeTicSoundWithPitch : (int) which : (int) pitch;
- (void) muzak : (int)which : (int) mtimeoff;
- (void) releaseAllNotesByWaveNum : (int) which;
- (void)releaseAllNotes;
- (void) setSoundFileName : (int) index : (NSString *)sfname;
- (void) setMasterLevel : (float) level;
- (void) setPan : (int) pan;
- (void) setPuzzleColor : (int) index : (UIColor *)color;
- (void) swapPuzzleColors : (int) pfrom : (int) pto;


//DHS 3/10
- (void) start;
- (void) stop;

//DHS 2019: Synth convenience functions, for oogie/swift
- (void)buildEnvelope:(int)a1 : (BOOL) a2;
-(void) buildaWaveTable : (int) a1 : (int) a2;
-(int)  getSynthNoteCount;
-(int)  getSynthUniqueCount;
-(int)  makeSureNoteisInKey : (int) a1 : (int) a2;
-(void) playNote : (int) a1 : (int) a2 : (int) a3;
-(void) queueNote : (int) a1 : (int) a2 : (int) a3;
-(void) releaseNote : (int) a1 : (int) a2;
-(void) setSynthAttack : (int) a1;
-(void) setSynthDecay : (int) a1;
-(void) setSynthDetune : (int) a1;
-(void) setSynthDuty : (int) a1;
-(void) setSynthGain : (int) a1;
-(void) setSynthMasterLevel : (int) a1;
-(void) setSynthMasterTune : (int) a1;
-(void) setSynthMIDI : (int) a1 : (int) a2;
-(void) setSynthMidiOn : (int) a1 : (int) a2;
-(void) setSynthMono : (int) a1;
-(void) setSynthMonoUN : (int) a1;
-(void) setSynthNeedToMailAudioFile : (int) a1;
-(void) setSynthNeedsEnvelope : (int) which : (BOOL) onoff; //10/17

-(void) setSynthPan : (int) a1;
-(void) setSynthPoly : (int) a1;
-(void) setSynthPortamento : (int) a1;
-(void) setSynthRelease : (int) a1;
-(void) setSynthSampOffset : (int) a1;
-(void) setSynthSustain : (int) a1;
-(void) setSynthSustainL : (int) a1;
-(void) setSynthWaveNum : (int) a1;

-(void) loadAudioToBuffer : (NSString*)name : (int) whichBuffer;


@end


@protocol sfxDelegate <NSObject>
@optional
-(void) didLoadSFX;
@end


