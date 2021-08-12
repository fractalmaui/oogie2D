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
#define NO_OOGIE_2D
#ifdef OOGIE_2D
#import "GMidi.h"
#endif
@protocol sfxDelegate;

#define NUM_ANALSESSION_INTS    32
#define NUM_ANALSESSION_DOUBLES 16
#define LOAD_SAMPLE_OFFSET 32   //9/25 new value: load all samples above HERE

//Absolute max for samples! must be large enuf for add-ons and full GM percussion!
#define MAX_SOUNDFILES 1024

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
// 3/27/21 no need -(void) loadAudioBKGDForOOGIE : (int) immediateSampleNum;
// 4/16 obsolete -(void) loadAudioForOOGIE;
-(NSArray *) loadSamplesNow : (NSString*)pname : (int) sampleBase;
-(NSMutableDictionary*) loadGeneralMidiNames;
-(void) copyBuffer : (int) from : (int) to : (BOOL) clear;
-(void) copyEnvelope : (int) from : (int) to;
- (void)cleanupBuffersAbove:(int)index;

- (void) dumpBuffer : (int) which : (int) dsize;
- (float)getLVolume ;
- (float)getRVolume ;
- (int)getBufferSize: (int) index;
- (float)getBufferPlaytime: (int) index;

-(int) getSampleRate : (NSString*)name : (int) type;
-(void) glintmusic : (int) whichizzit : (int) psx;
-(NSString*) getGMName : (int) buffer;
-(NSArray *) getEnvelopeForDisplay: (int) which : (int) size;
-(int) getEnvelopeSize : (int) which;
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
- (void)releaseAllLoopedNotes;
- (void)releaseAllNonLoopedNotes;

- (void) setSoundFileName : (int) index : (NSString *)sfname;
- (NSString*) getSoundFileName : (int) index;
- (void) setMasterLevel : (float) level;
- (void) setPan : (int) pan;
- (void)setPortamentoLastNote: (int)lastnote;
- (void) setPuzzleColor : (int) index : (UIColor *)color;
- (void) swapPuzzleColors : (int) pfrom : (int) pto;

-(void) testDump;


//DHS 3/10
- (void) start;
- (void) stop;

//DHS 2019: Synth convenience functions, for oogie/swift
- (void)buildEnvelope:(int)a1 : (BOOL) a2;
-(void) buildaWaveTable : (int) a1 : (int) a2;
- (NSDictionary*) getSampleHeader:(NSString *)soundFilePath;
-(int)  getSynthNoteCount;
-(int)  getSynthUniqueCount;
-(int)  getSynthLastToneHandle;
-(float)  getSynthSampleProgressAsPercent : (int) a1 : (int) a2;

-(int)  makeSureNoteisInKey : (int) a1 : (int) a2;
-(void) playNote : (int) a1 : (int) a2 : (int) a3;
-(void) playNoteWithDelay : (int) a1 : (int) a2 : (int) a3 : (int) a4;
-(void) releaseNote : (int) a1 : (int) a2;
-(void) setSynthAttack : (int) a1;
-(void) setSynthDecay : (int) a1;
-(void) setSynthDetune : (int) a1;
-(void) setSynthDuty : (int) a1;
-(void) setSynthInfinite : (int) a1; // 6/23/21
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
-(void) setSynthToneGainByHandle : (int) handle : (int) newGain; //6/25/21

-(void) setSynthWaveNum : (int) a1;
// 7/17 vibrato support
- (void) setSynthVibAmpl:  (int) newVal;
- (void) setSynthVibWave:  (int) newVal;
- (void) setSynthVibSpeed: (int) newVal;
- (void) setSynthVibDelay: (int) newVal;
- (void) setSynthVibeAmpl:  (int) newVal; //4/8 new amplitude vibe
- (void) setSynthVibeWave:  (int) newVal;
- (void) setSynthVibeSpeed: (int) newVal;
- (void) setSynthVibeDelay: (int) newVal;

//3/2/21 internal synth digital delay
-(void) setSynthDelayVars : (int)a1 : (int)a2 : (int)a3;
-(void) synthDelaySend : (float)a1 : (float) a2;
-(float) synthDelayReturnLorRWithAutoIncrement;

// 2/12/21 fine tune support
-(void) setSynthPLevel : (int) a1; //patch level
-(void) setSynthPKeyOffset : (int) a1;
-(void) setSynthPKeyDetune : (int) a1;

// 6/21 hand down to synth
-(void)startRecording:(int)maxRecordingTime;
-(void)stopRecording:(int)cancel;
-(void) pauseRecording;
-(void) unpauseRecording;
-(NSString *)getAudioOutputFileName;
-(NSString *)getAudioOutputFullPath;
-(void) setRecordingFolder : (NSString *) fname;

-(void) loadAudioToBuffer : (NSString*)name : (int) whichBuffer;
-(void) setNoteOffset: (int) which : (NSString*) fname; //10/6


@end


@protocol sfxDelegate <NSObject>
@optional
-(void) didLoadSFX;
@end


