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
#import <QuartzCore/CABase.h>
#import "SynthDave.h"
#include "oogieMidiStubs.h"
#include <time.h>
#include "cheat.h"

//SPECIAL ARC flag, set this if we are NOT using ARC
#define ARC_OFF



int midion = 1;

float ATTACK_TIME   = 0.004f;
float DECAY_TIME    = 0.002f;
float SUSTAIN_LEVEL = 0.8f;
float SUSTAIN_TIME  = 0.04f;
float RELEASE_TIME  = 0.05f;
float DUTY_TIME     = 0.5f;
float SAMPLE_OFFSET = 0.0f;

double *workBuffer; //9/20

@interface Synth (Private)
- (void)equalTemperament;
@end

#define SYNTH_TS 500.0  // was 1000 Converts percentage synth params to real-time...
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
unsigned short *swave = NULL;
int swaveSize;
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
-(int)isRecording
{
	return recording;
    
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
-(void)startRecording:(int)newlen
{
    //DHS 7/13/13
    if (recording) return;
    if (newlen == 0)
    {
    //    NSLog(@" ERROR! zero record length! ...default to 5 secs");
        newlen = 5;
    }
     reclength = newlen;
    //OK, we need to alloc. a buffer!
    recsize = newlen * 11025 * 2 * sizeof(short);
    //NSLog(@"...record %d secs, alloc %d bytes audioRecBuffer",newlen,recsize);
    audioRecBuffer = (short *)malloc(recsize);
    if (0 && audioRecBuffer != NULL)
    {
     //NSLog(@" ...alloc %d bytes OK, buffer %x",recsize,(unsigned int)audioRecBuffer);   
    }
    recptr=0;
    recording = 1;
} //end startRecording

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// stops recording, writes if cancel is zero
-(void)stopRecording:(int)cancel
{
    if (!recording) return;
    if (!cancel)
    {
       //NSLog(@" ...done recording, write output...");   
        //WRITE FILE HERE
        [self writeOutputSampleFile:@"dog.caf":@".caf"];
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
- (id)initWithSampleRate:(float)sampleRate_
{
	int loop;
    //NSLog(@"  initWithSampleRate : %f",sampleRate_);
	if ((self = [super init]))
	{
		sampleRate          = (float)sampleRate_;
        //NSLog(@" init all, samplrate %f",sampleRate);
		_gain                = 0.59f; //OVERall gain factor
		finalMixGain        = 1.0;
		gotSample           = 0;
		swave               = NULL; //temp sample file storage....
        swaveSize           = 0;
		glpan = grpan       = 0.5;  //set to center pan for now
        gportlast           = 64;  //last note; default to center of keyboard        
        uniqueVoiceCounter  = 0; 
        monoLastUnique      = 0;
        masterLevel         = 1.0;
        timetrax            = 0;
        queuePtr            = 0; //DHS 1/19 start with empty note queue
        arpPtr              = 0; //DHS 3/16/15: Arpeggiator...
        arpPlayPtr          = 0; //DHS 3/16/15: Arpeggiator...
        newUnique           = 0;
        aFactor             = 0.0f;
        bFactor             = 0.0f;
        recording = reclength = recptr = recsize = 0;
        copyingBuffer = copyingEnvelope = -1;
        //NSLog(@" null out audioRecBuffer...");
        audioRecBuffer = NULL;       
        recFileName = NULL;
        needToMailAudioFile=0;
		LOOPIT(MAX_SAMPLES)
		{
			sBufs[loop]		= NULL;
			sBufLens[loop]  = -1;
            sRates[loop]    = -1;
			sBufChans[loop] = -1;
			sEnvs[loop]		= NULL;
            sElen[loop]     = 0;
            envIsUp[loop]   = 0;
            envLength[loop]   = 0;
            envDataLength[loop] = 0; //10/17
		}
		LOOPIT(MAX_TONE_EVENTS)tones[loop].state = STATE_INACTIVE;		

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
        
        arptimer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(arptimerTick:) userInfo:nil repeats:YES];

	}

    
	return self;
} //end initWithSampleRate


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)dealloc
{
	int loop;
    NSLog(@" dealloc: Free all");
	if (swave != NULL) 
	{
		free(swave);
        swaveSize = 0;
		swave = NULL;
	}
	LOOPIT(MAX_SAMPLES)
	if (sBufs[loop] != NULL)
	{
		free(sBufs[loop]);
		sBufs[loop] = NULL;
	}
	LOOPIT(MAX_SAMPLES)
	if (sEnvs[loop] != NULL)
	{
		free(sEnvs[loop]);
		sEnvs[loop] = NULL;
        sElen[loop] = 0;
	}
}


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)arptimerTick:(NSTimer *)timer
{
    
    if (arpPlayPtr != arpPtr)  //IS there some stuff to play?
    {
        double latestTime = CACurrentMediaTime();
        int latestdelay   = arpQueue[ARP_PARAM_TIME][arpPlayPtr];
        double isitTime   = arpTime + (double)latestdelay/1000.0; //Add ms delay..
        if (latestTime > isitTime) //Time to play!
        {
            int a,b,c;
            a         = arpQueue[ARP_PARAM_NOTE][arpPlayPtr];
            b         = arpQueue[ARP_PARAM_WNUM][arpPlayPtr];
            c         = arpQueue[ARP_PARAM_TYPE][arpPlayPtr];
            _gain      = arpQueue[ARP_PARAM_GAIN][arpPlayPtr];
            _mono      = arpQueue[ARP_PARAM_MONO][arpPlayPtr];
            glpan     = arpQueue[ARP_PARAM_LPAN][arpPlayPtr];
            grpan     = arpQueue[ARP_PARAM_RPAN][arpPlayPtr];
            //NSLog(@" arp delay %d note %d %d %d at %f lt %f izit %f",latestdelay,a,b,c,arpTime,latestTime,isitTime);
            [self playNote:a:b:c];
            arpPlayPtr++;
            if (arpPlayPtr >= MAX_ARP) //Wraparound!
                arpPlayPtr = 0;
            arpTime  = latestTime;
        }
    }
} //end arptimerTick

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
	for (int n = 0; n < 256; ++n)
		pitches[n] = 440.0f * powf(2, ((float)n + masterTune - 69.0)/12.0f);  // A4 = MIDI key 69

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

    //NSLog(@"  Synth: buildwave %d type %d",which,type);
	switch(type)
	{
		case 0: [self buildRampTable:which];
			break;
		case 1: [self buildSineTable:which];
			break;
		case 2: [self buildSawTable:which];
			break;
		case 3: [self buildSquareTable:which];
			break;
        case 4: [self buildNoiseTable:which];
			break;
		case 5: [self buildSinXCosYTable:which];
            break;
        default: [self buildRampTable:which];
			break;
	}
    sRates[which]   = 44100;  //10/5 is this right? or is it 11025?

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
- (void)buildSampleTable:(int)which
{
    int err=0;
	Float32 cFrame;
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
    //NSLog(@" ...Malloc sbufs[%d] size %lu",which,sNumPackets * sChans * sizeof(float));
	sBufs[which] = malloc(totalFrames * sizeof(float)); //DHS 10/6
	if (!sBufs[which]) return;
    sBufLens[which] = totalFrames;
    //NSLog(@" ...Buildsample[%d]: frames %d  ",which,totalFrames);

    for ( i = 0; i < sBufLens[which]; i+=sChans)  // step through by #channels per packet
	{	
        if (i >= swaveSize) 
        {
            NSLog(@" ...sample overflow: buffer %d index %d maxsize %d",which,i,swaveSize);
            err=1;
            break;   
        }
        memcpy(&ts,&swave[i],2);  //dest,source,len...
        cFrame = (float)ts / 32768.0f;
        sBufs[which][i] = cFrame; //store our data...
        if (sChans == 1)
            memcpy(&ts,&swave[i],2);  //dest,source,len...
        else
            memcpy(&ts,&swave[i+1],2);  //dest,source,len...
        cFrame = (float)ts / 32768.0f;
        sBufs[which][i+1] = cFrame; //store our data...
        //if (0 &&  i%128 == 0)
        //	NSLog(@" bsw[%d] swave %d ts %d cFrame %f",i,swave[i],ts,cFrame);
    }
    //DHS 10/5 WTF? Sample rates seem to vary widely!
    int properRate = 44100;
    if (lastSampleRate > 11000 && lastSampleRate < 12000) properRate = 11025;
    NSLog(@"SAMPLE RATES lsr %d rate %d",lastSampleRate,properRate);
    sRates[which]   = properRate;
    if (err) sBufLens[which] = 8192; //STOOPID SIZE!
	sBufChans[which] = 2; //always stereo
	return;
} //end buildSampleTable


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
//    NSLog(@"copy envelope from %d to %d",from,to);
    //Free mem if needed
    if (sEnvs[to] != NULL)
    {
        free(sEnvs[to]);
        sEnvs[to] = NULL;
    }
    int elen = envLength[from];
    sEnvs[to] = malloc(elen * sizeof(float));
    if (!sEnvs[to]) return;
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
    if (size < 2 || envLength[which] < 2) return nil;
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
	// All envelopes are same length, with data from 0.0 to 1.0. 
	//  Each synth voice will have a corresponding envelope? 
	// Because lower tones last longer than higher tones, we will use a delta
	// value to step through this table. MIDI note number 64 has delta = 1.0f.
	float envsave;
	int i,savei,esize;
    attackLength  = (int)(ATTACK_TIME  * sampleRate);  // attack
    decayLength   = (int)(DECAY_TIME   * sampleRate);  // decay
    sustainLength = (int)(SUSTAIN_TIME * sampleRate);  // sustain
    releaseLength = (int)(RELEASE_TIME * sampleRate);  // release
    //DHS 11/16 zero envelope? BailL!
    if ( (attackLength  == 0) && (decayLength   == 0) &&
         (sustainLength == 0) && (releaseLength == 0) )
    {
        NSLog(@"  ...allzero ENV %d...",which);
        return;
    }
    //envelope was in use? Clobber it!
    if (sEnvs[which] != NULL && !buildInPlace)
    {
        NSLog(@"  ...free env %d...",which);
        free(sEnvs[which]);
        sEnvs[which] = NULL;
    }
    envLength[which] = (int)sampleRate * 2;  // 2? seconds DHS MAKE IT BIG
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
	
//	NSLog(@" TOP ADSR============= %d %d %d %d %f",
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
//    for (int i=0;i<256;i++)
//    {
//      NSLog(@" ...env[%d] %f",i,sEnvs[which][i]);
//    }
    //DHS WHY doesn't i already have the length here...???
	envDataLength[which] = i + releaseLength;
}  //end buildEnvelope


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
{   // 64 is middle C..... so base C is 4, plus five octaves...
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
// DHS 1/19 .... add note queue for quantizing....
//   Loop through the queue, and play all notes therein... 
- (void)emptyQueue  
{
    int loop,a,b,c;
    if (!queuePtr) return;
    //NSLog(@"  emptyq, size  %d",queuePtr);
    //if (queuePtr > 250) 
    //    NSLog(@" warning:biggg queueptr: %d",queuePtr);
    LOOPIT(queuePtr)
    {
        a         = noteQueue[0][loop];
        b         = noteQueue[1][loop];
        c         = noteQueue[2][loop];
        _gain      = noteQueue[3][loop];
        _mono      = noteQueue[4][loop];
        glpan     = noteQueue[5][loop];
        grpan     = noteQueue[6][loop];
        gporto    = noteQueue[7][loop];
        gportlast = noteQueue[8][loop];
        //newUnique = noteQueue[9][loop];

        [self playNote:a:b:c];
    }
    queuePtr = 0; //OK! Queue is empty...    
} //end emptyQueue


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// DHS 1/19  .... add note queue for quantizing....
- (void)queueNote:(int)midiNote :(int)wnum :(int)type
{
     //   NSLog(@"  qn %d %d g %f",wnum,type,gain);
    //OK! add our 3 params to the queue...
#if 1 //Shut this off if queue is bad...
    if (queuePtr < MAX_QUEUE-1)
    {
        noteQueue[0][queuePtr] = midiNote;
        noteQueue[1][queuePtr] = wnum;
        noteQueue[2][queuePtr] = type;
        noteQueue[3][queuePtr] = _gain;
        noteQueue[4][queuePtr] = _mono;
        noteQueue[5][queuePtr] = glpan;
        noteQueue[6][queuePtr] = grpan;
        noteQueue[7][queuePtr] = gporto;
        noteQueue[8][queuePtr] = gportlast;
        //noteQueue[9][queuePtr] = newUnique;
        queuePtr++;
    }
#endif    
   // DHS put this back if queue is broken... [self playNote:midiNote:wnum:type];
} //end queueNote


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)resetArp
{
    arpPtr  = arpPlayPtr = 0;
    arpTime = CACurrentMediaTime();
}



//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// DHS 3-16-15: Used to create arpeggiated sequences...
//   the arpQueue is a circular queue!
- (void)playNoteWithDelay : (int) midiNote : (int) wnum : (int) type : (int) delayms
{
    
    if (arpPtr == MAX_ARP-1) //Wraparound!
        arpPtr = 0;
    arpQueue[ARP_PARAM_NOTE][arpPtr] = midiNote;  //Similar to note queue but with timers...
    arpQueue[ARP_PARAM_WNUM][arpPtr] = wnum;
    arpQueue[ARP_PARAM_TYPE][arpPtr] = type;
    arpQueue[ARP_PARAM_GAIN][arpPtr] = _gain;
    arpQueue[ARP_PARAM_MONO][arpPtr] = _mono;
    arpQueue[ARP_PARAM_LPAN][arpPtr] = glpan;
    arpQueue[ARP_PARAM_RPAN][arpPtr] = grpan;
    arpQueue[ARP_PARAM_TIME][arpPtr] = delayms;
    arpPtr++;

} //end playNoteWithDelay



//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// DHS 11-9 need to change to support mono synth...
- (void)playNote:(int)midiNote :(int)wnum :(int)type
{
    int n,foundit=0;
    newUnique++;
//    NSLog(@"...play note %d, duration %4.2f type %d, buf %d , srate %d, blen %d dt %d mlevel %f",
//                       midiNote,
//                    (float)(sBufLens[wnum]/2)/(float)sRates[wnum],
//                    type,wnum,sRates[wnum],sBufLens[wnum],detune,masterLevel);
	if (sBufLens[wnum] <= 0)
    {
        NSLog(@" ERROR: buffer[%d] empty",wnum); //DHS 9/18 diagnostic, delete later    
        return;
    }
    //DHS 11/22 does this work on non-pitch shifted samples???
    if (sRates[wnum] == 11025)
    {
        midiNote -= 24;
        detune = TRUE; //force detune for weird sample rates
    }
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
                //NSLog(@"  tone n %d wn %d un %d",n,tones[n].waveNum,tones[n].un);
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
        tones[n].midiNote = midiNote;
        tones[n].phase    = 0.0f; 
        tones[n].pitch    = pitches[midiNote];
        //NSLog(@".. note %d ,pitch %f   ",midiNote, pitches[midiNote]);
        [self incrVoiceCount:n];
        if (type == SAMPLE_VOICE)
        { if (detune)
            tones[n].phase    = (int)((float)SAMPLE_OFFSET * 0.005 * (float)sBufLens[wnum]); //compute offset
        }
        tones[n].envStep  = 0.0f;
        tones[n].envDelta = midiNote / 64.0f;
        tones[n].waveNum  = wnum;	
        tones[n].toneType = type;	
        tones[n].gain	  = _gain * finalMixGain;
        tones[n].detune	  = detune;
        tones[n].mono 	  = _mono;
        tones[n].lpan     = glpan;	 //see setPan!
        tones[n].rpan     = grpan;	 //see setPan!	
        tones[n].portval  = 0;
        tones[n].timetrax = timetrax;
        tones[n].infinite = 0;
        if (type == SYNTH_VOICE)
        {
            tones[n].infinite = infinite;
        }
        BOOL needsEnvelope = (type == SYNTH_VOICE || type == SAMPLE_VOICE);  
        //11/10 but for all zeroes, bail on envelope!
        if (ATTACK_TIME == 0.0 &&
            DECAY_TIME == 0.0 &&
            SUSTAIN_TIME == 0.0 &&
            RELEASE_TIME == 0.0) needsEnvelope = FALSE;
        tones[n].needsEnvelope = needsEnvelope;
        tones[n].un       = newUnique;

        // DUH! we need to know WHICH synth voice to track during portamento!?!?!
        //if (gporto) //use portamento?  
        //{
        //    tones[n].portcount  = 20;  
        //    tones[n].portstep = (1.0/(float)tones[n].portcount) * 
        //        (tones[n].pitch - pitches[gportlast]) ; //port step val...
        //     NSLog(@" use port: gportlast %d oldpitch %f newpitch %f step %f",
        //     gportlast,pitches[gportlast],tones[n].pitch,tones[n].portstep);
        //      set to zero here to disable portamento
        //    tones[n].portstep= 0.0;
        //    tones[n].portval  = pitches[gportlast];  
        //  NSLog(@" playport note %d gpl %d pstep %f",
        //      midiNote,gportlast,tones[n].portstep);            
        //}
        //else
        //    tones[n].portstep = 999999; //NO portamento
        //tones[n].un = uniqueVoiceCounter; //save this in the tone
        //NSLog(@"  ...got played %d, wnum %d gain %f, fmg %f",midiNote,wnum,gain,finalMixGain);
        if (midion)  //Send out MIDI...
        {
            int vel = (int)(444*_gain);
            if (vel > 127) vel = 127;
            OMSetDevice(midiDev);
            OMPlayNote(midiChan, midiNote, vel );   
        }
    
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
        tones[n].portval      = 0;
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
// Aug 26: OK I want this to KLOBBER ALL audio output!
- (void)releaseAllNotes  
{
	for (int n = 0; n < MAX_TONE_EVENTS; ++n)
	{
        [self releaseNoteByBin:n];
        if (midion) OMEndNote((ItemCount)1, tones[n].midiNote);
	}
    numSVoices = numPVoices = 0;
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
-(NSString *)getAudioOutputFileName
{
    return recFileName;   
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (int)getSVoiceCount 
{
    return numSVoices;
    
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 11/22 add srate to keep track of weird samples rates
-(int) getSRate : (int) bptr
{
    if (bptr < 0 || bptr > MAX_SAMPLES ) return 44100;
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
	float sValue,sValue2,ml,mr,b,sl,sr,envValue;
    
	//double startTime = CACurrentMediaTime();
    sValue = sValue2 = 0.0f; //DHS 7/10/15 Compiler warnings
	// We are going to render the frames one-by-one. For each frame, we loop
	// through all of the active ToneEvents and move them forward a single step
	// in the simulation. We calculate each ToneEvent's individual output and
	// add it to a mix value. Then we write that mix value into the buffer and 
	// repeat this process for the next frame.
	for (f = 0; f < frames; ++f)
	{
		ml = mr = 0.0f;  // the mixed value for this frame
		for (n = 0; n < MAX_TONE_EVENTS; ++n)
		{
            if (tones[n].state != STATE_INACTIVE )
            {
                int duh = 0;
            }
			if (tones[n].state == STATE_MONOFADEOUT)  // fading out in mono mode?
            {
                tones[n].gain *= 0.5; //attenuate gain by half each sample (TUNE IF NEEDED)...
                if (tones[n].gain < 0.09)  //volume below 10%? Outtahere!
                  
                {
                    //NSLog(@" tone %d fadeout",n);
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
            if (tones[n].toneType == SYNTH_VOICE || tones[n].needsEnvelope) //0 - 7: synths...we need an envelope
			{
                if (tones[n].infinite) envValue = 1.0;
                else if (copyingEnvelope != wn) //11/9 don't access envelope on copy!
                {
                    a = (int)tones[n].envStep;   // integer part
                    b = tones[n].envStep - a;  // decimal part
                    c = a + 1;
                    if (c >= envLength[wn])  // don't wrap around
                        c = a;
                    //NSLog(@"wnum %d krashit! a/b/c is %d/%f/%d elen %d",
                    //      wn,a,b,c,envLength[wn]);
                    if (c > sElen[wn])
                        //illegal envelope access!
                    {
                        //if (0) NSLog(@"Illegal Envelope access: eLen[%d] = %d, abc %d %d %d",wn,sElen[wn],a,b,c);
                        //c = 0;
                        envValue = 0.0;
                    }
                    else if (sEnvs[wn] != NULL) //DHS nov 27 add existance check for sEnvs
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
			// Wrap round when we get to the end of the sine look-up table.
			if (tones[n].toneType == SYNTH_VOICE) //0 - 7: synths...
			{
                tones[n].phase += tones[n].pitch;
 				if (((int)tones[n].phase) >= sineLength)
					tones[n].phase -= sineLength;
				if (((int)tones[n].phase) < 0 )
					tones[n].phase += sineLength;
                //if (n == 1) NSLog(@" ... sval %f",sValue);
			}
			//DHS general sampling will have a pitch associated with it!
			else if (tones[n].toneType == SAMPLE_VOICE) //samples ! but not perc!
			{
				//DHS: this coeff gets us close to the initial sample's pitch
				//    when C4 is pressed on the keyboard....
				if (tones[n].detune)  //Detune? use pitch to step thru...
					tones[n].phase += 0.0029*(tones[n].pitch);
				else 
					tones[n].phase++; //NO detune. step thru by onesies...
				if (((int)tones[n].phase*sbc) >= sBufLens[wn]-2) //End sample/tone! DHS 6/6/17 add -1
				{
                    //NSLog(@" ..end tone %d,%d, blen %d",n,wn,sBufLens[wn]);
					tones[n].state   = STATE_INACTIVE;
                    tones[n].waveNum = -1;
                    if (midion) OMEndNote((ItemCount)1, tones[n].midiNote);
					tones[n].phase = 0;
                    [self decrVoiceCount:n];
				}
			}
			else   //percussion samples: NO PITCH
			{   
 				if (tones[n].detune) //tones[n].midiNote != 64)  //Octave shift in percussion??? SHIFTIT!
					tones[n].phase += 0.0029*(tones[n].pitch);
				else 
                    tones[n].phase++; //no octave: step thru by onesies...
                //DHS FOR some reason, percs > 8 NEVER GET HERE!

				if (((int)tones[n].phase*sbc) >= sBufLens[wn]) //End sample/tone!
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
                    {
                        sValue  = (1.0f - b)*sBufs[wn][2*a] + b*sBufs[wn][2*c];
                        sValue2 = (1.0f - b)*sBufs[wn][1+2*a] + b*sBufs[wn][1+2*c];
                    }
                }
                // Calculate the final sample value.
                //  we need to fill Left/Right buffers EVEN with mono samples!
                sl = sValue * envValue * tones[n].gain  * tones[n].lpan;
                //if (lrvolmod % 256 == 0)
                //      NSLog(@" sl: %f %f %f %f",sValue,envValue,tones[n].gain,tones[n].lpan);
                sr = 0;
                if (sbc == 1) //mono...
                    sr = sValue * envValue * tones[n].gain  * tones[n].rpan;
                else if (sbc == 2) //stereo...
                    sr = sValue2 * envValue * tones[n].gain  * tones[n].rpan;
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
 //      if (lrvolmod % 256 == 0)  { NSLog(@" frame %d LR %f %f",f,ml,mr); }
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
    //DHS 2/5/18 comment out block to silence warning
    //OK at this point we have a valid buffer; recording?
//    if (0 && recording)
//    {  int loop,rindex,rsize= f*2 + 1; //number of floats in our buffer...
//        short sval;
//        SInt16 si6;
//        rindex = recptr;
//        LOOPIT(2*frames)
//        {   si6 = (p[loop]);
//            sval = (short) si6;
//            //if (0 && rindex < 256)
//            //    NSLog(@" [%d] pakaudio px %x  si6 %d/%x s %d / %x",
//            //              rindex,p[loop],si6,si6,sval,sval);
//             audioRecBuffer[rindex] = sval;
//            rindex++;
//        }
//        //NSLog(@" ..wrbuf %d",recptr);
//        recptr+=(rsize-1);    //advance ptr
//        if (recptr >= recsize/2)  //DHS why /4?  hmmm why /2?
//        {
//            //NSLog(@" ...bing stop");
//            [self stopRecording:0];
//        }
//    } //end if recording
	//NSLog(@"elapsed %g", CACurrentMediaTime() - startTime);

	return frames;
} //end fillBuffer


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
    NSLog(@" set synth ewavenum %d STYBBED", wnum);
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
    //NSLog(@" set port %d",pn);
    gporto = (float)pn;
}//end setPortamento

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// sets up portamento for a voice, 0 = none, 1 = some (fixed amount for now)
- (void)setPortLast: (int)lastnote 
{
    gportlast = lastnote;
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
 	ATTACK_TIME = (float) newVal/SYNTH_TS;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setDecay: (int)newVal 
{
 	//take our percent val, turn it into our decay val (0 - .1)!!!
 	DECAY_TIME = (float) newVal/SYNTH_TS;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setSustain: (int)newVal 
{
 	//take our percent val, turn it into our sustain val (0 - .1)!!!
 	SUSTAIN_TIME = 5.0 * (float) newVal/SYNTH_TS;
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
 	RELEASE_TIME = (float) newVal/SYNTH_TS;
}


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setDuty: (int)newVal 
{
 	//take our percent val, turn it into our release val (0 - .1)!!!
 	DUTY_TIME = (float) newVal/100.0;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setSampOffset: (int)newVal 
{
 	//take our percent val, turn it into our release val (0 - .1)!!!
 	SAMPLE_OFFSET = (float) newVal/100.0;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setDetune: (int)newVal 
{
 	//take our percent val, turn it into our release val (0 - .1)!!!
 	detune = newVal;
}


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
- (void)writeOutputSampleFile:(NSString *)name :(NSString *)type
{ 	 
    UInt32 bytesize,packetsize;
    int err;
    char errc[8];
	AudioFileID fileID = nil;
	AudioStreamBasicDescription outFormat;

 	recFileName = [NSTemporaryDirectory() stringByAppendingPathComponent:@"oogieAudioDump.caf"];
    //NSLog(@" in dumpAudio...name %@",recFileName);
 	outFormat.mSampleRate		= 11025; 
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
    NSURL* recURL = [NSURL URLWithString:recFileName];
    //NSLog(@" dump %d bytes audio to url:%@",bytesize,url);
    err = AudioFileCreateWithURL( (__bridge CFURLRef)recURL,
                                 kAudioFileCAFType,
                                 &outFormat, 
                                 kAudioFileFlags_EraseFile, 
                                 &fileID);
    
    
    if (err) memcpy(errc,&err,4);
    //if (err) NSLog(@" error on AudioFileCreateWithURL , code %d %s",err,errc);
    err=AudioFileWritePackets (	fileID,  
                               FALSE,
                               bytesize,   // byte size?
                               NULL ,
                               0,           // start at zero packets...
                               &packetsize,  //# packets
                               audioRecBuffer);	
    
    if (err) memcpy(errc,&err,4);
    //if (err) NSLog(@" error on AudioFileWritePackets , code %d %s",err,errc);
    //NSLog(@" ...writeOutputSampleFile err %d, %d bytes",err,(int)bytesize);
	AudioFileClose(fileID);
    if (!err) needToMailAudioFile=1;
} //end writeOutputSampleFile


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 4/29/13: Add web support?
// 5/31/13: Add nils to fileid/fileurl, fix possible corruption bug
- (void)loadSample:(NSString *)name :(NSString *)type
{
    AudioFileID fileID; //DHS 11/12
    OSStatus err;
	int sws;
	char duhchar[8];
	UInt32 theSize,outNumBytes,readsize;
	UInt64 packetCount,bCount,bitRate;
    NSURL *fileURL = nil;
	AudioStreamBasicDescription outFormat;
	UInt32 thePropSize = sizeof(outFormat);
    NSLog(@" ..sample name %@ type %@",name,type);
    if ([type  isEqual: @"WEB"]) //we're pulling sample down from web?
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
 	err = AudioFileOpenURL ((__bridge CFURLRef) fileURL, kAudioFileReadPermission,0,&fileID);
    
	if (err)
	{  
       //if (err == kAudioFileFileNotFoundError)
		return;
	}
	// NSLog(@"File ID %d %x",fileID,fileID);
	// read size and format
    //Sept 19, 2019 : WTF! New samples 44.1K dont load. only 11025 works!
	AudioFileGetProperty(fileID, kAudioFilePropertyDataFormat, &thePropSize, &outFormat);
    lastSampleRate = (int)outFormat.mSampleRate; //DHS 10/5
    theSize = outFormat.mFormatID;
	memcpy(duhchar,&theSize,4);
    
    err = AudioFileGetProperty(fileID, kAudioFilePropertyBitRate,
                               &theSize, &bitRate);
	NSLog(@" ...samplerate %d vs bitrate %d",lastSampleRate,bitRate);
	// if (outFormat.mFormatID == kAudioFormatMPEG4AAC)  NSLog(@" ..found mp4 format..");
	// if (outFormat.mFormatID == kAudioFormatLinearPCM) NSLog(@" ..found linear PCM format..");
	sChans = outFormat.mChannelsPerFrame;
	theSize = sizeof(packetCount);
	err = AudioFileGetProperty(fileID, kAudioFilePropertyAudioDataPacketCount,
							   &theSize, &packetCount);	
    NSLog(@"LS:[%@]duration %4.2f mSampleRate %d packetCount %llu mBytesPerPacket %d chans %d",name,
          (float)(packetCount/sChans)/(float)outFormat.mSampleRate,
          (int)outFormat.mSampleRate,packetCount,(int)outFormat.mBytesPerPacket,outFormat.mChannelsPerFrame);
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
	// freeup old swave is needed
	if (swave != NULL) 
	{
        //NSLog(@"  Free swave " );
		free(swave);
		swave = NULL;
	}
	//OK, short data!
    sws = sNumPackets * sChans * sizeof(short);
	swave = (unsigned short *)malloc(sws);
    if (swave == NULL) //ERROR! Swave failed!
    {
        swaveSize = 0;
        //NSLog(@"Swave alloc failed (%d bytes) ",sws);
        return;	
    }
    else
    {
        swaveSize = sNumPackets * sChans;
    }
    readsize = sNumPackets * sChans;
    outNumBytes = -1;
    if (!err) err = AudioFileReadPacketData(fileID, FALSE, &outNumBytes, NULL, 0, &readsize, swave);
    sampleSize =outNumBytes; //DHS 10/6 was readsize;
    //NSLog(@" ...load sample OK, size %d vs outnumbytes %d",readsize,outNumBytes);
	if (!err)  AudioFileClose(fileID);
    gotSample = 1;
    //if (err != 0) NSLog(@" loadsample error: %d",(int)err);
    return;
	
} //end loadSample


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 9/21 Local load from path...
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
    NSLog(@"ERRR 3 %d",err);
    sPacketSize = (int)bCount;
    sNumPackets = (int)packetCount;
    //DHS we have to tell caller about this!!!
    if (bCount > MAX_SAMPLE_SIZE)
    {
        gotSample = 0;
        //NSLog(@"Sample file too big! (over %d)  %d",MAX_SAMPLE_SIZE,(int)bCount);
        return;
    }
    // freeup old swave is needed
    if (swave != NULL)
    {
        //NSLog(@"  Free swave " );
        free(swave);
        swave = NULL;
    }
    //OK, short data!
    //NSLog(@"  Malloc swave, size %d chans %d",sNumPackets,sChans);
    sws = sNumPackets * sChans * sizeof(short);
    swave = (unsigned short *)malloc(sws);
    if (swave == NULL) //ERROR! Swave failed!
    {
        swaveSize = 0;
        //NSLog(@"Swave alloc failed (%d bytes) ",sws);
        return;
    }
    else
    {
        swaveSize = sNumPackets * sChans;
    }
    readsize = sNumPackets * sChans;
    outNumBytes = 0; //DHS 10/10 init to avoid warning
    //DHS 10/10 use this call! not ...PacketData
    if (!err)err = AudioFileReadPackets (fileID,FALSE,&outNumBytes,NULL,0,&readsize,swave);
    sampleSize =  readsize;
    if (!err)  AudioFileClose(fileID);
    gotSample = 1;
    if (err != 0) NSLog(@" loadsample error: %d",(int)err);
    //else NSLog(@" ...load sample OK");
    //    NSLog(@" dump of sample %@========================",fileName);
    //    for (int i=0;i<64;i++) NSLog(@" swave[%d] %x",i,swave[i]);
    return;
    
} //end loadSample


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
    audioFormat.mSampleRate = 44100;   // GIVE YOUR SAMPLING RATE
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

    NSLog(@" done doogoititie size %d",j);

    sBufs[whichBuffer] = malloc(j * sizeof(float));
    if (!sBufs[whichBuffer]) return;
    //ok we have data, convert it! to unsigned short
    for (int i=0;i<j;i++)
    {
        double df = workBuffer[i];
        //df = 32767.0 * (df + 0.5);
        sBufs[whichBuffer][i] = (float)df + 0.5;
    }
    NSLog(@" got here");
    for (int i=0;i<256;i++)
        NSLog(@" wb[%d] %f -> %f",i,workBuffer[i],sBufs[whichBuffer][i]);

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
