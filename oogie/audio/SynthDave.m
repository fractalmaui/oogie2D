//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// NOTE: This is the OOGIE-2 (OOGIETWOOGIE) version of SynthDave!
//         It is no longer campatible with OOGIE, at the very least it should 
//           be used with CAUTION with older OOGIE stuff....
//
//    ____              _   _     ____                  
//   / ___| _   _ _ __ | |_| |__ |  _ \  __ ___   _____ 
//   \___ \| | | | '_ \| __| '_ \| | | |/ _` \ \ / / _ \
//    ___) | |_| | | | | |_| | | | |_| | (_| |\ V /  __/
//   |____/ \__, |_| |_|\__|_| |_|____/ \__,_| \_/ \___|
//           |___/                                      
//				 
//  product number: 495032459
// HUEDOKU VERSION:
//  DHS 11/27/14: Force load all samples as stereo.
//                Still need to change fillbuffer: CRASHED first try! .....Pulled mono switching from fillbuffer
// DHS 3/16/15:  Added playNoteWithDelay...
//                Changed queue dims!
// DHS 11/12     removed * in AudioFileID fileID declaration
//               replaced AudioFileReadPackets with AudioFileReadPacketData
// DHS 4/18/12:  For some reason RECORDING WAS on all the time! Disabled!
// DHS 7/24/19   CHECK FOR CHANGES SINCE 2012!!!
//               start adding properties: gain: float, more to come
// DHS 9/24      prevent crash on zero envelope params
// DHS 10/5      add sRates table, support for multiple sample rates
// DHS 10/6      fix bug in fillBuffer, use buffer type to determine synth buffer
//                 wraparound as opposed to assuming synths occupy low 8 buffers exclusively
// DHS 10/17     add support for sample envelopes
// DHS 11/9      add buildInPlace arg to buildEnvelope, copyBuffer, copyEnvelope
//     4/12/20   just malloc swave ONCE
//     6/25      change mono fadeout to 95% attenuation, 2% bailout
//                 dividing portamento pitch step by 500x seems to work! (parameterize this?)
//     7/17      add vibrato support
//     7/28      reduce vibrato speed max
//     8/1       playNote, use sampleOffset as simple percent
//     8/2       added percussion to envelope-capable voices
//     8/17      changed vibrato wave base to 200 to support GM Perc
//                 THERE MUST BE A BETTER WAY!
//    9/16   Thinking about adding chordVoice, need to store note offsets,
//             what about using arpQueue???  only need to store 3 or 5 , 7 notes?
// 9/25 Re-partition samples: 0..31 = work area (including vibrato waves)
//                            32..end = loaded samples area...
//    10/8  add sTuningOffsets and setNoteOffset
//    10/31 add freeSampleMemory and cleanupBuffersAbove
//  2/12/21 add fineTuning
//  3/26    add dumpTone
//  3/29    HUH??add sanity check in fillBuffers, WTF w/ negative indices!
//  4/26    add midiNote clamp 0..128 in playNote
//  4/29    pull swave, use unsigned char fileBuffer, support 32 bit files too
//  4/30    getVibeLevel: input wave range 0..1 NOT -1..1!!
//          getVibOffset: input wave range MAKE -1..1 to center vib freq
//          also set DUTY to 0.5 when creating square vib waves, was random b4
// 5/10     enlarge sample space to 1024
// 5/19     add INV_SYNTH_TS
// 5/24     add envelope size check
// 6/21     comment out negative phase errs in fillbuffer
// 6/25     code cleanup during sample loop testing, add loadupToneFromSynth
//             add arpTones, redo arpeggiator data struct
// 6/26     pull queueNote, change playNoteWithDelay to append queue OR insert as needed
// 6/27     add more custom releaseNote... methods
#import <QuartzCore/CABase.h>
#import "SynthDave.h"
#include "oogieMidiStubs.h"
#include <time.h>
#include "cheat.h"

int midion = 1;

float ATTACK_TIME   = 0.004f;
float DECAY_TIME    = 0.002f;
float SUSTAIN_LEVEL = 0.8f;
float SUSTAIN_TIME  = 0.04f;
float RELEASE_TIME  = 0.05f;
float DUTY_TIME     = 0.5f;
float SAMPLE_OFFSET = 0.0f;

double *workBuffer; //9/20

#define DEFAULT_SAMPLE_RATE 44100

//Vibrato uses canned ramp/sine/saw/square waves, they are fixed ONCE and left alone...
//  ideally they should be near the top of the wave area!!
#define VIBRATO_WAVE_BASE 16  //9/25  was 200 now all work waves are below 32, this uses up 6 possible spots?

@interface Synth (Private)
- (void)equalTemperament;
@end

#define SYNTH_TS 500.0  // was 1000 Converts percentage synth params to real-time...
#define INV_SYNTH_TS 0.002
#define ATTACK_RELEASE_MULT 3.0
//several sets of 12-key lookup tables, used to convert
//  chromatic musical input so it sounds "in tune"...

int keysiglookups[] ={
	0,0,2,2,4,5,5,7,7,9,9,11,		// Major
	0,0,2,3,3,5,5,7,8,8,10,10,		// Minor
	0,0,2,2,4,6,6,7,7,9,9,11,		//Lydian
	0,1,1,4,4,5,7,7,8,8,10,10,		//Phrygian
	0,0,2,2,4,5,5,7,7,9,10,10,		//Mixolydian
	0,1,1,3,3,5,6,6,8,8,10,10,		//Locrian
	0,2,2,3,3,6,6,7,8,8,11,11,		//Egyptian
	0,1,1,4,4,5,5,7,8,8,11,11,		//Hungarian
	0,0,2,3,5,5,6,7,8,8,11,11,		//Algerian
	0,0,2,2,5,5,5,9,9,9,10,10,		//Japanese
	0,0,0,4,4,4,6,6,7,7,11,11,		//Chinese
	0,1,2,3,4,5,6,7,8,9,10,11,		//Chromatic
};

int uniqueVoiceCounter;   //set to 0, increments every time playnote is called...
int monoLastUnique;

double drand(double lo_range,double hi_range );
int gotSample,sampleSize;
//#define MAX_SAMPLE_SIZE 1655360   //canned for now, allocate later for multisamples
#define MAX_SAMPLE_SIZE 12000000   //HDK: new max size, allows for ambient bkgd music
unsigned char  *fileBuffer = NULL;  //4/29 for universal file work area
int fileBufferSize;     //4/29
int sPacketSize,sNumPackets,sChans;  //sample channels...

#define TWOBYTESAMPLERANGE 65535.0

float lvolbuf[16];
float rvolbuf[16];
int lrvolptr,lrvolmod;
AudioFileID WAVfileID;
int copyingBuffer;
int copyingEnvelope;

short *audioRecBuffer;

@implementation Synth



//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (id)initWithSampleRate:(float)sampleRate_
{
	int loop;
    //NSLog(@"  initWithSampleRate : %f",sampleRate_);
	if ((self = [super init]))
	{
		sampleRate          = (float)sampleRate_;
        //NSLog(@" init all, samplrate %f",sampleRate);
		_gain               = 0.59f; //OVERall gain factor
		finalMixGain        = 1.0;
		gotSample           = 0;
        //4/12/20 just alloc the WAV file storage buffer ONCE, max size
        fileBuffer = (unsigned char *)malloc(MAX_SAMPLE_SIZE*2);

        //MAX_SAMPLE_SIZE
        fileBufferSize      = 0;   //4/29
		glpan = grpan       = 0.5;  //set to center pan for now
        portamentoLastNote  = 0;    // 6/26 time = 0 means no portamento
        portamentoTime      = 0;       // 6/26
        uniqueVoiceCounter  = 0;
        monoLastUnique      = 0;
        masterLevel         = 1.0;
        masterTune          = 0; //6/8/21
        timetrax            = 0;
        queuePtr            = 0; //DHS 1/19 start with empty note queue
        arpPtr              = 0; //DHS 3/16/15: Arpeggiator...
        arpPlayPtr          = 0; //DHS 3/16/15: Arpeggiator...
        newUnique           = 0;
        aFactor             = 0.0f;
        bFactor             = 0.0f;
        vibAmpl             = 0; //7/17 no vibrato initially
        vibDelay            = 0; //UNUSED
        _recGain            = 0.8; //7/29 new
        recording = reclength = recptr = recsize = 0;
        copyingBuffer = copyingEnvelope = -1;
        //NSLog(@" null out audioRecBuffer...");
        audioRecBuffer = NULL;       
        recFileName = @"";
        recFileFullPath = @"";
        recordfileIndex = 0;  //6/22 for naming recording output files

        needToMailAudioFile=0;
		LOOPIT(MAX_SAMPLES)
		{
			sBufs[loop]		= NULL;
			sBufLens[loop]  = -1;
            sRates[loop]    = -1;
			sBufChans[loop] = -1;
            sTuningOffsets[loop] = 0; //10/6/20 for GM tuning
			sEnvs[loop]		= NULL;
            sElen[loop]     = 0;
            envIsUp[loop]   = 0;
            envLength[loop]   = 0;
            envDataLength[loop] = 0; //10/17
		}
		LOOPIT(MAX_TONE_EVENTS)tones[loop].state = STATE_INACTIVE;		

        //3/2/21 digital delay
        delayBuf = nil;
        dwptr = drptr = 0;
        [self initDigitalDelay];
        delayMix = delayTime = delaySustain = 0;
        
		[self equalTemperament];
		//OK get our wave setup and built
		sineLength = 2 * (int)sampleRate;
		[self buildaWaveTable: 0:1];
        //DHS 11/20: Seed our random generator w/ current time
        srand((unsigned int)time(NULL));
        numSVoices = 0;
        numPVoices = 0;
        
        //9/20 work buffer
        workBuffer = (double *) malloc(1024 * 1024 * 3 * sizeof(double));
        
        LOOPIT(16) lvolbuf[loop]=0.0;
        LOOPIT(16) rvolbuf[loop]=0.0;
        lrvolptr=lrvolmod=0;
 
        // 2/26 try calling directly from fillBuffer instead...
        //3/15 test, arp gets called from fillBuffer instead
//        arptimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self
//                  selector:@selector(arptimerTick:) userInfo:nil repeats:YES];

        //Vibrato test, use buffer 99 for vibrato sine wave...
        DUTY_TIME = 0.5; //4/30 canned 50/50 square wave for vibrato
        
        for (int i=0;i<4;i++)
           [self buildaWaveTable:VIBRATO_WAVE_BASE+i :i];  //lets use buffer 1 for vibrato??
	}
	return self;
} //end initWithSampleRate

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
-(void) testDump
{

    //DUMP SOME WAVES
    for (int i=0;i<256;i++)
    {
        float tval = 999.0;
        if (sBufs[i] != nil) tval = sBufs[i][32];
//        if (sBufLens[i] > 0) NSLog(@" buflen[%d] %d test %f",i,sBufLens[i],tval);
    }

}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)dealloc
{
	int loop;
    NSLog(@" dealloc: Free all");
    fileBufferSize = 0;    //4/29
    LOOPIT(MAX_SAMPLES) [self freeSampleMemory:loop];
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 10/31 used in dealloc and cleanupBuffersAbove,
//  seeing a krash caused by this somehow?
//  I think it is the synth trying to play a note from a deleted buffer!
-(void) freeSampleMemory:(int) index
{
    if (sBufs[index] != NULL)
    {
        free(sBufs[index]);
        sBufs[index] = NULL;
    }
    if (sEnvs[index] != NULL)
    {
        free(sEnvs[index]);
        sEnvs[index] = NULL;
        sElen[index] = 0;
    }
} //end freeSampleMemory

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 3/15/21
- (void)arptimerTick:(NSTimer *)timer
{
    [self arpUpdate];
}


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 3/15/21
- (void)arpUpdate
{
    //NSLog(@" arpptrs %d vs %d",arpPlayPtr ,arpPtr);
    if (arpPlayPtr != arpPtr)  //IS there some stuff to play?
    {
        double latestTime  = CACurrentMediaTime();
        double latestdelay = arpQueue[arpPlayPtr][ARP_PARAM_TIME]; //6/26 indices were bkgds
        if (latestTime >= latestdelay) //Time to play!
        {
            [self playNoteFromTone : arpTones[arpPlayPtr]]; //6/25/21 play from set of stored tones
            arpPlayPtr++;
            if (arpPlayPtr >= MAX_ARP)  arpPlayPtr = 0;   //6/26/21 wups! Wraparound!
            arpTime  = latestTime;
        }
    }
} //end arpUpdate

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// sets a range of plus/minus one-half semitone
- (void)setMasterTune:(int)nt;
{
    masterTune = (float)nt/10.0;
} //end setMasterTune

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// sets a range of plus/minus one-half semitone
- (void)setMasterLevel:(float)nl;
{
    masterLevel = nl;
    //NSLog(@" synth set master level %f",nl);
} //end setMasterLevel

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
//  OK: assume A4 on musical keyboard is at 440Hz.
//    this then builds a set of pitches based on
//    12-semitone equitonal octaves......
- (void)equalTemperament
{
    //NSLog(@"Synth: set equalTemperament, tune %f",masterTune);
    float internalOffset = 68.0;
//    float internalOffset = 69.0;
    for (int n = 0; n < 256; ++n)
    {
        pitches[n] = 440.0f * powf(2, ((float)n + masterTune - internalOffset)/12.0f);  // A4 = MIDI key 69
        //NSLog(@" note[%d] pitch [%f]",n,pitches[n]);
    }

    //pitches[n] = 440.0f * powf(2, (n - 69)/12.0f);  // A4 = MIDI key 69

}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// builds one of 'which' waves: Ramp,Sine, Saw, Square  ...+??
// Wave gets stored in the sBuf sample buffer, indexed by which
- (void)buildaWaveTable: (int) which :(int) type
{
	//int loop;
	if (sBufs[which] != NULL) //already got sumthin??? 
	{
        [self cleanupNotes:which];
         free(sBufs[which]);
        sBufs[which] = NULL;
	}
    //10/16/20 redid case statements, were WRONG
	switch(type)
	{
		case WAVE_RAMP: [self buildRampTable:which];
			break;
		case WAVE_SINE: [self buildSineTable:which];
			break;
		case WAVE_SAW: [self buildSawTable:which];
			break;
		case WAVE_SQUARE: [self buildSquareTable:which];
			break;
        case WAVE_NOISE: [self buildNoiseTable:which];
			break;
        default: [self buildRampTable:which];
			break;
	}
    sRates[which]   = DEFAULT_SAMPLE_RATE;  //10/5 is this right? or is it 11025?

	//if(0) for(int i=0;i<sineLength;i+=256)
	// 	NSLog(@" wav[%d] %f",i,sBufs[which][i]);
			
	// NSLog(@"  bwte %d",which);
	return;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)buildNoiseTable: (int) which
{
	sBufs[which] = malloc(sineLength * sizeof(float));
	if (!sBufs[which]) return;
	for (int i = 0; i < sineLength; i++) //one wavelength for the ramp, k?
		sBufs[which][i] = (float)drand(0.0,1.0 );
	sBufLens[which] = sineLength;
	sBufChans[which] = 1;
	return;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)buildRampTable: (int) which
{
	sBufs[which] = malloc(sineLength * sizeof(float));
	if (!sBufs[which]) return;
	for (int i = 0; i < sineLength; i++) //one wavelength for the ramp, k?
		sBufs[which][i] = (float)i / sineLength;
	sBufLens[which] = sineLength;
	sBufChans[which] = 1;
	return;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)buildSawTable: (int) which
{
	sBufs[which] = malloc(sineLength * sizeof(float));
	if (!sBufs[which]) return;
	int sl2 = sineLength/2;
	for (int i = 0; i < sl2; i++) //one half wavelength for the saw, k?
		sBufs[which][i] = 2.0 * (float)i / sineLength;
	for (int i = sl2; i < sineLength; i++) //2nd half
		sBufs[which][i] = 1.0 - sBufs[which][i-sl2];
	sBufLens[which] = sineLength;
	sBufChans[which] = 1;
	return;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)buildSquareTable: (int) which
{
	int i,duty = DUTY_TIME * sineLength;
	sBufs[which] = malloc(sineLength * sizeof(float));
	if (!sBufs[which]) return;
	for ( i = 0; i < duty; i++)  //first half is 0
		sBufs[which][i] = 0.0;
	while (i < sineLength)  //second half is  1 (what about dutyy??)
		sBufs[which][i++] = 1.0;
	sBufLens[which] = sineLength;
	sBufChans[which] = 1;
	return;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)buildSineTable: (int) which
{
	// Compute a sine table for a 1 Hz tone at the current sample rate.
	// We can quickly derive the sine wave for any other tone from this
	// table by stepping through it with the wanted pitch value.
	sBufs[which] = malloc(sineLength * sizeof(float));
	if (!sBufs[which]) return;
	for (int i = 0; i < sineLength; i++)
	{
		sBufs[which][i] = sinf(i * 2.0f * M_PI / sineLength);
	}
	sBufLens[which] = sineLength;
	sBufChans[which] = 1;
	return;
} //end buildSineTable



/*==waves....==================================*/
/*=============================================*/
- (void)buildSinXCosYTable: (int) which
//void sinxcosyWave(int a,int b,int c,int d,double *wave)
{
    int a,b;
	//int loop;
	double c1,c2;
    double WSIZE = sineLength;
	//c=d=0;
	sBufs[which] = malloc(sineLength * sizeof(float));
	if (!sBufs[which]) return;
    a  = (int)aFactor;
    b  = (int)bFactor;
	c1 = 0.5;     //127.5;
	c2 = 0.4999;  //127.0;
	a = max(1,a);
	b = max(1,b);
  //  LOOPIT(WSIZE) wave[loop] =
  //  (c1+ c2*
  //   (double)sin(3.*(double)(loop*a)/WSIZE)*
  //   (double)sin(3.*(double)(loop*b+128)/WSIZE)
  //   );
	for (int i = 0; i < sineLength; i++)
	{
		sBufs[which][i] = //  sinf(i * 2.0f * M_PI / sineLength);
          (c1 + c2*
            (double)sin(3.*(double)(i*a)/WSIZE)*
            (double)sin(3.*(double)(i*b+128)/WSIZE)
            );

        //NSLog(@" sinxcosy[%d] %f",i,sBufs[which][i]);
	}
	sBufLens[which] = sineLength;
	sBufChans[which] = 1;
    
} //end sinxcosyWave

/*==waves....==================================*/
/*=============================================*/
- (void)buildSinXSinYTable: (int) which
//void sinxsinyWave(int a,int b,int c,int d,double *wave)
{
    int loop;
    int a,b;
    double WSIZE = (double)sineLength;
	double c1,c2;
	a=b=0;
	c1 = 127.5;
	c2 = 127.0;
    a = max(1,a);
    b = max(1,b);
    LOOPIT(WSIZE) sBufs[which][loop] =
    (c1 + c2*
     (float)sin(3.*(float)(loop*a)/WSIZE)*
     (float)sin(3.*(float)(loop*b)/WSIZE));
}  //end sinxsinyWave


/*==waves....==================================*/
/*=============================================*/
- (void)buildSinOSineTable: (int) which
//void sinosineWave(int a,int b,int c,int d,double *wave)
{int loop,ival1;
	double c1,c2;
    int a,b,c;
    double WSIZE = (double)sineLength;
	c1 = 127.5;
	c2 = 127.0;
	a=b=c=0;
    a = max(1,a);
    b= max(1,b);
    LOOPIT(WSIZE)
    //THIS IS BROKEN. MOD WON'T WORK ON DOUBLES!
    { ival1 =  (loop*a) + (int)((float)b*(1.0+
                                          (float)sin(3.*(float)((loop*c)%(int)WSIZE))));
       sBufs[which][loop] =
        (c1+c2*
         (float)sin(3.*(float)(ival1%(int)WSIZE)));
    }
} //end sinosineWave




//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// this assumes swave has been populated w/ samplefile contents...
//  (ALSO ASSUME ONLY MONO FOR NOW!!!
// DHS TGIVING 14: Force stereo samples: makes playback faster
//  4/29 support 32 bit samples
- (void)buildSampleTable:(int)which
{
    int err=0;
	Float32 clFrame;
    Float32 crFrame;
	short ts;
	int i;
	if (sBufs[which]) 
    {
        //NSLog(@"  2Free sbufs[%d]",which);
        [self cleanupNotes:which];
        free(sBufs[which]); //no illegal double-alloc, please...   
        sBufs[which] = NULL;
    }
    int totalFrames = sNumPackets * sChans;
    //NSLog(@"BuildSample[%d] ...size %lu",which,sNumPackets * sChans * sizeof(float));
	sBufs[which] = malloc(totalFrames * sizeof(float)); //DHS 10/6
	if (!sBufs[which]) return;
    sBufLens[which] = totalFrames;

    // 4/29/21 compute bytes per sample if possible
    int bytesPerSample = 2;
    if (sNumPackets > 0 && sChans > 0) bytesPerSample = sPacketSize / (sNumPackets*sChans);

    //NSLog(@" ...Buildsample[%d]: frames %d srate %d bps %d",which,totalFrames,lastSampleRate,bytesPerSample);

    //DHS 4/12/20 saw overflow by 1 error, reduce loop by 1 to avoid
    unsigned char *pfileBuffer = (unsigned char*)fileBuffer; //4/29 point to incoming data...
    for ( i = 0; i < sBufLens[which]-1; i+=sChans)  // step through by #channels per packet
	{	
        if (i >= fileBufferSize)    //4/29
        {
            NSLog(@" ...sample overflow: buffer %d index %d maxsize %d",which,i,fileBufferSize);
            err=1;
            break;   
        }
        clFrame = crFrame = 0.0;
        if (bytesPerSample == 2) //4/29 old 16 bit...
        {
            memcpy(&ts,pfileBuffer,2);
            pfileBuffer+=2; //advance pointer...
            clFrame = crFrame = (float)ts / 32768.0f;
            if (sChans == 2)
            {
                memcpy(&ts,pfileBuffer,2);
                pfileBuffer+=2; //advance pointer...
                crFrame = (float)ts / 32768.0f;
            }
        }
        else if (bytesPerSample == 3) //4/29 new 24 bit...
        {
            unsigned int work4 = 0;
            memcpy(&work4,pfileBuffer,3);
            pfileBuffer+=3; //advance pointer...
            work4 = work4 << 8; //padd bottom 8 bits, move sign bit from 24 to 32
            clFrame = crFrame = (float)((int)work4) / (32768.0*65536.0f);
            if (sChans == 2)
            {
                memcpy(&work4,pfileBuffer,3);
                pfileBuffer+=3; //advance pointer...
                work4 = work4 << 8; //padd bottom 8 bits, move sign bit from 24 to 32
                crFrame = (float)((int)work4) / (32768.0*65536.0f);
            }
        }
        else if (bytesPerSample == 4) //4/29 new 32 bit...
        {
            int work4 = 0;
            memcpy(&work4,pfileBuffer,4);
            pfileBuffer+=4; //advance pointer...
            work4 = work4 >> 16; //convert to 16 bit representation
            clFrame = crFrame = (float)work4 / 32768.0f;
            if (sChans == 2)
            {
                memcpy(&work4,pfileBuffer,4);
                pfileBuffer+=4; //advance pointer...
                work4 = work4 >> 16; //convert to 16 bit representation
                crFrame = (float)work4 / 32768.0f;
            }
        }
        //always store L/R even on mono!!
        sBufs[which][i]   = clFrame; //store our data...
        sBufs[which][i+1] = crFrame; //store our data...
//        if (i%128 == 0 && bytesPerSample == 4)
//          	NSLog(@" bsw[%d] swave %d ts %d cl/rFrame %f/%f",i,swave[i],ts,clFrame,crFrame);
    }
    //DHS 10/5 WTF? Sample rates seem to vary widely!
    int properRate = lastSampleRate; //4/29
    if (lastSampleRate >= 11000 && lastSampleRate < 12000)
    {
        //NSLog(@" sample 11k...");
        properRate = 11025;
    }
    
    
//4/29    if (lastSampleRate == 48000)   properRate = DEFAULT_SAMPLE_RATE;
    sRates[which]   = properRate;
    if (err) sBufLens[which] = 8192; //STOOPID SIZE!
    //NSLog(@"SAMPLE RATES lsr %d rate %d blen %d",lastSampleRate,sRates[which],sBufLens[which]);
	sBufChans[which] = 2; //always stereo
//     NSLog(@" dump buf every 256th......");
//     for (int i=0;i<sBufLens[which]-1;i+=256)
//         NSLog(@" [%d]:%f",i,sBufs[which][i]);
	return;
} //end buildSampleTable

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
//3/2/21 digital delay
-(void) initDigitalDelay
{
    
    if (delayBuf != nil) //Really?
    {
        NSLog(@" digital delay: reinit? not nil!");
        free(delayBuf);
        delayBuf = nil;
    }
    
    //allocate 1 extra second, stereo, 44khz
    delayBufSize = (1+MAX_DELAY_SECONDS) * DEFAULT_SAMPLE_RATE * 2;
    delayBuf = malloc(delayBufSize * sizeof(float));
    if (delayBuf == nil)
    {
        NSLog(@" ERROR initializing digital delay!");
    }
    drptr = dwptr = 0;
} //end initDigitalDelay

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
-(void) setDelayVars : (int)dtime : (int)dsustain : (int)dmix
{
    delayTime    = dtime; //dtime is in units 0-100, so call it 1/10 sec for now
    delaySustain = dsustain;
    delayMix     = dmix;
    //NOTE we also need to calculate difference between read and write ptrs
    //  read pointer is usually behind write pointer and never ahead
    int doffset =  (dtime * 88200) / 100; //stereo
    drptr = dwptr - doffset;
    while (drptr < delayBufSize) drptr += delayBufSize; //handle negative wrap...
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// incoming l/r floating point -1.0 .... 1.0 range audio data
-(void) delaySend : (float)ml : (float) mr
{
    delayBuf[dwptr] += ml;
    if (delayBuf[dwptr] < -1.0) delayBuf[dwptr] = -1.0;  //clip!!
    if (delayBuf[dwptr] >  1.0) delayBuf[dwptr] =  1.0;
    dwptr++;
    delayBuf[dwptr] += mr;
    if (delayBuf[dwptr] < -1.0) delayBuf[dwptr] = -1.0;  //clip!!
    if (delayBuf[dwptr] >  1.0) delayBuf[dwptr] =  1.0;
    dwptr++;
    while (dwptr >= delayBufSize) dwptr -= delayBufSize; //handle positive wrap...
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 3/2/21 digital delay... Just call this TWICE duh!
-(float) delayReturnLorRWithAutoIncrement
{
    float dw = delayBuf[drptr]; //get LH
    dw *= delaySustain; //should always get smaller, down to 0
    delayBuf[drptr] = dw;
    drptr++;
    while (drptr >= delayBufSize) drptr -= delayBufSize; //handle positive wrap...
    return dw;
} //end delayReturnLorRWithAutoIncrement



//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 11/9 Destructive copy!
-(void) copyBuffer : (int) from : (int) to : (BOOL) clear
{
    copyingBuffer = to;
    //Free mem if needed
    if (clear)
    {
        free(sBufs[to]);
        sBufs[to] = NULL;
    }
    int blen = sBufLens[from];
    sBufs[to] = malloc(blen * sizeof(float));
    if (!sBufs[to]) return;
    //NSLog(@"copy buffer from %d to %d  size [%d]",from,to,blen);
    for (int i=0;i<blen;i++)
    {
        //if (i % 256 == 0) NSLog(@"    [%d]->[%d]...%f",from,to,sBufs[from][i]);
        sBufs[to][i] = sBufs[from][i];
    }
    sBufLens[to]  = sBufLens[from];
    sBufChans[to] = sBufChans[from];
    sRates[to]    = sRates[from]; //11/22
    copyingBuffer = -1;

} //end copyBuffer

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 11/9 Destructive copy!
-(void) copyEnvelope : (int) from : (int) to
{
    copyingEnvelope = to;
    //NSLog(@"copy envelope from %d to %d",from,to);
    //Free mem if needed
    if (sEnvs[to] != NULL)
    {
        free(sEnvs[to]);
        sEnvs[to] = NULL;
    }
    int elen = envLength[from];
    if (elen == 0)
    {
        NSLog(@" ERROR: copy empty envelope %d -> %d",from,to);
        return;
    }
    sEnvs[to] = malloc(elen * sizeof(float));
    if (!sEnvs[to])
    {
        NSLog(@" err nil to envelope %d",to);
        return;
    }
    for (int i=0;i<elen;i++)
    {
        //if (i % 16 == 0) NSLog(@"...%f",sEnvs[from][i]);
        sEnvs[to][i] = sEnvs[from][i];
    }
    envLength[to] = envLength[from];
    //REDUNDANT?
    envDataLength[to] = envDataLength[from];
    
    //NSLog(@" elen[%d] %d vs datalen %d",to,envLength[to] ,envDataLength[to] );
    envIsUp[to]   = 1;
    sElen[to] = sElen[from];
    copyingEnvelope = -1;
} //end copyEnvelope

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 11/11: BUG: if decay is set to 0 then the sustain gets decay color!
//      redid to pass segment back as negative indicator!
-(NSArray *) getEnvelopeForDisplay: (int) which : (int) size
{
    // 5/24 add nil check to sEnvs, but WHY!?!?!
    if (sEnvs[which]==nil)
    {
        NSLog(@" ERROR! nil envelope, should never happen!");
        return nil;
    }
    if (size < 2 || envLength[which] < 2 || sEnvs[which]==nil) return nil;
    NSMutableArray *a = [[NSMutableArray alloc]init];
    int optr = 0;
    int op = 0;
    int phase = 0;
    int duhsize = attackLength + decayLength + sustainLength + releaseLength;
    float bcf = (float)duhsize / (float)size;
    for (int i=0;i<size;i++) //fill output
    {
        optr = (int)((float) i * bcf);
        if (optr > attackLength) phase = 1;
        if (optr > attackLength + decayLength) phase = 2;
        if (optr > attackLength + decayLength+sustainLength) phase = 3;
        float fff = sEnvs[which][optr];
        if (phase != op)
        {
            fff = -1.0 * (float)phase; //Mark phase change
        }
        op = phase;
        [a addObject:[NSNumber numberWithFloat: fff]];
    }
    return [NSArray arrayWithArray:a];
} //end getEnvelopeForDisplay

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)buildEnvelope:(int)which : (BOOL) buildInPlace
{
    //DHS 10/17 avoid redundant calls:
    if (!buildInPlace && envDataLength[which] > 0) return;
   // NSLog(@"  buildEnvelope %d...",which);

	// All envelopes are same length, with data from 0.0 to 1.0. 
	//  Each synth voice will have a corresponding envelope? 
	// Because lower tones last longer than higher tones, we will use a delta
	// value to step through this table. MIDI note number 60? has delta = 1.0f.
	float envsave;
	int i,savei,esize;
    //Get partial envelope lengths ...
    attackLength  = (int)(ATTACK_RELEASE_MULT * ATTACK_TIME  * sampleRate);     // attack 5/19 add mult
    decayLength   = (int)(DECAY_TIME   * sampleRate);                          // decay
    sustainLength = (int)(SUSTAIN_TIME * sampleRate);                         // sustain
    releaseLength = (int)(ATTACK_RELEASE_MULT * RELEASE_TIME * sampleRate);  // release 5/19 add mult
    //DHS 11/16 zero envelope? BailL!
    if ( (attackLength  == 0) && (decayLength   == 0) &&
         (sustainLength == 0) && (releaseLength == 0) )
    {
       // NSLog(@"  ...allzero ENV %d...",which);
        return;
    }
    //envelope was in use? Clobber it!
    if (sEnvs[which] != NULL && !buildInPlace)
    {
        NSLog(@"  ...free env %d...",which);
        free(sEnvs[which]);
        sEnvs[which] = NULL;
    }
    envLength[which] = (int)sampleRate * 8;  // 5/19 enlarge   2? seconds DHS MAKE IT BIG
    envIsUp[which] = 1;
    if (envLength[which] && (sEnvs[which] == NULL)) //Need to allocate?
	{
        //NSLog(@" malloc env [%d] size %d",which,envLength[which]);
        esize = envLength[which]*sizeof(float);
		sEnvs[which] = (float*)malloc(esize);
		if (!sEnvs[which]) return;
        sElen[which] = esize;
	}
    else if (!envLength[which]) {
        //NSLog(@" error in buildEnvelope: zero env length, which %d",which);
        return;
    }
    //NSLog(@"  build env %d len %d...",which,envLength[which]);
	
	//NSLog(@" TOP ADSR============= %d %d %d %d %f",
    //		  attackLength,decayLength,sustainLength,releaseLength ,sampleRate);

	if (attackLength < 1)
	{		
		i = 0;
		envsave = 1.0;
	}
	else  
	{
		for (  i = 0; i < attackLength; i++)
			{
                if (i > sElen[which]) break;   //OUCH! Shouldn't happen
				sEnvs[which][i] = (float)i / (float)attackLength;
				//NSLog(@" ...Aenv[%d] %f",i,sEnvs[which][i]);
			}
		envsave = sEnvs[which][i-1]; //save last env level...
	}
	savei = i;
	// NSLog(@" ...Denvtop[%d] %d %f %d %f %f",which,savei,envsave,decayLength,sampleRate,SUSTAIN_LEVEL);
	for (  i = savei; i < (savei + decayLength); i++)
		{
            if (i > sElen[which]) break;   //OUCH! Shouldn't happen
            sEnvs[which][i] = envsave - ((float)(1.0 - SUSTAIN_LEVEL) * (i-savei) / decayLength);
            // NSLog(@" ...Denv[%d] %f",i,sEnvs[which][i]);
		}

	//Add token sustain chunk....
	savei = i;
	for (  i = savei; i < savei + sustainLength; i++)
		{
            if (i > sElen[which]) break;   //OUCH! Shouldn't happen
            sEnvs[which][i] = SUSTAIN_LEVEL;
            //NSLog(@" ...Senv[%d] %f",i,sEnvs[which][i]);
		}
	savei = i;
    envsave = 0;
    if (i > 0) //DHS 9/24 prevent crash on zero envelope params
        envsave = sEnvs[which][i-1]; //save last env level...
	for (int i = savei; i < savei + releaseLength; i++)
		{
            if (i > sElen[which]) break;   //OUCH! Shouldn't happen
            sEnvs[which][i] = envsave - envsave*((float)(i-savei) / releaseLength);
		}
    
//    for (int i=0;i<savei + releaseLength;i+=(savei + releaseLength)/10)
//    {
//      NSLog(@" ...env[%d] %f",i,sEnvs[which][i]);
//    }
    //DHS WHY doesn't i already have the length here...???
	envDataLength[which] = i + releaseLength;
}  //end buildEnvelope

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 10/31 clear buffers above designated index
- (void)cleanupBuffersAbove:(int)index
{
    while (index < MAX_SAMPLES)
    {
        [self freeSampleMemory: index++];
    }
} //end cleanupBuffersAbove

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
//DHS: We need a cleanup here so voices that may be playing don't
//    keep trying play if their buffer gets clobbered!!!
-(void) cleanupNotes:(int)which
{
    int loop;
    LOOPIT(MAX_TONE_EVENTS)
    {
        if (tones[loop].waveNum == which) //gotta kill some tones!
        {
            tones[loop].state   = STATE_INACTIVE;
            tones[loop].waveNum = -1;
            if (midion) OMEndNote((ItemCount)1, tones[loop].midiNote);
            [self decrVoiceCount:loop];
            
        }
    }
}   //end cleanupNotes

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// attempts to fit an algorithmically generated note into a
//   musical key recognizable to human ears....
- (int)makeSureNoteisInKey: (int) wkey : (int) note
{   // 60 is middle C..... so base C is 4, plus five octaves...
    #define NOTEBASE 4
    int result;
	int tloc = 12*wkey + (note-NOTEBASE) % 12;  // C...B range (0-11)
	int octave = (note-NOTEBASE)/12;    
    //NSLog(@" inkey %d %d",wkey,note);
	if (wkey > 11)   return note;  //out of whack? Just return original note.
	if (tloc < 0)    return note;  //June 2013
	if (tloc > 143)  return note;  //June 2013
    result = NOTEBASE + 12*octave + keysiglookups[tloc]; // 'inkey val'
    //NSLog(@" ....result (%d %d) %d",octave,tloc,result);
	return result;
} //end makeSureNoteisInKey



//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// NEVER CALLED???  6/25 simplify
- (void)emptyQueue
{
    int loop;
    if (!queuePtr) return;
    //NSLog(@"  emptyq, size  %d",queuePtr);
    LOOPIT(queuePtr)
        [self playNoteFromTone : arpTones[loop]]; //6/25/21 play from set of stored tones
    queuePtr = 0; //OK! Queue is empty...
} //end emptyQueue

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)resetArp
{
    arpPtr  = arpPlayPtr = 0;
    arpTime = CACurrentMediaTime();
}



//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 6/26/21 find proper time before inserting new queue item!
//   DHS 3-16-15: Used to create arpeggiated sequences...
//   the arpQueue is a circular queue!
// ALSO note this doesnt handle case where queue is too small
//   and we may unwind past play ptr!
- (void)playNoteWithDelay : (int) midiNote : (int) wnum : (int) type : (int) delayms
{
    double insertTime = CACurrentMediaTime() + (double)delayms*0.001;
    int n0 = arpPtr-1;
    int n1 = arpPtr;
    int topn = MAX_ARP-1;
    if (n1 >= topn) n1 = 0; //handle positive wrap
    BOOL shifted = FALSE;
    while (arpQueue[n0][ARP_PARAM_TIME] > insertTime) //need to index backwards?
    {
        arpQueue[n1][ARP_PARAM_TIME] = arpQueue[n0][ARP_PARAM_TIME];
        arpTones[n1]                 = arpTones[n0]; //bump tone/time to next place
        n0--;
        n1--;
        if (n0 < 0) n0 = topn;   //handle backwards wrap!
        if (n1 < 0) n1 = topn;
        if (n0 <= arpPlayPtr) return; //Cant go before play ptr! Bail!
        shifted = TRUE;
        //NOte n0 points to where we will be saving data!
    }
    if (!shifted) n0 = n1; //No shift? we will append
    arpQueue[n0][ARP_PARAM_TIME] = insertTime;
    arpTones[n0]                 = [self loadupToneFromSynth:midiNote :wnum :type]; //6/25 simplify
    arpPtr++; //shift or no shift, still update end ptr!
    //NSLog(@" insert arp at %d",n0);
} //end playNoteWithDelay

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)OLDplayNoteWithDelay : (int) midiNote : (int) wnum : (int) type : (int) delayms
{
    if (arpPtr == MAX_ARP-1) arpPtr = 0; //Wraparound! //6/25/21 wups wrong def!
    double latestTime = CACurrentMediaTime();
    arpQueue[arpPtr][ARP_PARAM_TIME] = latestTime + (double)delayms*0.001;
    arpTones[arpPtr] = [self loadupToneFromSynth:midiNote :wnum :type]; //6/25 simplify
    arpPtr++;
} //end playNoteWithDelay


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 6/25 used by playNote and playNoteWithDelay
-(ToneEvent) loadupToneFromSynth : (int)midiNote :(int)wnum :(int)type
{
    ToneEvent t;
    t.toneType = type;
    t.state    = STATE_PRESSED;
    //2/12/21 add fine tuning...  +/- 50 notes
    midiNote += (pKeyOffset-50);
    midiNote = MAX(0,MIN(128,midiNote)); //4/26 handle wild notes!!!
    t.midiNote = midiNote;
    t.phase    = 0.0f;
    //2/12/21 still need to change pitch using pKeyDetune!!!
    t.pitch    = pitches[midiNote];
    if (type == SAMPLE_VOICE || type == PERCUSSION_VOICE)
    {
        //8/1 sample offset for percussion AND samples now!
        t.phase    = (int)((float)SAMPLE_OFFSET * (float)sBufLens[wnum] /
                                  (float)sBufChans[wnum]); //compute offset, NOTE #chans
    }
    t.envStep  = 0.0f;
    t.envDelta = midiNote / 64.0f;
    t.waveNum  = wnum;
    t.toneType = type;
    //2/12/21 fine tuning...
    float pgain = 1.0;
    if (pLevel < 50) //attenuate level by 2x
    {
        pgain = MAX(0.5,0.5 + 0.5 * (float)pLevel/50.0);
    }
    else if (pLevel > 50) //increase level by 2x
    {
        pgain = MIN(2.0,1.0 + 0.5 * (float)pLevel/50.0);
    }
    t.gain      = _gain * pgain * finalMixGain;
    t.detune      = detune;
    t.mono       = _mono;
    t.lpan     = glpan;     //see setPan!
    t.rpan     = grpan;     //see setPan!

    t.portamentoTime  = portamentoTime;
    t.timetrax = timetrax;
    t.infinite = 0;
    //7/17 vibrato support
    if (vibAmpl > 0 && vibSpeed > 0) //user enabled vibrato?
    {
        t.vibEnabled = TRUE;
        // 9/2 add exponential range to vib ampl / speed
        t.vibAmpl    = (int)powf(1.03,(float)vibAmpl);
        t.vibSpeed   = (int)powf(1.08,(float)vibSpeed);
        t.vibWave    = vibWave;
        t.vibDelay   = vibDelay;
        t.vibIndex   = 0.0;
        t.vibStep    = 0.3*t.vibSpeed;  //9/2
    }
    else t.vibEnabled = FALSE;
    //4/8 amplitude vibe support
    if (vibeAmpl > 0 && vibeSpeed > 0) //user enabled vibrato?
    {
        t.vibeEnabled = TRUE;
        // 9/2 add exponential range to vib ampl / speed
        t.vibeAmpl    = (int)powf(1.03,(float)vibeAmpl);
        t.vibeSpeed   = (int)powf(1.08,(float)vibeSpeed);
        t.vibeWave    = vibeWave;
        t.vibeDelay   = vibeDelay;
        t.vibeIndex   = 0.0;
        t.vibeStep    = 0.3*t.vibeSpeed;  //9/2
    }
    else t.vibeEnabled = FALSE;

    if (type == SYNTH_VOICE || type == SAMPLE_VOICE) //6/23 add samplevoice for loop support
    {
        t.infinite = infinite;
    }
    //8/2 add percussion
    BOOL needsEnvelope = (type == SYNTH_VOICE ||
                          type == SAMPLE_VOICE ||
                          type == PERCUSSION_VOICE);
    //11/10 but for all zeroes, bail on envelope!
    if (ATTACK_TIME  == 0.0 &&
        DECAY_TIME   == 0.0 &&
        SUSTAIN_TIME == 0.0 &&
        RELEASE_TIME == 0.0) needsEnvelope = FALSE;
    
    t.needsEnvelope = needsEnvelope;
    t.un       = newUnique;
    if (portamentoTime != 0.0 && portamentoLastNote > 0)  //6/25 need portamento? do some math
    {
        t.portamentoLastNote    = portamentoLastNote; // is this needed?
        t.portamentoTime        = portamentoTime;
        // 6/23 NOTE portamento pitch step has to be VERY tiny, note 100 factor!
        t.portamentoPitchStep   = (t.pitch - pitches[portamentoLastNote]) /
                                            (500.0*portamentoTime);
        t.portamentoPitchFinish = t.pitch;
        t.pitch                 = pitches[portamentoLastNote]; //start with LAST NOTE
    }
    return t;
} //end loadupToneFromSynth

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// DHS 11-9 need to change to support mono synth...
- (void)playNote:(int)midiNote :(int)wnum :(int)type
{
    int n,foundit=0;
    newUnique++;
//    if (infinite)
//        NSLog(@"...play note %d, duration %4.2f type %d, buf %d , srate %d, blen %d dt %d  mono %d mlevel %f",
//              midiNote,
//              (float)(sBufLens[wnum]/2)/(float)sRates[wnum],
//              type,wnum,sRates[wnum],sBufLens[wnum],detune,_mono,masterLevel);
    if (sBufLens[wnum] <= 0)
    {
        NSLog(@" ERROR: buffer[%d] empty",wnum); //DHS 9/18 diagnostic, delete later
        return;
    }
    //DHS 11/22 does this work on non-pitch shifted samples???
    // 4/29 perform fixed pitch shift to compensate for sample rate
    //WTF? very counterintuitive: i was shifting notes DOWN for low samples rates,
    //  but sounds were always too low.  Now I shift UP...
    
    //WHY O WHY do 11k samples cause such havoc? they should be shifted 2 octaves DOWN
    //  when played but
    if (sRates[wnum] == 11025)
        midiNote -= 24; //24; //5/18 back to plus shift?  2  octave shift DOWN
    else if (sRates[wnum] == 22050)
        midiNote -= 12; //1 octave shift UP now?
    else if (sRates[wnum] == 16000) //4/29
        midiNote -= 21;  // 1.75 octave shift UP now?
    else if (sRates[wnum] == 48000) //4/29
        midiNote += 1; // one note UP
    if (sRates[wnum] != DEFAULT_SAMPLE_RATE) detune = TRUE; //anything but 44.1khz we need to detune!
    if (midiNote < 1 || midiNote > 255) return;
    //uniqueVoiceCounter++;  //keep track of nth voice...
    if (_mono) //ok mono means find old voice and stop it!
    {
        //hopefully this will find the correct voice.
        // if it doesn't work, we need UNIQUE voice ids! UGH!
        // this could fail if we have TWO voices at the same
        //  time w/ same patch and both are mono....???
        //
        for (int n = 0; n < MAX_TONE_EVENTS; ++n)
            if ( tones[n].mono && tones[n].waveNum == wnum  )
            {
                //Ideally each tone could be put into 'release' state and
                //  then quietly die down (quickly too)??
                tones[n].state = STATE_MONOFADEOUT;
                if (midion) OMEndNote((ItemCount)1, tones[n].midiNote);
            }
    }
    foundit = -1;
    for (n = 0; n < MAX_TONE_EVENTS; ++n)
    {
     if (tones[n].state == STATE_INACTIVE)  // find an empty slot
        {
            foundit = n;
            break;
        }
    }
    if (foundit != -1)  //empty slot? Play that note!
    {
        n=foundit;
        tones[n] = [self loadupToneFromSynth:midiNote :wnum :type]; //6/25 packit up!
        lastToneHandle = n; //6/27 wups forgot
        [self incrVoiceCount:n];
        if (midion)  //Send out MIDI...
        {
            int vel = (int)(444*_gain);
            if (vel > 127) vel = 127;
            OMSetDevice(midiDev);
            OMPlayNote(midiChan, midiNote, vel );
        }
       //[self dumpTone:n];
    }
} //end playNote

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 6/25/21 needed for arpeggiator and maybe delay
- (void)playNoteFromTone:(ToneEvent)t
{
    int n,foundit=0;
    newUnique++;
    if (sBufLens[t.waveNum] <= 0)
    {
        NSLog(@" ERROR: buffer[%d] empty",t.waveNum); //DHS 9/18 diagnostic, delete later
        return;
    }
    if (t.mono) //ok mono means find old voice and stop it!
    {   //hopefully this will find the correct voice.
        // if it doesn't work, we need UNIQUE voice ids! UGH!
        // this could fail if we have TWO voices at the same
        //  time w/ same patch and both are mono....???
        for (int n = 0; n < MAX_TONE_EVENTS; ++n)
            if ( tones[n].mono && tones[n].waveNum == t.waveNum  )
            {
                //Ideally each tone could be put into 'release' state and
                //  then quietly die down (quickly too)??
                tones[n].state = STATE_MONOFADEOUT;
                if (midion) OMEndNote((ItemCount)1, tones[n].midiNote);
            }
    }
    foundit = -1;
    for (n = 0; n < MAX_TONE_EVENTS; ++n)
    {     if (tones[n].state == STATE_INACTIVE)  // find an empty slot
        {
            foundit = n;
            break;
        }
    }
    if (foundit != -1)  //empty slot? Play that note!
    {
        n=foundit;
        tones[n] = t;
        [self incrVoiceCount:n];
        if (midion)  //Send out MIDI...
        {
            int vel = (int)(444*_gain);
            if (vel > 127) vel = 127;
            OMSetDevice(midiDev);
            OMPlayNote(midiChan, t.midiNote, vel );
        }
    }
} //end playNoteFromTone


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// DHS 11-9 need to change to support mono synth...
- (void)oldplayNote:(int)midiNote :(int)wnum :(int)type
{
    int n,foundit=0;
    newUnique++;
//    if (infinite)
//        NSLog(@"...play note %d, duration %4.2f type %d, buf %d , srate %d, blen %d dt %d  mono %d mlevel %f",
//              midiNote,
//              (float)(sBufLens[wnum]/2)/(float)sRates[wnum],
//              type,wnum,sRates[wnum],sBufLens[wnum],detune,_mono,masterLevel);
    if (sBufLens[wnum] <= 0)
    {
        NSLog(@" ERROR: buffer[%d] empty",wnum); //DHS 9/18 diagnostic, delete later    
        return;
    }
    //DHS 11/22 does this work on non-pitch shifted samples???
    // 4/29 perform fixed pitch shift to compensate for sample rate
    //WTF? very counterintuitive: i was shifting notes DOWN for low samples rates,
    //  but sounds were always too low.  Now I shift UP...
    
    //WHY O WHY do 11k samples cause such havoc? they should be shifted 2 octaves DOWN
    //  when played but
    if (sRates[wnum] == 11025)
        midiNote -= 24; //24; //5/18 back to plus shift?  2  octave shift DOWN
    else if (sRates[wnum] == 22050)
        midiNote -= 12; //1 octave shift UP now?
    else if (sRates[wnum] == 16000) //4/29
        midiNote -= 21;  // 1.75 octave shift UP now?
    else if (sRates[wnum] == 48000) //4/29
        midiNote += 1; // one note UP
    if (sRates[wnum] != DEFAULT_SAMPLE_RATE) detune = TRUE; //anything but 44.1khz we need to detune!
    if (midiNote < 1 || midiNote > 255) return;
    //uniqueVoiceCounter++;  //keep track of nth voice...
    if (_mono) //ok mono means find old voice and stop it!
    {   //hopefully this will find the correct voice.  
        // if it doesn't work, we need UNIQUE voice ids! UGH!
        // this could fail if we have TWO voices at the same
        //  time w/ same patch and both are mono....???
        for (int n = 0; n < MAX_TONE_EVENTS; ++n)
            if ( tones[n].mono && tones[n].waveNum == wnum  )
//                if ( tones[n].mono && tones[n].waveNum == wnum &&  tones[n].un == newUnique)
            {
//                NSLog(@" mono fadeout tone n %d wn %d un %d",n,tones[n].waveNum,tones[n].un);
                //Ideally each tone could be put into 'release' state and 
                //  then quietly die down (quickly too)??
                tones[n].state = STATE_MONOFADEOUT;
                if (midion) OMEndNote((ItemCount)1, tones[n].midiNote);
            }
    }
    foundit = -1;
	for (n = 0; n < MAX_TONE_EVENTS; ++n)
	{ 	if (tones[n].state == STATE_INACTIVE)  // find an empty slot
        {
            foundit = n;
            break;
        }
    }
    if (foundit != -1)  //empty slot? Play that note!
    {
        n=foundit;
        tones[n].toneType = type;
        tones[n].state    = STATE_PRESSED;
        //2/12/21 add fine tuning...  +/- 50 notes
        midiNote += (pKeyOffset-50);
        midiNote = MAX(0,MIN(128,midiNote)); //4/26 handle wild notes!!!
        tones[n].midiNote = midiNote;
        tones[n].phase    = 0.0f;
        //2/12/21 still need to change pitch using pKeyDetune!!!
        tones[n].pitch    = pitches[midiNote];
        //NSLog(@".. note %d ,pitch %f   ",midiNote, pitches[midiNote]);
        [self incrVoiceCount:n];
        if (type == SAMPLE_VOICE || type == PERCUSSION_VOICE)
        {
            //8/1 sample offset for percussion AND samples now!
            tones[n].phase    = (int)((float)SAMPLE_OFFSET * (float)sBufLens[wnum] /
                                      (float)sBufChans[wnum]); //compute offset, NOTE #chans
        }
        tones[n].envStep  = 0.0f;
        tones[n].envDelta = midiNote / 64.0f;
        tones[n].waveNum  = wnum;	
        tones[n].toneType = type;
        //2/12/21 fine tuning...
        float pgain = 1.0;
        if (pLevel < 50) //attenuate level by 2x
        {
            pgain = MAX(0.5,0.5 + 0.5 * (float)pLevel/50.0);
        }
        else if (pLevel > 50) //increase level by 2x
        {
            pgain = MIN(2.0,1.0 + 0.5 * (float)pLevel/50.0);
        }
        tones[n].gain	  = _gain * pgain * finalMixGain;
        tones[n].detune	  = detune;
        tones[n].mono 	  = _mono;
        tones[n].lpan     = glpan;	 //see setPan!
        tones[n].rpan     = grpan;	 //see setPan!

        tones[n].portamentoTime  = portamentoTime;
        tones[n].timetrax = timetrax;
        tones[n].infinite = 0;
        //7/17 vibrato support
        if (vibAmpl > 0 && vibSpeed > 0) //user enabled vibrato?
        {
            tones[n].vibEnabled = TRUE;
            // 9/2 add exponential range to vib ampl / speed
            tones[n].vibAmpl    = (int)powf(1.03,(float)vibAmpl);
            tones[n].vibSpeed   = (int)powf(1.08,(float)vibSpeed);
            tones[n].vibWave    = vibWave;
            tones[n].vibDelay   = vibDelay;
            tones[n].vibIndex   = 0.0;
            tones[n].vibStep    = 0.3*tones[n].vibSpeed;  //9/2
            //NSLog(@" play: viba/w/s/i/s %d %d %d %f",vibAmpl,vibWave,vibSpeed,tones[n].vibStep);
        }
        else tones[n].vibEnabled = FALSE;
        //4/8 amplitude vibe support
        if (vibeAmpl > 0 && vibeSpeed > 0) //user enabled vibrato?
        {
            tones[n].vibeEnabled = TRUE;
            // 9/2 add exponential range to vib ampl / speed
            tones[n].vibeAmpl    = (int)powf(1.03,(float)vibeAmpl);
            tones[n].vibeSpeed   = (int)powf(1.08,(float)vibeSpeed);
            tones[n].vibeWave    = vibeWave;
            tones[n].vibeDelay   = vibeDelay;
            tones[n].vibeIndex   = 0.0;
            tones[n].vibeStep    = 0.3*tones[n].vibeSpeed;  //9/2
            //NSLog(@" play: AMPLvib a/w/s/i/s %d %d %d %f",vibeAmpl,vibeWave,vibeSpeed,tones[n].vibeStep);
        }
        else tones[n].vibeEnabled = FALSE;

        if (type == SYNTH_VOICE || type == SAMPLE_VOICE) //6/23 add samplevoice for loop support
        {
            tones[n].infinite = infinite;
        }
        //8/2 add percussion
        BOOL needsEnvelope = (type == SYNTH_VOICE ||
                              type == SAMPLE_VOICE ||
                              type == PERCUSSION_VOICE);
        //11/10 but for all zeroes, bail on envelope!
        if (ATTACK_TIME  == 0.0 &&
            DECAY_TIME   == 0.0 &&
            SUSTAIN_TIME == 0.0 &&
            RELEASE_TIME == 0.0) needsEnvelope = FALSE;
        
        tones[n].needsEnvelope = needsEnvelope;
        tones[n].un       = newUnique;
        if (portamentoTime != 0.0 && portamentoLastNote > 0)  //6/25 need portamento? do some math
        {
            tones[n].portamentoLastNote    = portamentoLastNote; // is this needed?
            tones[n].portamentoTime        = portamentoTime;
            // 6/23 NOTE portamento pitch step has to be VERY tiny, note 100 factor!
            tones[n].portamentoPitchStep   = (tones[n].pitch - pitches[portamentoLastNote]) /
                                                (500.0*portamentoTime);
            tones[n].portamentoPitchFinish = tones[n].pitch;
            tones[n].pitch                 = pitches[portamentoLastNote]; //start with LAST NOTE
        }

        //NSLog(@"  ...got played %d, wnum %d gain %f, fmg %f",midiNote,wnum,gain,finalMixGain);
        if (midion)  //Send out MIDI...
        {
            int vel = (int)(444*_gain);
            if (vel > 127) vel = 127;
            OMSetDevice(midiDev);
            OMPlayNote(midiChan, midiNote, vel );   
        }
      // [self dumpTone:n];
    }
        
    //if (foundit == -1) NSLog(@" ...ran out of tone space! limit=%d",MAX_TONE_EVENTS);
} //end playNote


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// This plays a SYNTH note with a custom pitch: NO NOTES USED!
// Not considered a "voice" so it doesn't increment voice count...
//  Wnum should be 0-7???
//  pitch is floating point, in HZ
- (void)playPitchedNote:(float)pitch :(int)wnum
{
    int n,foundit=0;
    newUnique++;
    if (sBufLens[wnum] <= 0) return;
    foundit = -1;
    for (n = 0; n < MAX_TONE_EVENTS; n++)
	{
        if (tones[n].state == STATE_INACTIVE)  // find an empty slot
          {foundit = n;
           break;
          }
    }
    //if (1) NSLog(@"... playPitchedNote  Pitch %f, buf %d blen %d tone %d founditbin %d", pitch,wnum,sBufLens[wnum],n,foundit);
    if (foundit != -1)  //empty slot? Play that note!
    {
        n=foundit;
        tones[n].toneType = SYNTH_VOICE;
        tones[n].state    = STATE_PRESSED;
        // NO NOTE!  tones[n].midiNote = midiNote;
        tones[n].phase    = 0.0f; //DHS What about sample offset?
        tones[n].pitch    = pitch;
        [self incrVoiceCount:n];
        tones[n].envStep    = 0.0f;
        tones[n].envDelta   = 1.0f;  //This needs to be canned!!! Maybe NO envelope?
        tones[n].waveNum  = wnum;
        tones[n].gain	          = _gain * finalMixGain;
        tones[n].detune	= 1;
        tones[n].mono 	= 0;  //Since we cannot find this easily, force polyphony for now
        tones[n].lpan          = glpan;	 //see setPan!
        tones[n].rpan          = grpan;	 //see setPan!
        tones[n].portamentoTime = portamentoTime;
        tones[n].timetrax    = timetrax;
        tones[n].un             = newUnique;
        
    }
    
    //if (foundit == -1) NSLog(@" ...ran out of tone space! limit=%d",MAX_TONE_EVENTS);
} //end playPitchedNote

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// Designed to be used with pitched note: release note by actual wave BIN
- (void)releaseNoteByBin:(int)n
{
    tones[n].state   = STATE_INACTIVE;
    tones[n].waveNum = -1;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 6/27 called by 3 different release methods
-(void) releaseNotesOrLoopsOrArpeggiator : (BOOL) nflag : (BOOL) lflag : (BOOL) aflag
{
    for (int n = 0; n < MAX_TONE_EVENTS; ++n)
    {
        if ((lflag && tones[n].infinite) ||
            (nflag && !tones[n].infinite))
        {
            [self releaseNoteByBin:n];
            if (midion) OMEndNote((ItemCount)1, tones[n].midiNote);
            //update counts...
            if (tones[n].toneType == SYNTH_VOICE || tones[n].toneType == SAMPLE_VOICE)
                numSVoices = MAX(0,numSVoices-1);
            else if (tones[n].toneType == PERCUSSION_VOICE || tones[n].toneType == PERCKIT_VOICE)
                numPVoices = MAX(0,numPVoices-1);
        }
    }
    if (aflag) [self resetArp];
} //end releaseNotesOrLoopsOrArpeggiator

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 6/23/21 only clobber infinite notes...
- (void)releaseAllLoopedNotes
{
    [self releaseNotesOrLoopsOrArpeggiator : FALSE : TRUE : FALSE];
} //end releaseAllLoopedNotes

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 6/23/21 only clobber infinite notes...
- (void)releaseAllNonLoopedNotes
{
    [self releaseNotesOrLoopsOrArpeggiator : TRUE : FALSE : FALSE];
} //end releaseAllNonLoopedNotes


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// Aug 26: OK I want this to KLOBBER ALL audio output!
- (void)releaseAllNotes  
{
    [self releaseNotesOrLoopsOrArpeggiator : TRUE : TRUE : TRUE];
} //end releaseAllNotes

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// This happens if user kills a voice??? Doesn't work too good,
//   since the audio queue is already been fed out..... still get delayed result
- (void)releaseAllNotesByWaveNum:(int)wn  
{
	for (int n = 0; n < MAX_TONE_EVENTS; ++n)
	{
	//	NSLog(@" releaseAll... n %d wn%d vs %d",n,tones[n].waveNum);
	  if (tones[n].waveNum  == wn)
      {
          [self releaseNoteByBin:n];
          if (midion) OMEndNote((ItemCount)1, tones[n].midiNote);
          [self decrVoiceCount:n];
      }
	}

}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
//DHS 12-1: Added check to make sure both NOTE and wave num match before
//  forcing release in MONO mode...
- (void)releaseNote:(int)midiNote :(int)wnum
{
	for (int n = 0; n < MAX_TONE_EVENTS; ++n)
	{
		if (tones[n].midiNote == midiNote && 
            tones[n].waveNum == wnum &&	
            tones[n].state != STATE_INACTIVE)
		{
			tones[n].state = STATE_RELEASED;
            //Is this the best place for this?
            if (midion) OMEndNote((ItemCount)1, tones[n].midiNote);
            [self decrVoiceCount:n];
			// We don't exit the loop here, because the same MIDI note may be
			// playing more than once, and we need to stop them all.
		}
	}
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 10/31 get buffer size...
- (int)getBufferSize: (int) index
{
    if (sBufs[index] == nil) return 0;
    return sBufLens[index];
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 6/25/21 new
- (float)getBufferPlaytime: (int) index
{
    if (sBufs[index] == nil) return 0.0;
    int blen  = sBufLens[index];
    int srate = sRates[index];
    int chans = sBufChans[index];
    if (chans == 0) return 0.0;
    return (float)blen/((float)chans*(float)srate);
} //end getBufferPlaytime


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
-(NSString *)getAudioOutputFileName
{
    return recFileName; //asdf
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
-(NSString *)getAudioOutputFullPath
{
    return recFileFullPath;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (int)getSVoiceCount 
{
    return numSVoices;
    
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 5/24 checks envelope size (usually b4 a copy)
-(int) getEnvelopeSize : (int) which
{
    if (which < 0 || which >= MAX_SAMPLES) return 0;
    if (sEnvs[which] == nil) return 0;
    return sElen[which];
} //end getEnvelopeSize

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 11/22 add srate to keep track of weird samples rates
-(int) getSRate : (int) bptr
{
    if (bptr < 0 || bptr > MAX_SAMPLES ) return DEFAULT_SAMPLE_RATE;
    return sRates[bptr];
}


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (int)getNeedToMailAudioFile 
{
    return needToMailAudioFile;
}
//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setNeedToMailAudioFile:(int)n
{
    needToMailAudioFile=n;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// DANGEROUS: makes note play FOREVER!
- (void)setInfinite:(int)n
{
    infinite=n;
}


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (int)getPVoiceCount 
{
    return numPVoices;
}
//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)incrVoiceCount:(int)n
{
    // NSLog(@" ..INCR voice count(%2.2d),note %3.3d, (%2.2d %2.2d)",
    //        n,tones[n].midiNote, numSVoices,numPVoices);
    if (tones[n].toneType == SYNTH_VOICE || tones[n].toneType == SAMPLE_VOICE)
    { // NSLog(@" ...incr SYNTH");
        numSVoices++;
    }
    else 
    {
        //NSLog(@" ...incr PERC");
        numPVoices++;
    }
   //NSLog(@" ..DONEINCR %d sv   %d pv",numSVoices,numPVoices);

} //end incrVoiceCount

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)decrVoiceCount:(int)n
{
    // NSLog(@" ..DECR voice count(%2.2d),note %3.3d, (%2.2d %2.2d)",
    //        n,tones[n].midiNote, numSVoices,numPVoices);
    if (tones[n].toneType == SYNTH_VOICE || tones[n].toneType == SAMPLE_VOICE)
    {
        numSVoices--;
        if (numSVoices < 0) numSVoices = 0;
    }
    else 
    {
        numPVoices--;
        if (numPVoices < 0) numPVoices = 0;
    }
    //NSLog(@" ..DONEDECR %d sv   %d pv",numSVoices,numPVoices);
} //end decrVoiceCount

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// DHS 11/29: Used to clear out stray sounds if user quits a game early?
- (int)clearBuffer:(void*)buffer frames:(int)frames
{
	SInt16* p = (SInt16*)buffer;
    int f;
    for (f = 0; f < frames; ++f)
    {
		p[f*2]     = 0;     //LEFT
        p[f*2 + 1] = 0;   //RIGHT
    }
    return 0;
} //end clearBuffer

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// THIS NEEDS TO BE TIGHT AS POSSIBLE!!!!
- (int)fillBuffer:(void*)buffer frames:(int)frames
{
	SInt16* p = (SInt16*)buffer;
	int f,n,a,c,wn;
    int sbc;
    float sValue,sValue2,ml,mr,b,sl,sr;
    float vibPitchOff = 0.0;
    float envValue    = 1.0; //2/26 fix no init warning
    float vibeAmplLevel = 1.0;

	//double startTime = CACurrentMediaTime();
    sValue = sValue2 = 0.0f; //DHS 7/10/15 Compiler warnings
	// We are going to render the frames one-by-one. For each frame, we loop
	// through all of the active ToneEvents and move them forward a single step
	// in the simulation. We alculate each ToneEvent's individual output and
	// add it to a mix value. Then we write that mix value into the buffer and 
	// repeat this process for the next frame.
	for (f = 0; f < frames; ++f)
	{
		ml = mr = 0.0f;  // the mixed value for this frame
		for (n = 0; n < MAX_TONE_EVENTS; ++n)
		{
			if (tones[n].state == STATE_MONOFADEOUT)  // fading out in mono mode?
            {
                tones[n].gain *= 0.95; // 6/25 attenuate gain by 5% each sample (TUNE IF NEEDED)...
                if (tones[n].gain < 0.02)  //volume below 10%? Outtahere!
                {
                   // NSLog(@" tone %d fadeout",n);
                    tones[n].state   = STATE_INACTIVE;
                    tones[n].waveNum = -1;
                    if (midion) OMEndNote((ItemCount)1, tones[n].midiNote);
                    [self decrVoiceCount:n];
                 }

            }
            if (tones[n].state == STATE_INACTIVE)  // only active tones
                   continue;    //this is krude! but it bypasses logic below and goes to end of loop
			wn = tones[n].waveNum ;
			// The envelope is precomputed and stored in a look-up table.
			// For MIDI note 64 we step through this table one sample at a
			// time but for other notes the "envStep" may be fractional.
			// We must perform an interpolation to find the envelope value
			// for the current step. 10/17 add support for sample envelopes
            //0 - 7: synths...we need an envelope, sample-based too if flag is set
            if (tones[n].toneType == SYNTH_VOICE || tones[n].needsEnvelope)
			{
                if (tones[n].infinite) envValue = 1.0;
                else if (copyingEnvelope != wn) //11/9 don't access envelope on copy!
                {
                    a = (int)tones[n].envStep;   // integer part
                    //DHS 3/29/21 KLUGE? saw a krash with both a and c negative!
//                    if (a < 0)
//                    {
//                        NSLog(@" ERROR: negative index in fillBuffers! (should NEVER HAPPEN)");
//                        a = 0;
//                    }
                    b = tones[n].envStep - a;  // decimal part
                    c = a + 1;
                    if (c >= envLength[wn])  // don't wrap around
                        c = a;
                    if (c > sElen[wn])
                        //illegal envelope access!
                    {
                        //if (0) NSLog(@"Illegal Envelope access: eLen[%d] = %d, abc %d %d %d",wn,sElen[wn],a,b,c);
                        //c = 0;
                        envValue = 0.0;
                    }
                    else if (sEnvs[wn] != NULL) //DHS nov 27 add existance check for sEnvs
                        //4/26 KRASH here, weird: tone[0] played, midiNote is -30 and envStep is -6773761
                        //  WTF? how can we get negative env step, and why a negative MIDI note?
                        envValue = (1.0f - b)*sEnvs[wn][a] + b*sEnvs[wn][c];
                    else {
                        envValue = 0.0;
                    }
                    // Get the next envelope value. If there are no more values,
                    // then this tone is done ringing.
                    tones[n].envStep += tones[n].envDelta;
                    if (((int)tones[n].envStep) >= envDataLength[wn]  )
                    {
                        tones[n].state   = STATE_INACTIVE;
                        tones[n].waveNum = -1;
                        if (midion) OMEndNote((ItemCount)1, tones[n].midiNote);
                        [self decrVoiceCount:n];
                        continue;
                    }
//                    NSLog(@"wnum %d  a/b/c is %d/%f/%d rawEnv %f elen %d -> value %f",
//                          wn,a,b,c,sEnvs[wn][a],envLength[wn],envValue);
                    envValue = 1.0; //KLUGE
                }
			}  //end synth/sample voice
			else  //Percussion/Sample voice? We won't apply envelope
				envValue = 1.0;
			// The steps in the sine table are 1 Hz apart, but the pitch of
			// the tone (which is the value by which we step through the
			// table) may have a fractional value and fall in between two
			// table entries. We will perform a simple interpolation to get
			// the best possible sine value.
			a = (int)tones[n].phase;  // integer part
            //if (a >= sineLength) NSLog(@" abing! %d vpo %f",a,vibPitchOff);
			b = tones[n].phase - a;   // decimal part
			c = a + 1;
			sbc = sBufChans[wn];
			if (tones[n].toneType == SYNTH_VOICE ) //DHS 10/6 fix
			{
				while (a >= sineLength) a -= sineLength;  // wrap a and c ptrs
				while (c >= sineLength) c -= sineLength;  					
			}
			else  //percussion/sample waves...
			{
				if (a >= sBufLens[wn])
				{ 	a = sBufLens[wn]-1; // sample: nowrap!
					c = a;
				}
			}
            // 6/25 we need to get either a fixed pitch step OR a portamento / whammy bar pitch offset
            if (tones[n].portamentoTime > 0.0) //Got portamento?
            {
                float tps = tones[n].portamentoPitchStep;
                if ((tps > 0.0 && tones[n].pitch < tones[n].portamentoPitchFinish) ||
                    (tps < 0.0 && tones[n].pitch > tones[n].portamentoPitchFinish) )
                {
                    tones[n].pitch += tps; //change the pitch
                }
            }
            float pitch = tones[n].pitch;
            //7/17 add vibrato offset here! modifies pitch over time
            vibPitchOff = (tones[n].vibEnabled) ? [self getVibOffset : pitch : n] : 0.0;
//            if (n == 0 && tones[n].vibEnabled)
//            {
//                float percent = vibPitchOff/pitch;
//                NSLog(@" pitch vs offset %f : %f [%f %%]",pitch,vibPitchOff,percent);
//            }
            pitch = tones[n].pitch + vibPitchOff; //Assume default pitch 7/17 add vibrato
			// Wrap round when we get to the end of the sine look-up table.
			if (tones[n].toneType == SYNTH_VOICE) //0 - 7: synths...
			{
                tones[n].phase += pitch;
                //wrap wave around within synth buffer
 				while (((int)tones[n].phase) >= sineLength)
					tones[n].phase -= sineLength;
				while (((int)tones[n].phase) < 0 )
					tones[n].phase += sineLength;
			}
			//DHS general sampling will have a pitch associated with it!
			else if (tones[n].toneType == SAMPLE_VOICE) //samples ! but not perc!
			{
				//DHS: this coeff gets us close to the initial sample's pitch
				//    when C4 is pressed on the keyboard....
				if (tones[n].detune)  //Detune? use pitch to step thru...
                {
                    tones[n].phase += 0.0029*pitch;
                }
				else
					tones[n].phase++; //NO detune. step thru by onesies...
                //10/8 check for vibrato-caused crash...
                if (tones[n].phase  < 0.0)
                    {
                        //NSLog(@" ERROR!! negative phase on sample voice %d : %d",n,(int)tones[n].phase);
                        tones[n].phase = 0.0;
                    }
				if (((int)tones[n].phase*sbc) >= sBufLens[wn]-2) //End sample/tone! DHS 6/6/17 add -1
				{
                    //NSLog(@" ..end tone %d,%d, blen %d",n,wn,sBufLens[wn]);
                    if (tones[n].infinite == 0) //  6/23/21 Single pass only
                    {
                        tones[n].state   = STATE_INACTIVE;
                        tones[n].waveNum = -1;
                        if (midion) OMEndNote((ItemCount)1, tones[n].midiNote);
                    }
                    else
                        tones[n].state = STATE_PRESSED; //REDUNDANT, testing ONLY
					tones[n].phase = 0;
                    if (tones[n].infinite == 0) [self decrVoiceCount:n];
				}
			} //end SAMPLE_VOICE
			else   //percussion samples: 5/2/20 add detune
			{   
 				if (tones[n].detune)   //Detune? use pitch to step thru...
					tones[n].phase += 0.0029*pitch;
				else 
                    tones[n].phase++; //no octave: step thru by onesies...
                //10/8 check for vibrato-caused crash...
                if (tones[n].phase  < 0.0)
                {
                    //NSLog(@" ERROR!! negative phase on perc voice %d : %d",n,(int)tones[n].phase);
                    tones[n].phase = 0.0;
                }
                //DHS FOR some reason, percs > 8 NEVER GET HERE!
				if (((int)tones[n].phase*sbc) >= sBufLens[wn]-2) //End sample/tone!
				{
					tones[n].state   = STATE_INACTIVE;
                    tones[n].waveNum = -1;
                    if (midion) OMEndNote((ItemCount)1, tones[n].midiNote);
					tones[n].phase = 0;
                    //NSLog(@" decr 4 n %d, dt %d",n,tones[n].detune);
                    [self decrVoiceCount:n];
				}
			}
            if (tones[n].state != STATE_INACTIVE) //DHS 6/6/17
            {
                sValue = 0;
                if (copyingBuffer != wn) //11/9 Dont access on a copy!
                {
                    if (sbc == 1) //mono...
                        sValue = (1.0f - b)*sBufs[wn][a] + b*sBufs[wn][c];
                    else if (sbc == 2) //stereo...
                    { //10/8/20 saw a crash , a was NEGATIVE!!!
                        sValue  = (1.0f - b)*sBufs[wn][2*a] + b*sBufs[wn][2*c];
                        sValue2 = (1.0f - b)*sBufs[wn][1+2*a] + b*sBufs[wn][1+2*c];
                    }
                }
                // Calculate the final sample value.
                //  we need to fill Left/Right buffers EVEN with mono samples!
                // 4/8/21 apply vibe amplitude level as needed
                vibeAmplLevel = (tones[n].vibeEnabled) ? [self getVibeLevel : n] : 1.0;
                envValue*=vibeAmplLevel; //apply ampl vibe
                sl = sValue * envValue * tones[n].gain  * tones[n].lpan ;
                //if (lrvolmod % 256 == 0)
                //      NSLog(@" sl: %f %f %f %f",sValue,envValue,tones[n].gain,tones[n].lpan);
                sr = 0;
                if (sbc == 1) //mono...
                    sr = sValue * envValue * tones[n].gain  * tones[n].rpan ;
                else if (sbc == 2) //stereo...
                    sr = sValue2 * envValue * tones[n].gain  * tones[n].rpan ;
                // Add it to the mix.
                ml += sl;
                mr += sr;
            }
		} //end n loop; done mixing tones
        //DHS masterlevel is new as of 2013: Try ultra boost 2.0...
        ml*=(masterLevel);
        mr*=(masterLevel);
		// Clamp MIX to make sure it is within the [-1.0f, 1.0f] range.
		if (mr > 1.0f)       mr = 1.0f;
		else if (mr < -1.0f) mr = -1.0f;
		if (ml > 1.0f)       ml = 1.0f;
		else if (ml < -1.0f) ml = -1.0f;
        
		// Write the sample mix to the buffer as TWO 16-bit words.
		p[f*2]     = (SInt16)((ml ) * 0x7FFF);     //LEFT 
		p[f*2 + 1] = (SInt16)((mr ) * 0x7FFF);   //RIGHT
        
        
        //if (f < 256) NSLog(@" 2mlr %f %f p %d/%x %d/%x",ml,mr,p[f*2],p[f*2],p[f*2+1],p[f*2+1]);
        //DHS feb 2013: Store latest audio output in a volume buffer...
        lrvolmod++;
//LIVE DUMP: TURN OFF FOR DELIVERY!!!===================
//        if (lrvolmod % 256 == 0)  { NSLog(@" frame %d LR %f %f",f,ml,mr); }
//======================================================
        //take sample every 8 frames...
        if (lrvolmod % 8 == 0)
        {
            lvolbuf[lrvolptr]=ml;
            rvolbuf[lrvolptr]=mr;
            lrvolptr++;
            if (lrvolptr > 15) lrvolptr=0; //wrap around...
        }
	
    } //end insane main loop...
    
    //6/17/21 (arp/chord) handle new arpeggiated notes, should run in real time?
    [self arpUpdate];
    
    //DHS 2/5/18 comment out block to silence warning
    //OK at this point we have a valid buffer; recording?
    if (recording && audioRecBuffer != nil) //5/17 add error check, saw krash below!
    {  int loop,rindex,rsize= f*2; //number of floats in our buffer...
        short sval;
        SInt16 si6;
        rindex = recptr;
        //NSLog(@" ........recording, frames %d rsize %d recptr %d",frames,rsize,recptr);
        LOOPIT(2*frames)
        {
            si6 = (p[loop]);  
            sval = (short)(_recGain * (float)si6); //7/29 test rec gain
//            if (rindex  % 1024 == 0)
//                NSLog(@" [%d] pakaudio px %x  si6 %d/%x s %d / %x",
//                          rindex,p[loop],si6,si6,sval,sval);
            //5/17/21 KRASH HERE after stopping a recording! buf was nil
            audioRecBuffer[rindex] = sval;
            rindex++;
        }
        //NSLog(@" ..wrbuf %d",recptr);
        recptr+=rsize;    //advance ptr
        if (recptr >= recsize/2)  //DHS why /4?  hmmm why /2?
        {
            //NSLog(@" ...bing stop at size %d ",recsize);
            [self stopRecording:0];
        }
    } //end if recording
	//NSLog(@"elapsed %g", CACurrentMediaTime() - startTime);

	return frames;
} //end fillBuffer

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// for voice n, apply vibrato as needed, returns a pitch offset
//  NOTE offset must be proportional to the pitch!!
//  CRASH: 10/8/20 can this set phase < 0???
-(float) getVibOffset : (float) pitch : (int) n
{
    int wave = VIBRATO_WAVE_BASE + tones[n].vibWave;
    float findex = tones[n].vibIndex;
    float sval   = sBufs[wave][(int)findex]; // get raw wave value, range 0 to 1
    sval = (2.0 * sval) - 1.0; //4/30 convert to range -1 to 1...
    float fstep  = tones[n].vibStep;
    findex = findex + fstep;
    while (findex >= sBufLens[wave]) findex-=sBufLens[wave]; //wraparound
    tones[n].vibIndex = findex;  //save updaed vib index
    sval *= (pitch * vibAmpl * 0.05); //needs to be blown up a lot?
    return sval;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// for voice n, compute amplitude vibe level, returns 1.0 for no change
//  4/30 wups, input wave range 0..1 NOT -1..1!!
-(float) getVibeLevel : (int) n
{
    int wave = VIBRATO_WAVE_BASE + tones[n].vibeWave;
    float findex = tones[n].vibeIndex;
    float sval   = sBufs[wave][(int)findex]; // get raw wave value, range 0 to 1
    float fstep  = tones[n].vibeStep;
    findex = findex + fstep;
    while (findex >= sBufLens[wave]) findex-=sBufLens[wave]; //wraparound
    tones[n].vibeIndex = findex;  //save updaed vib index
    //NSLog(@"  svalraw %f",sval);
    sval =  sval * vibeAmpl * 0.01; //rescale to 0.0 ... 1.0 range
    //NSLog(@" vi %d vampl %d sv %f",(int)findex,vibeAmpl,sval);
    return sval;
}


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setUnique: (int)newUniqueInt 
{
	//we get a new gain value from 0 to 255, and set our gain accordingly,
	//  ranging from 0 to 1
	newUnique = newUniqueInt;
}//end setUnique

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (int)getMidiOn   
{
	return midion;
}//end getMidiOn



//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setMidiOn: (int)onoff 
{
    //NSLog(@" ...synth set MIDI on/off %d",onoff); 
	midion = onoff;
}//end setMidiOn

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
//10/17 for sample envelopes
-(void) setNeedsEnvelope : (int) which : (BOOL) onoff
{
    tones[which].needsEnvelope = onoff;
}


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void) setWaveNum: (int) wnum
{
    //NSLog(@" set synth ewavenum %d STUBBED", wnum);
    //WTF>>\\??  waveNum = wnum;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setMIDI: (int)mdev :(int)mchan
{
	//we get a new gain value from 0 to 255, and set our gain accordingly,
	//  ranging from 0 to 1
	midiDev  = mdev;
	midiChan = mchan;
}//end setMIDI

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setTimetrax:(int)newVal 
{
	//this is off/on for now, 0 , 1
	timetrax = newVal;
}//end setTimetrax


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// used to match old voice's unique lil track (to clobber last mono note)
- (void)setMonoUN: (int)un 
{
    monoLastUnique = un;
}//end setMonoUN


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// sets up portamento for a voice, 0 = none, 1 = some (fixed amount for now)
- (void)setPortamento: (int)pn
{
    portamentoTime = (float)pn;
}//end setPortamento

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// sets up portamento for a voice, 0 = none, 1 = some (fixed amount for now)
- (void)setPortamentoLastNote: (int)lastnote 
{
    portamentoLastNote = lastnote;
}//end setPortamento


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// Sets globals lpan and rpan, stored w/ tones in playnote.
- (void)setPan: (int)newPanInt 
{
	float dogf;
	dogf = (float)newPanInt;
	//NSLog(@" setpan %d %f",newPanInt,dogf);
	grpan = dogf/255.0;
	glpan = 1.0 - dogf/255.0;
	
} //end setPan

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (float)getLVolume 
{
    int loop;
    float r=0;
    LOOPIT(16)r+=ABS(lvolbuf[loop]);
    r/=16.0;
    return r;
} //end getLVolume

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (float)getRVolume 
{
    int loop;
    float r=0;
    LOOPIT(16)r+=ABS(rvolbuf[loop]);
    r/=16.0;
    return r;
} //end getRVolume

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (int)getUniqueCount 
{
    return(uniqueVoiceCounter);
}  //end getUniqueCount

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
//6/25/21
- (int) getLastToneHandle
{
    return lastToneHandle;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
//6/25/21 n points to a tone struct
-(float) getSampleProgressAsPercent : (int) n : (int) buf
{
    int sbc = sBufChans[buf];
    int tp  = (int)tones[n].phase;
    if (sBufLens[buf] == 0) return 0.0;
    float pf = (float)(tp*sbc) / (float)sBufLens[buf];
    //NSLog(@" getSampleProgressAsPercent[%d] sbc %d tp %d pf %f",n,sbc,tp,pf);
    return (pf * 100.0);
} //end getSampleProgressAsPercent

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// gain is input 0..255
- (void) setToneGainByHandle : (int) handle : (int) newGain
{
    tones[handle].gain = (float)newGain/255.0;
}


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (int)getNoteCount 
{   int nc=0;
	for (int n = 0; n < MAX_TONE_EVENTS; ++n)
	{
		if (tones[n].state != STATE_INACTIVE)  // only active tones
			nc++;
	}
	return nc ;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (float)getADSR: (int)which : (int)where 
{
	// if (where % 32 == 0) NSLog(@" getADSR %d  %d ",which,where);
	if (!envIsUp[which]) return -1.0;
	if (where >= envLength[which]) return -2.0;
	return sEnvs[which][where];
}
//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (int)getEnvDataLen:(int)which  
{
	if (!envIsUp[which]) return 0.0;
	return envDataLength[which];
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setAttack: (int)newVal 
{
 	//take our percent val, turn it into our attack val (0 - .1)!!!
 	ATTACK_TIME = (float) ATTACK_RELEASE_MULT*newVal*INV_SYNTH_TS; //5/19 3x longer attack/release
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setDecay: (int)newVal 
{
 	//take our percent val, turn it into our decay val (0 - .1)!!!
 	DECAY_TIME = (float) newVal*INV_SYNTH_TS;  //5/19 change coeef
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setSustain: (int)newVal 
{
 	//take our percent val, turn it into our sustain val (0 - .1)!!!
 	SUSTAIN_TIME = 5.0 * (float) newVal*INV_SYNTH_TS; //5/19 change coeef
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setSustainL: (int)newVal 
{
 	//take our percent val, turn it into our sustain level (DIFFERENT: 0 - 1)!!!
 	SUSTAIN_LEVEL = (float) newVal/100.0;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setRelease: (int)newVal 
{
 	//take our percent val, turn it into our release val (0 - .1)!!!
 	RELEASE_TIME = (float) ATTACK_RELEASE_MULT*newVal*INV_SYNTH_TS; //5/19 3x longer attack/release
}


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setDuty: (int)newVal 
{
 	//take our percent val, turn it into our release val (0 - .1)!!!
 	DUTY_TIME = (float) newVal/100.0;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 8/1 new arg
- (void)setSampOffset: (int)percent;
{
 	//take our percent val, turn it into our release val (0 - .1)!!!
 	SAMPLE_OFFSET = (float)percent/100.0;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setDetune: (int)newVal 
{
 	//take our percent val, turn it into our release val (0 - .1)!!!
 	detune = newVal;
}

//7/17 vibrato externals...
- (void) setVibAmpl:   (int) newVal {vibAmpl  = newVal;}
- (void) setVibWave:   (int) newVal {vibWave  = newVal;}
- (void) setVibSpeed:  (int) newVal {vibSpeed = newVal;}
- (void) setVibDelay:  (int) newVal {vibDelay = newVal;}
//4/8 amplitude vibe
- (void) setVibeAmpl:   (int) newVal {vibeAmpl  = newVal;}
- (void) setVibeWave:   (int) newVal {vibeWave  = newVal;}
- (void) setVibeSpeed:  (int) newVal {vibeSpeed = newVal;}
- (void) setVibeDelay:  (int) newVal {vibeDelay = newVal;}
// 2/12/21 fine tuning
- (void) setPLevel:     (int)newVal  {pLevel       = newVal;}
- (void) setPKeyOffset: (int)newVal  {pKeyOffset   = newVal;}
- (void) setPKeyDetune: (int)newVal  {pKeyDetune   = newVal;}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 10/6 new buffer to store note offset for general midi samples
-(void) setNoteOffset: (int) which : (NSString*) fname
{
    NSArray *keys   = @[@"C",@"D",@"E",@"F",@"G",@"A",@"B"];
    NSArray *digits = @[@"0",@"1",@"2",@"3",@"4",@"5",@"6",@"7",@"8",@"9"];
    //NSLog(@"SETNOTEOFFETS================+%@ --------------___",fname);
    NSArray *f = [fname componentsSeparatedByString:@"_"];
    if (f == nil || f.count < 2) return; //nothing! error so do nothing
    NSString *suffix = f[1]; //part after the _
    if (suffix.length < 2) return; //error, too short
    NSString *s1 = [suffix substringWithRange: NSMakeRange(0,1)]; //break into 2 strings
    NSString *s2 = [suffix substringWithRange: NSMakeRange(1,1)];
    
    NSUInteger kindex = [keys   indexOfObject:s1];
    NSUInteger dindex = [digits indexOfObject:s2];

    if (kindex != NSNotFound && dindex != NSNotFound) //legit key/digit sig?
    {
        int offset = (int) kindex;
        int dig = (int) dindex;
        NSLog(@" found %@ o/d %d %d",fname,offset,dig);
        offset = offset + 16 + 12*(dig); //i guess 16 is bottom for C0?
        NSLog(@" .....and offset is %d == 64?",offset);
        sTuningOffsets[which] = offset;
    }
} //end setNoteOffset




//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// sept 7: WRITE WAV FILE?????
// Sept 11: OK. This is yielding error 1718449215 (hex  666d743f) or "fmt?"
//          which is kAudioFileUnsupportedDataFormatError
//          Same err trying WAV or AIFF file, ok kAudioFormatULaw seems OK!
// Currently ignores input name strings....
//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==-----
//objc[876]: Object 0x1f59d550 of class __NSCFString autoreleased with no pool in place - just leaking - break on objc_autoreleaseNoPool() to debug
//objc[876]: Object 0x1f5a3290 of class NSPathStore2 autoreleased with no pool in place - just leaking - break on objc_autoreleaseNoPool() to debug
//objc[876]: Object 0x1f59c690 of class __NSCFString autoreleased with no pool in place - just leaking - break on objc_autoreleaseNoPool() to debug
//objc[876]: Object 0x1f5af400 of class NSPathStore2 autoreleased with no pool in place - just leaking - break on objc_autoreleaseNoPool() to debug
// 6/22/20 remove args
- (void)writeOutputSampleFile
{ 	 
    UInt32 bytesize,packetsize;
    int err;
    char errc[8];
	AudioFileID fileID = nil;
	AudioStreamBasicDescription outFormat;
    recordfileIndex++;  //Increment index!
    recFileName = [NSString stringWithFormat:@"oogie%4.4d.caf",recordfileIndex];
    
    NSArray  *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];

 	recFileFullPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"samples/%@", recFileName]];
    NSLog(@" ...write sample %@",recFileFullPath);

    outFormat.mSampleRate       = DEFAULT_SAMPLE_RATE;
	outFormat.mFormatID			= kAudioFormatLinearPCM;
    outFormat.mFormatFlags		= kAudioFormatFlagIsSignedInteger;
    outFormat.mFramesPerPacket	= 1;  //single frame, nothing fancy
    outFormat.mChannelsPerFrame	= 2;  //stereo
    outFormat.mBytesPerFrame	= 4;  //two shorts
    outFormat.mBytesPerPacket	= 4;  //again, two shorts
    outFormat.mBitsPerChannel   = 16; // deep audio
    //DHS 7/19/13. recptr is in WORDS, so add 2x
    bytesize = 2*recptr;
    packetsize = bytesize/outFormat.mBytesPerPacket;
    //if (0) NSLog(@" dump audio inside recorder... bs %d bpp %d ps %d",
    //      bytesize,outFormat.mBytesPerPacket,packetsize); 
    NSURL* recURL = [NSURL URLWithString:recFileFullPath];
    //NSLog(@" dump %d bytes audio to url:%@",bytesize,url);
    //Audio errors...
    //    kAudioFileUnspecifiedError                        = 'wht?',        // 0x7768743F, 2003334207
    //    kAudioFileUnsupportedFileTypeError                 = 'typ?',        // 0x7479703F, 1954115647
    //    kAudioFileUnsupportedDataFormatError             = 'fmt?',        // 0x666D743F, 1718449215
    //    kAudioFileUnsupportedPropertyError                 = 'pty?',        // 0x7074793F, 1886681407
    //    kAudioFileBadPropertySizeError                     = '!siz',        // 0x2173697A,  561211770
    //    kAudioFilePermissionsError                         = 'prm?',        // 0x70726D3F, 1886547263
    //    kAudioFileNotOptimizedError                        = 'optm',        // 0x6F70746D, 1869640813
    //    // file format specific error codes
    //    kAudioFileInvalidChunkError                        = 'chk?',        // 0x63686B3F, 1667787583
    //    kAudioFileDoesNotAllow64BitDataSizeError        = 'off?',        // 0x6F66663F, 1868981823
    //    kAudioFileInvalidPacketOffsetError                = 'pck?',        // 0x70636B3F, 1885563711
    //    kAudioFileInvalidPacketDependencyError            = 'dep?',        // 0x6465703F, 1684369471
    //    kAudioFileInvalidFileError                        = 'dta?',        // 0x6474613F, 1685348671

    //int x = kAudioFileInvalidChunkError;
    NSLog(@" create auidio file %@",recURL);
    err = AudioFileCreateWithURL( (__bridge CFURLRef)recURL,
                                 kAudioFileCAFType,
                                 &outFormat, 
                                 kAudioFileFlags_EraseFile, 
                                 &fileID);
    //WTF? no error on overwrite?
    if (err)
    {
        memcpy(errc,&err,4);
        NSLog(@" error on AudioFileCreateWithURL , code %d %s",err,errc);
    }
    
    err=AudioFileWritePackets (	fileID,
                               FALSE,
                               bytesize,   // byte size?
                               NULL ,
                               0,           // start at zero packets...
                               &packetsize,  //# packets
                               audioRecBuffer);	
    
    if (err) memcpy(errc,&err,4);
    //if (err) NSLog(@" error on AudioFileWritePackets , code %d %s",err,errc);
    if (err) NSLog(@" ...writeOutputSampleFile err %d, %d bytes",err,(int)bytesize);
	AudioFileClose(fileID);
    if (!err) needToMailAudioFile=1;
} //end writeOutputSampleFile


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 4/27/21: just like loadSample but returns dictionary w/ header info
- (NSDictionary*) getSampleHeader:(NSString *)soundFilePath 
{
    AudioFileID fileID; //DHS 11/12
    OSStatus err;
    int sws;
    UInt32 theSize,outNumBytes,readsize;
    UInt64 packetCount,bCount;
    NSURL *fileURL = nil;
    AudioStreamBasicDescription outFormat;
    UInt32 thePropSize = sizeof(outFormat);
    fileURL = [[NSURL alloc] initFileURLWithPath: soundFilePath];
    //NSLog(@" sample file url %@",fileURL);
    err = AudioFileOpenURL ((__bridge CFURLRef) fileURL, kAudioFileReadPermission,0,&fileID);

    //on mp4 files, (.mov)? getting error 1954115647
    //Use of unresolved identifier 'NSDataReadingMappedIfSafe'
    if (err)
    {
        NSLog(@"getSampleHeader load err : %x",err);
        return nil;
    }
    // NSLog(@"File ID %d %x",fileID,fileID);
    // read size and format
    //Sept 19, 2019 : WTF! New samples 44.1K dont load. only 11025 works!
    AudioFileGetProperty(fileID, kAudioFilePropertyDataFormat, &thePropSize, &outFormat);
    lastSampleRate = (int)outFormat.mSampleRate; //DHS 10/5
    //5/17 bitRate is never used!
    //err = AudioFileGetProperty(fileID, kAudioFilePropertyBitRate,
    //                           &theSize, &bitRate);
    //NSLog(@" ...samplerate %d vs bitrate %d",lastSampleRate,bitRate);
    // if (outFormat.mFormatID == kAudioFormatMPEG4AAC)  NSLog(@" ..found mp4 format..");
    // if (outFormat.mFormatID == kAudioFormatLinearPCM) NSLog(@" ..found linear PCM format..");
    sChans = outFormat.mChannelsPerFrame;
    theSize = sizeof(packetCount);
    err = AudioFileGetProperty(fileID, kAudioFilePropertyAudioDataPacketCount,
                               &theSize, &packetCount);
//    NSLog(@"LoadSamle:[%@]duration %4.2f mSampleRate %d packetCount %llu mBytesPerPacket %d chans %d",name,
//          (float)(packetCount/sChans)/(float)outFormat.mSampleRate,
//          (int)outFormat.mSampleRate,packetCount,(int)outFormat.mBytesPerPacket,outFormat.mChannelsPerFrame);
    bCount = 0;
    theSize = sizeof(bCount);
    if (!err) err = AudioFileGetProperty(fileID, kAudioFilePropertyAudioDataByteCount,
                               &theSize, &bCount);
    sPacketSize = (int)bCount;
    sNumPackets = (int)packetCount;

    //OK, short data!
    sws = sNumPackets * sChans * sizeof(short);
    fileBufferSize = sNumPackets * sChans;    //4/29
    readsize = sNumPackets * sChans;
    outNumBytes = -1;
    sampleSize =outNumBytes; //DHS 10/6 was readsize;
    //NSLog(@" ...load sample OK, size %d vs outnumbytes %d",readsize,outNumBytes);
    if (!err)  AudioFileClose(fileID);

    NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:
                       [NSNumber numberWithInt:sChans],@"channels",
                       [NSNumber numberWithInt:sNumPackets],@"packets",
                       [NSNumber numberWithInt:lastSampleRate],@"samplerate",
                       nil];
    return d;
    
} //end getSampleHeader


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 4/29/13: Add web support?
// 5/31/13: Add nils to fileid/fileurl, fix possible corruption bug
- (void)loadSample:(NSString *)name :(NSString *)type
{
    AudioFileID fileID; //DHS 11/12
    OSStatus err;
	int sws;
	UInt32 theSize,outNumBytes,readsize,bitRate; //5/17 bitRate was wrong
	UInt64 packetCount,bCount;
    NSURL *fileURL = nil;
	AudioStreamBasicDescription outFormat;
	UInt32 thePropSize = sizeof(outFormat);
    if (fileBuffer == NULL) //no memory?
    {
        fileBufferSize = 0;     //4/29
        NSLog(@"loadSample ERROR filebuffer unallocated!");
        return;
    }
    //NSLog(@" loadSample %@ type %@",name,type);
    if ([type  isEqual: @"WEB"] || [type  isEqual: @"USR"]) //6/22 web or user content?
        {
            if (name == NULL) return;
            fileURL = [[NSURL alloc] initFileURLWithPath: name];  //file not found!
        }
    else
        {
            NSString *soundFilePath  = [[NSBundle mainBundle] pathForResource:name ofType:type];
            if (soundFilePath == NULL)
            {   NSLog(@" ..sample load: bad path %@.%@",name,type);
                return;
            }
           fileURL = [[NSURL alloc] initFileURLWithPath: soundFilePath];
        }
    //NSLog(@" sample file url %@",fileURL);
    
    if ([name containsString:@"222"])
    {
        NSLog(@" found weird one");
    }
    
    err = AudioFileOpenURL ((__bridge CFURLRef) fileURL, kAudioFileReadPermission,0,&fileID);

    //on mp4 files, (.mov)? getting error 1954115647
    //Use of unresolved identifier 'NSDataReadingMappedIfSafe' 
	if (err)
	{
        NSLog(@" sample load err : %x",err);
		return;
	}
	// NSLog(@"File ID %d %x",fileID,fileID);
	// read size and format
    //Sept 19, 2019 : WTF! New samples 44.1K dont load. only 11025 works!
	AudioFileGetProperty(fileID, kAudioFilePropertyDataFormat, &thePropSize, &outFormat);
    lastSampleRate = (int)outFormat.mSampleRate; //DHS 10/5
    theSize = sizeof(bitRate); //5/17 wups wrong size!
    err = AudioFileGetProperty(fileID, kAudioFilePropertyBitRate,
                               &theSize, &bitRate);
	//NSLog(@" ...samplerate %d vs bitrate %d",lastSampleRate,bitRate);
	// if (outFormat.mFormatID == kAudioFormatMPEG4AAC)  NSLog(@" ..found mp4 format..");
	// if (outFormat.mFormatID == kAudioFormatLinearPCM) NSLog(@" ..found linear PCM format..");
	sChans = outFormat.mChannelsPerFrame;
	theSize = sizeof(packetCount);
	err = AudioFileGetProperty(fileID, kAudioFilePropertyAudioDataPacketCount,
							   &theSize, &packetCount);	
//    NSLog(@"LoadSamle:[%@]duration %4.2f mSampleRate %d packetCount %llu mBytesPerPacket %d chans %d",name,
//          (float)(packetCount/sChans)/(float)outFormat.mSampleRate,
//          (int)outFormat.mSampleRate,packetCount,(int)outFormat.mBytesPerPacket,outFormat.mChannelsPerFrame);
    bCount = 0;
	theSize = sizeof(bCount);
	if (!err) err = AudioFileGetProperty(fileID, kAudioFilePropertyAudioDataByteCount,
							   &theSize, &bCount);
	sPacketSize = (int)bCount;
	sNumPackets = (int)packetCount;
	//NSLog(@" loadSample: sNumPackets %d   sChans %d bcount %d max %d",sNumPackets, sChans,bCount,MAX_SAMPLE_SIZE);
    //DHS we have to tell caller about this!!!
	if (bCount > MAX_SAMPLE_SIZE) 
	{
         gotSample = 0;
		 //NSLog(@"Sample file too big! (over %d)  %d",MAX_SAMPLE_SIZE,(int)bCount);
		 return;	
	}
	//OK, short data!
    sws = sNumPackets * sChans * sizeof(short);
    fileBufferSize = sNumPackets * sChans;     //4/29
    readsize = sNumPackets * sChans;
    outNumBytes = -1;

    //4/29/21 handle 32 bit samples...
    int bytesPerSample = 2;
    if (sNumPackets > 0 && sChans > 0) bytesPerSample = sPacketSize / (sNumPackets*sChans);
    // 4/29 read any type of file into fileBuffer
    if (!err) err = AudioFileReadPacketData(fileID, FALSE, &outNumBytes, NULL, 0, &readsize, fileBuffer);
    sampleSize =readsize*bytesPerSample; //DHS 4/29 redo yet again
    //NSLog(@" ...load sample OK, size %d vs outnumbytes %d",readsize,outNumBytes);
	if (!err)  AudioFileClose(fileID);
    gotSample = 1;
    //if (err != 0) NSLog(@" loadsample error: %d",(int)err);
    return;
	
} //end loadSample

//static char *FormatError(char *str, OSStatus error)
//{
//    // see if it appears to be a 4-char-code
//    *(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
//    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
//        str[0] = str[5] = '\'';
//        str[6] = '\0';
//    } else {
//        // no, format it as an integer
//        sprintf(str, "%d", (int)error);
//    }
//    return str;
//}


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 9/21 Local load from path... NOT USED in oogieCam, needs updating
- (void)loadSampleFromPath : (NSString *)subFolder : (NSString *)fileName
{
    AudioFileID fileID; //DHS 11/12
    OSStatus err;
    int sws;
    char duhchar[8];
    UInt32 theSize,outNumBytes,readsize;
    UInt64 packetCount,bCount;
    //NSURL *fileURL = nil;
    AudioStreamBasicDescription outFormat;
    UInt32 thePropSize = sizeof(outFormat);
    //Start at main bundle...
    NSURL *path = NSBundle.mainBundle.resourceURL;
    //add subfolder...
    NSURL *p2 = [path URLByAppendingPathComponent:subFolder];
    //aaand filename...
    NSURL *sampleURL = [p2 URLByAppendingPathComponent:fileName];
    
    err = AudioFileOpenURL ((__bridge CFURLRef) sampleURL, kAudioFileReadPermission,0,&fileID);
    
    if (err)
    {
        //if (err == kAudioFileFileNotFoundError)
            NSLog(@" ..sample file load err %d",(int)err);
        return;
    }
    //Get format, size
    AudioFileGetProperty(fileID, kAudioFilePropertyDataFormat, &thePropSize, &outFormat);
    lastSampleRate = (int)outFormat.mSampleRate; //DHS 10/5
    theSize = outFormat.mFormatID;
    memcpy(duhchar,&theSize,4);
    // if (outFormat.mFormatID == kAudioFormatMPEG4AAC)  NSLog(@" ..found mp4 format..");
    // if (outFormat.mFormatID == kAudioFormatLinearPCM) NSLog(@" ..found linear PCM format..");
    sChans = outFormat.mChannelsPerFrame;
    theSize = sizeof(packetCount);
    err = AudioFileGetProperty(fileID, kAudioFilePropertyAudioDataPacketCount,
                               &theSize, &packetCount);
    bCount = 0;
    theSize = sizeof(bCount);
    if (!err) err = AudioFileGetProperty(fileID, kAudioFilePropertyAudioDataByteCount,
                                         &theSize, &bCount);
    //NSLog(@"ERRR 3 %d",err);
    sPacketSize = (int)bCount;
    sNumPackets = (int)packetCount;
    //DHS we have to tell caller about this!!!
    if (bCount > MAX_SAMPLE_SIZE)
    {
        gotSample = 0;
        //NSLog(@"Sample file too big! (over %d)  %d",MAX_SAMPLE_SIZE,(int)bCount);
        return;
    }
    //OK, short data!
    sws = sNumPackets * sChans * sizeof(short);
    fileBufferSize = sNumPackets * sChans;  //4/29

    NSLog(@"..... samplerate %d",lastSampleRate);
    readsize = sNumPackets * sChans;
    outNumBytes = 0; //DHS 10/10 init to avoid warning
    //DHS 10/10 use this call! not ...PacketData
    if (!err)err = AudioFileReadPackets (fileID,FALSE,&outNumBytes,NULL,0,&readsize,fileBuffer);
    sampleSize =  readsize;
    if (!err)  AudioFileClose(fileID);
    gotSample = 1;
    if (err != 0) NSLog(@" loadsample error: %d [%@]",(int)err,fileName);
    //else NSLog(@" ...load sample OK");
    //    NSLog(@" dump of sample %@========================",fileName);
    //    for (int i=0;i<64;i++) NSLog(@" swave[%d] %x",i,swave[i]);
    return;
    
} //end loadSampleFromPath


/*-----------------------------------------------------------*/  
/*-----------------------------------------------------------*/   
double drand(double lo_range,double hi_range )
{ 
	int rand_int;  
	double tempd,outd;  
	
	rand_int = rand();  
	tempd = (double)rand_int/(double)RAND_MAX;  /* 0.0 <--> 1.0*/  
	
	outd = (double)(lo_range + (hi_range-lo_range)*tempd);  
	return(outd);  
}   //end drand

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
-(void) doogitie  : (NSString *)name : (int) whichBuffer
{
    NSLog(@" doogieite");
    NSString * source = [[NSBundle mainBundle] pathForResource:name ofType:@"wav"]; // SPECIFY YOUR FILE FORMAT
    
    const char *cString = [source cStringUsingEncoding:NSASCIIStringEncoding];
    
    CFStringRef str = CFStringCreateWithCString(
                                                NULL,
                                                cString,
                                                kCFStringEncodingMacRoman
                                                );
    CFURLRef inputFileURL = CFURLCreateWithFileSystemPath(
                                                          kCFAllocatorDefault,
                                                          str,
                                                          kCFURLPOSIXPathStyle,
                                                          false
                                                          );
    
    ExtAudioFileRef fileRef;
    ExtAudioFileOpenURL(inputFileURL, &fileRef);
    
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate = DEFAULT_SAMPLE_RATE;   // GIVE YOUR SAMPLING RATE
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kLinearPCMFormatFlagIsFloat;
    audioFormat.mBitsPerChannel = sizeof(Float32) * 8;
    audioFormat.mChannelsPerFrame = 2; // Mono
    audioFormat.mBytesPerFrame = audioFormat.mChannelsPerFrame * sizeof(Float32);  // == sizeof(Float32)
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mBytesPerPacket = audioFormat.mFramesPerPacket * audioFormat.mBytesPerFrame; // = sizeof(Float32)
    
    // 3) Apply audio format to the Extended Audio File
    ExtAudioFileSetProperty(
                            fileRef,
                            kExtAudioFileProperty_ClientDataFormat,
                            sizeof (AudioStreamBasicDescription), //= audioFormat
                            &audioFormat);
    
    int numSamples = 1024; //How many samples to read in at a time
    UInt32 sizePerPacket = audioFormat.mBytesPerPacket; // = sizeof(Float32) = 32bytes
    UInt32 packetsPerBuffer = numSamples;
    UInt32 outputBufferSize = packetsPerBuffer * sizePerPacket;
    
    // So the lvalue of outputBuffer is the memory location where we have reserved space
    UInt8 *outputBuffer = (UInt8 *)malloc(sizeof(UInt8 *) * outputBufferSize);
    
    AudioBufferList convertedData ;//= malloc(sizeof(convertedData));
    
    convertedData.mNumberBuffers = 1;    // Set this to 1 for mono
    convertedData.mBuffers[0].mNumberChannels = audioFormat.mChannelsPerFrame;  //also = 1
    convertedData.mBuffers[0].mDataByteSize = outputBufferSize;
    convertedData.mBuffers[0].mData = outputBuffer; //

    UInt32 frameCount = numSamples;
    float *samplesAsCArray;
    int j =0;
    
    while (frameCount > 0) {
        ExtAudioFileRead(
                         fileRef,
                         &frameCount,
                         &convertedData
                         );
        if (frameCount > 0)  {
            AudioBuffer audioBuffer = convertedData.mBuffers[0];
            samplesAsCArray = (float *)audioBuffer.mData; // CAST YOUR mData INTO FLOAT
            
            for (int i =0; i< numSamples ; i++) { //YOU CAN PUT numSamples INTEAD OF 1024
                
                workBuffer[j] = (double)samplesAsCArray[i] ; //PUT YOUR DATA INTO FLOAT ARRAY
                //printf("\n%f",workBuffer[j]);  //PRINT YOUR ARRAY'S DATA IN FLOAT FORM RANGING -1 TO +1
                j++;
            } //end for i
        } //end frameCount > 0
    }  //end while
    sBufs[whichBuffer] = malloc(j * sizeof(float));
    if (!sBufs[whichBuffer]) return;
    //ok we have data, convert it! to unsigned short
    for (int i=0;i<j;i++)
    {
        double df = workBuffer[i];
        //df = 32767.0 * (df + 0.5);
        sBufs[whichBuffer][i] = (float)df + 0.5;
    }
// 4/26 cleanup
//    for (int i=0;i<256;i++)
//        NSLog(@" wb[%d] %f -> %f",i,workBuffer[i],sBufs[whichBuffer][i]);

}


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
-(int)isRecording
{
    return recording;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
-(void)startRecording:(int)maxRecordingTime
{
    //DHS 7/13/13
    if (recording) return;
    if (maxRecordingTime == 0)
    {
    //    NSLog(@" ERROR! zero record length! ...default to 5 secs");
        maxRecordingTime = 5; //10 secs by default?
    }
    reclength = maxRecordingTime;

    //OK, we need to alloc. a buffer!
    recsize = maxRecordingTime * DEFAULT_SAMPLE_RATE * 2 * sizeof(short);
    //NSLog(@"...record %d secs, alloc %d bytes audioRecBuffer",maxRecordingTime,recsize);
    audioRecBuffer = (short *)malloc(recsize);
    if (0 && audioRecBuffer != NULL)
    {
     //NSLog(@" ...alloc %d bytes OK, buffer %x",recsize,(unsigned int)audioRecBuffer);
    }
    recptr=0;
    recording = 1;
} //end startRecording

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
-(void) pauseRecording
{
    recording = FALSE;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
-(void) unpauseRecording
{
    recording = TRUE;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// stops recording, writes if cancel is zero
-(void)stopRecording:(int)cancel
{
    if (!recording) return;
    if (!cancel)
    {
        [self writeOutputSampleFile];
    }
    if (audioRecBuffer)  //clear storage
    {
        free(audioRecBuffer);
        audioRecBuffer=NULL;
    }
    recording=0;
    //need to stop and save/nosave samplefile
} //end stopRecording

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
-(void) dumpTone : (int) which
{
    ToneEvent t = tones[which];
    NSLog(@" Tone Dump %d ============================",which);
    NSLog(@" midiNote/pitch/phase %d %f %f",t.midiNote,t.pitch,t.phase);
    NSLog(@" adsr %d %d %d %d needsEnvelope %d",t.envAttack,t.envDecay,t.envSustain,t.envRelease,t.needsEnvelope);
    NSLog(@" type/wave/mono/detune %d %d %d %d",t.toneType,t.waveNum,t.mono,t.detune);
    NSLog(@" envStep/Delta/gain/lpan/rpan  %f %f %f %f %f",t.envStep,t.envDelta,t.gain,t.lpan,t.rpan);
    NSLog(@" port lastNote/Time/PitchFinish/PitchStep %d %f %f %f",
          t.portamentoLastNote,t.portamentoTime,t.portamentoPitchFinish,t.portamentoPitchStep);
    NSLog(@" vib ampl/wave/speed/delay  %d %d %d %d",t.vibAmpl,t.vibWave,t.vibSpeed,t.vibDelay );
    NSLog(@" vib enabled/index/step %d %f %f",t.vibEnabled,t.vibIndex,t.vibStep );
    NSLog(@" vibe ampl/wave/speed/delay  %d %d %d %d",t.vibeAmpl,t.vibeWave,t.vibeSpeed,t.vibeDelay );
    NSLog(@" timetrax/portcount/un/infinite %d %d %d %d",t.timetrax,t.portcount,t.un,t.infinite);
}

//DHS 10/10/19 el dumpo
//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
-(void) dumpBuffer : (int) which : (int) dsize
{
    NSLog(@"Buffer[%d] dump, fullsize %d",which,sBufLens[which]);
    for (int i=0;i<dsize;i++)
    {
        NSLog(@"...b[%d] : %f",i,sBufs[which][i]);
    }
}

@end
