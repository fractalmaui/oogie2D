//
//        _             _ _       ____         __  __           ____  _                       
//       / \  _   _  __| (_) ___ | __ ) _   _ / _|/ _| ___ _ __|  _ \| | __ _ _   _  ___ _ __ 
//      / _ \| | | |/ _` | |/ _ \|  _ \| | | | |_| |_ / _ \ '__| |_) | |/ _` | | | |/ _ \ '__|
//     / ___ \ |_| | (_| | | (_) | |_) | |_| |  _|  _|  __/ |  |  __/| | (_| | |_| |  __/ |   
//    /_/   \_\__,_|\__,_|_|\___/|____/ \__,_|_| |_|  \___|_|  |_|   |_|\__,_|\__, |\___|_|   
//                                                                             |___/           
//				 
//    
// DHS 5/30/13: READY FOR RELEASE! 
//=========================================================================
// APP submittal to Apple, June 13th!!!
//=========================================================================
// OOGIECAM VERSION:
//  DHS 8/9/13: First Release? WOW! Within a week from inception!
// SPECIAL For HueDoKu: Changed audio session to kAudioSessionCategory_AmbientSound
//  BUG: Ambient sound sometimes doesn't work on the phone, had to go to normal sound!
//  DHS 11/12: Replace old audio with AVFoundation-based calls

#import "AudioBufferPlayer.h"

@interface AudioBufferPlayer (Private)
- (void)setUpAudio;
- (void)tearDownAudio;
- (void)setUpAudioSession;
- (void)tearDownAudioSession;
- (void)setUpPlayQueue;
- (void)tearDownPlayQueue;
- (void)setUpPlayQueueBuffers;
- (void)primePlayQueueBuffers;
@end

int needtoclear = 0;
int uberpackets = 0;

#if 0 //DHS 11/12
static void interruptionListenerCallback(void* inUserData, UInt32 interruptionState)
{
	AudioBufferPlayer* player = (__bridge AudioBufferPlayer*) inUserData;
	if (interruptionState == kAudioSessionBeginInterruption)
	{
		[player tearDownAudio];
	}
	else if (interruptionState == kAudioSessionEndInterruption)
	{
		[player setUpAudio];
		[player start];
	}
}
#endif

static void playCallback(
	void* inUserData, AudioQueueRef inAudioQueue, AudioQueueBufferRef inBuffer)
{
	AudioBufferPlayer* player = (__bridge AudioBufferPlayer*) inUserData;
	if (player.playing)
	{
       // if (!needtoclear)
            [player.delegate audioBufferPlayer:player fillBuffer:inBuffer format:player.audioFormat];
       // else
       // {
       //     SInt16* p = (SInt16*)inBuffer;
       //     int f;
       //     for (f = 0; f <  uberpackets; ++f)
       //     {
       //         p[f*2]     = 0;     //LEFT
       //         p[f*2 + 1] = 0;   //RIGHT
       //     }
       //     needtoclear = 0;
        //}
        AudioQueueEnqueueBuffer(inAudioQueue, inBuffer, 0, NULL);
	}  //end playing
}

@implementation AudioBufferPlayer

@synthesize delegate;
@synthesize playing;
@synthesize gain;
@synthesize audioFormat;

- (id)initWithSampleRate:(Float64)sampleRate channels:(UInt32)channels bitsPerChannel:(UInt32)bitsPerChannel secondsPerBuffer:(Float64)secondsPerBuffer
{
	return [self initWithSampleRate:sampleRate channels:channels bitsPerChannel:bitsPerChannel packetsPerBuffer:(UInt32)(secondsPerBuffer * sampleRate)];
}

- (id)initWithSampleRate:(Float64)sampleRate channels:(UInt32)channels bitsPerChannel:(UInt32)bitsPerChannel packetsPerBuffer:(UInt32)packetsPerBuffer_
{
    //NSLog(@" init sound: srate %d,chans %d,bpc %d, ppb %d",
    //      sampleRate,channels,bitsPerChannel,packetsPerBuffer);
	if ((self = [super init]))
	{
		playing = NO;
		delegate = nil;
		playQueue = NULL;
		gain = 1.0;

		audioFormat.mFormatID         = kAudioFormatLinearPCM;
		audioFormat.mSampleRate       = sampleRate;
		audioFormat.mChannelsPerFrame = channels;
		audioFormat.mBitsPerChannel   = bitsPerChannel;
		audioFormat.mFramesPerPacket  = 1;  // uncompressed audio
		audioFormat.mBytesPerFrame    = audioFormat.mChannelsPerFrame * audioFormat.mBitsPerChannel/8; 
		audioFormat.mBytesPerPacket   = audioFormat.mBytesPerFrame * audioFormat.mFramesPerPacket;
		audioFormat.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger 
									  | kLinearPCMFormatFlagIsPacked; 

		packetsPerBuffer = packetsPerBuffer_;
        uberpackets = packetsPerBuffer;
		bytesPerBuffer = packetsPerBuffer * audioFormat.mBytesPerPacket;

		[self setUpAudio];

	}
	return self;
}

- (void)dealloc
{
	[self tearDownAudio];
	//ARC doesn't need [super dealloc];
}

- (void)setUpAudio
{
	if (playQueue == NULL)
	{
		[self setUpAudioSession];
		[self setUpPlayQueue];
		[self setUpPlayQueueBuffers];
 
	}
}

- (void)tearDownAudio
{
	if (playQueue != NULL)
	{
		[self stop];
		[self tearDownPlayQueue];
		[self tearDownAudioSession];
	}
}

- (void)setUpAudioSession
{
    
    
#if 1
    AVAudioSession *session;
    session = [AVAudioSession sharedInstance];
    //error handling
    BOOL success;
    NSError* error;
    
    //set the audioSession category.
    //Needs to be Record or PlayAndRecord to use audioRouteOverride:
    
    success = [session setCategory:AVAudioSessionCategoryAmbient
                             error:&error];
    
    success = [session setActive:YES error:&error];
    


#endif
    
#if 0
    //use AVAudioSession instead...??
	AudioSessionInitialize(
		NULL,
		NULL,
		interruptionListenerCallback,
		(__bridge void *)(self)
		);

    

	//UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
    UInt32 sessionCategory = kAudioSessionCategory_AmbientSound;
    //Use AVAudioSession setCategory : withOptions : method
    //UInt32 sessionCategory = kAudioSessionCategory_SoloAmbientSound;
	AudioSessionSetProperty(
		kAudioSessionProperty_AudioCategory,
		sizeof(sessionCategory),
		&sessionCategory
		);
    // use setactive method

	AudioSessionSetActive(true);

#endif

}

- (void)tearDownAudioSession
{
    //DHS 11/12
    AVAudioSession *session;
    NSError* error;
    [session setActive:NO error:&error];
    
    //DHS 11/12 AudioSessionSetActive(false);
}

- (void)setUpPlayQueue
{
	AudioQueueNewOutput(
		&audioFormat,
		playCallback,
		(__bridge void *)(self), 
		NULL,                   // run loop
		kCFRunLoopCommonModes,  // run loop mode
		0,                      // flags
		&playQueue
		);

	self.gain = 1.0;
}

- (void)tearDownPlayQueue
{
	AudioQueueDispose(playQueue, YES);
	playQueue = NULL;
}

- (void)setUpPlayQueueBuffers
{
	for (int t = 0; t < NUMBER_AUDIO_DATA_BUFFERS; ++t)
	{
		AudioQueueAllocateBuffer(
			playQueue,
			bytesPerBuffer,
			&playQueueBuffers[t]
			);
	}
}

- (void)primePlayQueueBuffers
{
	for (int t = 0; t < NUMBER_AUDIO_DATA_BUFFERS; ++t)
	{
		playCallback((__bridge void *)(self), playQueue, playQueueBuffers[t]);
	}
}

- (void)start
{
	if (!playing)
	{
		playing = YES;
		[self primePlayQueueBuffers];
		AudioQueueStart(playQueue, NULL);
	}
}

- (void)stop
{
	if (playing)
	{
		AudioQueueStop(playQueue, TRUE);
		playing = NO;
	}
}

- (void)setGain:(Float32)gain_
{
	gain = gain_;

	AudioQueueSetParameter(
		playQueue,
		kAudioQueueParam_Volume,
		gain
		);
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 11/29:Used to clean up audio output, zeroes out audio buffer...
- (void)clearBuffer
{
    needtoclear = 1;
}


@end
