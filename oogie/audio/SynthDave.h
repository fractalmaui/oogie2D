//
//    ____              _   _     ____                  
//   / ___| _   _ _ __ | |_| |__ |  _ \  __ ___   _____ 
//   \___ \| | | | '_ \| __| '_ \| | | |/ _` \ \ / / _ \
//    ___) | |_| | | | | |_| | | | |_| | (_| |\ V /  __/
//   |____/ \__, |_| |_|\__|_| |_|____/ \__,_| \_/ \___|
//           |___/                                      
//				 
// SynthDave: Polyphone synth AND sample player...
// First built April 2011; reworked in June!
// DHS April 14 2012: add harmony voice : synth 3-way harmony...
// DHS 1/8/13: Added enums for keysigs
// DHS 1/17/13 Added PERCKIT_VOICE type
// DHS 2/13: Add port. vars, add recording vars.
// DHS 5/10/13: Add new param, timetrax
// DHS 5/20/13: Add MIDI support
// OOGIECAM VERSION:
//  DHS 8/9/13: First Release? WOW! Within a week from inception!
// DHS 1/23/14: ARC-based version for RoadieTrip
// DHS 10/17/19 add envelope support for samples
// DHS 11/9     add copyBuffer
// DHS 11/22    add getSRate
// 9/16 2020: start adding harmonyVoice, make it an on/off flag!
//              all voices can be harmony as needed!
// 9/25 Re-partition samples: 0..31 = work area (including vibrato waves)
//                            32..end = loaded samples area...
// 1/26  redid arpQueue, enlarged, made doubles, changed time calculations
// 3/2   add digital delay
// 6/25/21 add arpTones, redo arpeggiator data struct
// 11/23/21 add env256 array, render all envelopes into 256 buffer
// 11/25    remove old envelope crap
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioFile.h>
#import <Foundation/Foundation.h>

#define MAX_TONE_EVENTS 256   //10/27 was 64

//Possible states for a ToneEvent.
typedef enum
{
	STATE_INACTIVE = 0,    ///< ToneEvent is not used for playing a tone
	STATE_PRESSED = 1,     ///< ToneEvent is still playing normally
	STATE_SUSTAINED = 2,   ///< ToneEvent is at sustain level...
	STATE_RELEASED = 3,    ///< ToneEvent is released and ringing out
    STATE_MONOFADEOUT = 4, ///< Used in MONO voicemode: Fade voice out ASAP
}
ToneEventState;


typedef enum
{
	WAVE_SINE   = 0,  // Sine Wave (original code)
	WAVE_SAW    = 1,  // Sawtooth Wave
	WAVE_SQUARE = 2,  // Square Wave (need duty cycle??)
	WAVE_RAMP   = 3,  // Ramp Wave
	WAVE_NOISE  = 4,  // Noise Wave (Repeats, not really noise??)
}
ToneWaves;

typedef enum
{
	KEY_MAJOR       = 0,   
	KEY_MINOR       = 1,   
	KEY_LYDIAN      = 2,   
	KEY_PHRYGIAN    = 3,   
	KEY_MIXOLYDIAN  = 4,   
	KEY_LOCRIAN     = 0,   
	KEY_EGYPTIAN    = 0,   
	KEY_HUNGARIAN   = 0,   
	KEY_ALGERIAN    = 0,   
	KEY_JAPANESE    = 0,   
	KEY_CHINESE     = 0,   
	KEY_CHROMATIC   = 0,   
}
ToneKeysigs;

#define MAJOR_KEY 0
#define MINOR_KEY 1
#define LYDIAN_KEY 2
#define PHRYGIAN_KEY 3
#define MIXOLYDIAN_KEY 4
#define LOCRIAN_KEY 5
#define EGYPTIAN_KEY 6
#define HUNGARIAN_KEY 7
#define ALGERIAN_KEY 8
#define JAPANESE_KEY 9
#define CHINESE_KEY 10
#define CHROMATIC_KEY 11



//arpeggiator stuff:
#define ARP_PARAM_NOTE 0
#define ARP_PARAM_WNUM 1
#define ARP_PARAM_TYPE 2
#define ARP_PARAM_GAIN 3
#define ARP_PARAM_MONO 4
#define ARP_PARAM_LPAN 5
#define ARP_PARAM_RPAN 6
#define ARP_PARAM_TIME 7

#define MIDI_MIDDLE_C 60 //2/26/20 This is proper middle C, NOT 64!

// Describes a tone.
typedef struct
{
	ToneEventState state;   ///< the state of the tone
	int midiNote;           ///< the MIDI note number of the tone
    float pitch;            //usually constant, changes during portamento...
	float phase;            ///< current step for the oscillator
	int envAttack;          //  ADSR Support...
	int envDecay;           //  ADSR Support... 
	int envSustain;         //  ADSR Support...
	int envRelease;         //  ADSR Support...
    int toneType;           //  Synth/Perc/etc
    int waveNum;            //  Ranp sine etc
    int mono;               //  Monophonic Synth/Sample mode... 0 by default
	int detune;             //  Samples only: 0=NO pitch shift, 1=pitchshift
	double envStep;          ///< for stepping through the envelope
    double envDelta;         ///< how fast we're stepping through the envelope
	float gain;             ///<   note loudness
	float lpan;             ///<   lpan  0.0 to 1.0
	float rpan;             ///<   ppan  0.0 to 1.0
    int portamentoLastNote; // 6/26
    float portamentoTime;
    float portamentoPitchFinish; // end portamento tone
    float portamentoPitchStep;   // teeny stepsize to increase port freq
    int  vibAmpl;    //7/17 vibrato externals
    int  vibWave;
    int  vibSpeed;
    int  vibDelay;    //TBD
    float vibIndex;
    float vibStep;
    BOOL vibEnabled; //7/17 internal vib vars
    int  vibeAmpl;    //4/8 amplitude vibe
    int  vibeWave;
    int  vibeSpeed;
    int  vibeDelay;    //TBD
    float vibeIndex;
    float vibeStep;
    BOOL vibeEnabled; //7/17 internal vib vars
    int timetrax;
    int portcount;
    int un;
    int infinite;           //Synth ONLY, holds note forever...
    BOOL needsEnvelope;     // 10/17 for sample envelopes
    float envelope256[256];   //11/23/21 all tones have their own envelope now!!
}
ToneEvent;

//Synth AND sampler is in one object....
#define MAX_SAMPLES 1024 //5/10/21 had to enlarge yet again!
#define MAX_QUEUE 32  //queue size for notes played between quant steps
#define MAX_ARP 8192  //2/26/21 enlarge arpeggiator size...
#define MAX_ARP_BUCKETS 16 //number of buckets in each arp note storage
@interface Synth : NSObject
{
    float masterTune;   //DHS 1/11/13 new overall tuning, +/- .5 semitone
    float masterLevel;
	float sampleRate;   ///< output will be generated for this sample rate
    int lastSampleRate;    //sample rate from last file read in
    int newUnique;
	int midiDev,midiChan;   //MIDI output support, midiDev=0 means MIDI OFF
	float finalMixGain;    // Final total output volume...
    float aFactor,bFactor;   //used in sin/cos mixed waves
	float *sBufs[MAX_SAMPLES];       // First five bufs are canned synth waves, rest are samples....
    float env512[512];      //11/23 work areas, used to produce 256 item envelopss
    float env256[256];
    double env256Step;      //converts from time -> envelope units, always less than 1,0
    int sRates[MAX_SAMPLES];         // 10/5/2019 keep track of sample rates
	int sBufLens[MAX_SAMPLES];
	int sBufChans[MAX_SAMPLES];      //1 = mono, 2=stereo
    int sTuningOffsets[MAX_SAMPLES];    //10.6 single note offsets, for GM tuning
	int sineLength;                  ///< size of sine look-up table
	int detune;         ///< overall detune flag...
    //Last ADSR length
    int attackLength, decayLength , sustainLength, releaseLength;
    //Delay section 3/2/21
    float *delayBuf;
    int dwptr,drptr; //read/write delay pointers
    
	ToneEvent tones[MAX_TONE_EVENTS];
    int lastToneHandle; // 6/25/21 points to most recently played note
    int queuePtr,arpPtr;
    int arpPlayPtr;
    float noteQueue[MAX_ARP][MAX_QUEUE];
    double arpQueue[MAX_ARP][MAX_ARP_BUCKETS];   //Arpeggiator: just holds time now, note data is in arpTones
    ToneEvent arpTones[MAX_ARP]; //6/25/21
	/// fundamental frequencies for all MIDI note numbers
	float pitches[256];
    int numPVoices;
    int numSVoices;
    float glpan,grpan; //temp pan settings: call setPan right before playnote!
    int portamentoLastNote; // 6/26
    float portamentoTime;  // 6/26
    int  vibAmpl;    //7/17 vibrato externals
    int  vibWave;
    int  vibSpeed;
    int  vibDelay;
    int  vibeAmpl;    //4/8 amplitude vibe
    int  vibeWave;
    int  vibeSpeed;
    int  vibeDelay;
    int pLevel,pKeyOffset,pKeyDetune; //2/12/21 fine tuning
    int timetrax;
    int recording,reclength,recptr,recsize;
    int needToMailAudioFile;
    int infinite;           //Synth ONLY, holds note forever...
    NSString *recFileName;
    NSString *recFileFullPath;
    double arpTime;
    NSTimer *arptimer;
    //6/22/20
    int recordfileIndex; //used to name output recordings
    
    // 3/2/21 digital delay
    int delayTime,delaySustain,delayMix;
    int delayBufSize;
}

#define NULL_VOICE -1
#define SYNTH_VOICE 0
#define PERCUSSION_VOICE 1
#define PERCKIT_VOICE 2
#define SAMPLE_VOICE 3
#define SPLITSAMPLE_VOICE 4   //11/2
#define HARMONY_VOICE 8  //9/16: bit 8 indicates harmony
#define HARMONY_MASK 255 //9/16: bits 0-7
#define MIDITRACK_VOICE 5
#define SYNTHA_DEFAULT			4.0;
#define SYNTHD_DEFAULT			2.0;
#define SYNTHS_DEFAULT			20.0;
#define SYNTHSL_DEFAULT			40.0;
#define SYNTHR_DEFAULT			20.0;
#define SYNTHDUTY_DEFAULT		50.0;

#define MAX_DELAY_SECONDS 2

@property (nonatomic, assign) float gain;
@property (nonatomic, assign) int mono;
@property (nonatomic, assign) int poly;
@property (nonatomic, weak) NSString *recFileFolder;
@property (nonatomic, assign) float recGain;

-(void) copyBufferOutResampled : (int) bnum : (int)fsize : (float*) fbuf; //7/7/21
-(void) copyBuffer : (int) from : (int) to : (BOOL) clear;

-(void)startRecording:(int)maxRecordingTime;
-(void)stopRecording:(int)cancel;
-(void) pauseRecording;
-(void) unpauseRecording;

//4/2/21 no need - (void)writeOutputSampleFile:(NSString *)name :(NSString *)type;
 
// Initializes the Synth.
- (id)initWithSampleRate:(float)sampleRate;
- (int)getNeedToMailAudioFile; 
- (void)setNeedToMailAudioFile:(int)n;
-(int) getSRate : (int) bptr;
- (int)getSVoiceCount ;
- (int)getPVoiceCount ;
- (float)getLVolume ;
- (float)getRVolume ;
-(NSString *)getAudioOutputFileName;
-(NSString *)getAudioOutputFullPath;
-(float) getSampleProgressAsPercent : (int) n : (int) buf;

//DHS set master tune
- (void)setMasterTune:(int)nt;
- (void)setMasterLevel:(float)nl;
- (void)equalTemperament;
- (void)resetArp;
// Schedules a new note for playing.
//* If there are no more open slots (i.e. the polyphony limit is reached), then 
//* this new note is simply ignored.
// UMM type is synth voice #??? sample #??
- (void)playNote:(int)midiNote :(int)wnum :(int)type;
- (void)playNoteWithDelay:(int)midiNote : (int) wnum : (int) type : (int) delayms;
- (void)playPitchedNote:(float)pitch :(int)wnum;
- (void)emptyQueue;

//  Releases a note that is currently playing.
// If more than one tone with the corresponding MIDI note number is playing, 
//  they will all be released.

- (int)makeSureNoteisInKey: (int) wkey : (int) note;

- (int)clearBuffer:(void*)buffer frames:(int)frames;
- (int)fillBuffer:(void*)buffer frames:(int)frames;
- (void)buildEnvelope:(int)which : (BOOL) buildInPlace;
-(void) dumpEnvelope: (int) which;

- (void)buildaWaveTable: (int) which :(int) type;
- (void)buildSampleTable:(int) which;
- (void)buildRampTable: (int) which;
- (void)buildSineTable: (int) which;
- (void)buildNoiseTable: (int) which;
- (void)buildSawTable: (int) which;
- (void)buildSquareTable: (int) which;
- (void)cleanupNotes:(int)which;
- (void)cleanupBuffersAbove:(int)index;
- (void)decrVoiceCount:(int)n;
- (int)getBufferChans: (int) index;   //7/7
- (int)getBufferSize: (int) index;
- (float)getBufferPlaytime: (int) index;
- (int)getNoteCount;
- (NSDictionary*) getSampleHeader:(NSString *)soundFilePath;
- (int)getUniqueCount;
- (int) getLastToneHandle; //6/25/21

- (void)incrVoiceCount:(int)n;
- (void)setMonoUN: (int)un ;
- (void)releaseAllNotes;
- (void)releaseAllLoopedNotes;
- (void)releaseAllNonLoopedNotes;
- (void)releaseNoteByBin:(int)n;
- (void)releaseAllNotesByWaveNum:(int)wn  ;
- (void)releaseNote:(int)midiNote :(int)wnum;
- (void)setInfinite:(int)n;
- (void)setPan: (int)newPanInt ;
- (void)setPortamento: (int)pn ;
- (void)setPortamentoLastNote: (int)lastnote ;
- (void)setAttack: (int)newVal ;
- (void)setDecay: (int)newVal ;
- (void)setSustain: (int)newVal; 
- (void)setSustainL: (int)newVal; 
- (void)setRelease: (int)newVal ;
- (void)setDuty: (int)newVal ;
- (void)setSampOffset : (int)percent; 
- (void)setDetune: (int)newVal ;
- (void)setTimetrax: (int)newVal ;
- (void) setToneGainByHandle : (int) handle : (int) newGain;
- (void)setMIDI: (int)mdev :(int)mchan;
- (void) setNeedsEnvelope : (int) which : (BOOL) onoff; //10/17
- (void)setMidiOn: (int)onoff ;
- (int) getMidiOn;  
- (void) setWaveNum:  (int) wnum;
- (void) setVibAmpl:  (int) newVal;
- (void) setVibWave:  (int) newVal;
- (void) setVibSpeed: (int) newVal;
- (void) setVibDelay: (int) newVal;
- (void) setVibeAmpl:  (int) newVal;
- (void) setVibeWave:  (int) newVal;
- (void) setVibeSpeed: (int) newVal;
- (void) setVibeDelay: (int) newVal;
- (void) setNoteOffset: (int) which : (NSString*) fname;
//2/12/21 fine tuning
-(void) setPLevel     : (int) a1; //patch level
-(void) setPKeyOffset : (int) a1;
-(void) setPKeyDetune : (int) a1;

-(void) setDelayVars : (int)dtime : (int)dsustain : (int)dmix;
-(void) delaySend : (float)ml : (float) mr;
-(float) delayReturnLorRWithAutoIncrement;



- (void)loadSample:(NSString *)name :(NSString *)type ;
- (void)loadSampleFromPath : (NSString *)subFolder : (NSString *)fileName;
- (void) dumpBuffer : (int) which : (int) dsize;

-(void) doogitie  : (NSString *)name : (int) whichBuffer;

-(void) testDump;

@end
