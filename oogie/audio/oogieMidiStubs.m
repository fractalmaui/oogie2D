//    ____  ____  _____ _  _____ _      _  ____  _ 
//   /  _ \/  _ \/  __// \/  __// \__/|/ \/  _ \/ \
//   | / \|| / \|| |  _| ||  \  | |\/||| || | \|| |
//   | \_/|| \_/|| |_//| ||  /_ | |  ||| || |_/|| |
//   \____/\____/\____\\_/\____\\_/  \|\_/\____/\_/
//
//  oogieMidi.m: Basic MIDI stuff for iOS
//  oogieIPAD
//
//  Created by dave scruton on 5/19/13.
//  Copyright (c) 2013 fractallonomy. All rights reserved.
//
// DHS May 19: OOGIE speaks MIDI! Makes killer sounds!
//               there may be too many MIDI note off's getting sent?!?!
// DHS May 21: Added midi reset , reset channel
// DHS May 25: Fixed message size of "program change". 2 NOT 3!!!
// DHS May 29: Fixed midi online routine
//  DHS 5/30/13: READY FOR RELEASE! Pull all NSlog
//=========================================================================
// APP submittal to Apple, June 13th!!!
//=========================================================================
#include <stdio.h>
#include "oogieMidiStubs.h"
#include "cheat.h"

#if 0
MIDIClientRef      client;
MIDIPortRef        outputPort; 
MIDIPortRef        inputPort;
NSString          *virtualEndpointName;
MIDIEndpointRef    virtualSourceEndpoint;
MIDIEndpointRef    virtualDestinationEndpoint;
NSMutableArray    *sources, *destinations;
MIDIEndpointRef  endpoint = 0;
int midiDeviceNum;
int mverbose = 0;
#endif 


//-----------=MIDI=---------------=MIDI=---------------=MIDI=-----
void OMMIDIinit(void)
{
    return;
} //end OMMIDIinit



//-----------=MIDI=---------------=MIDI=---------------=MIDI=-----
// Turns off all notes on all channels on the current device
void OMResetAll(void)
{
} //end OMResetAll


//-----------=MIDI=---------------=MIDI=---------------=MIDI=-----
// Turns off all notes on ONE channel 
void OMResetChannel(int chan) 
{
} //end OMResetChannel



//-----------=MIDI=---------------=MIDI=---------------=MIDI=-----
// This is called note-to-note. Is that a good idea???
void OMSetDevice(int dev)
{
} //end OMSetDevice

//-----------=MIDI=---------------=MIDI=---------------=MIDI=-----
void OMProgramChange(ItemCount chan,int program) 
{
    
} //end OMProgramChange




//-----------=MIDI=---------------=MIDI=---------------=MIDI=-----
void OMPlayNote(ItemCount chan,int note,int vel)
{
} //end OMPlayNote

//-----------=MIDI=---------------=MIDI=---------------=MIDI=-----
void OMEndNote(ItemCount chan,int note )
{
} //end OMEndNote

//-----------=MIDI=---------------=MIDI=---------------=MIDI=-----
void OMflushOutput(void)
{
} //end OMflushOutput


//-----------=MIDI=---------------=MIDI=---------------=MIDI=-----
//static NSString *OMNameOfEndpoint(MIDIEndpointRef ref)
//{
//   return @"stubbed";
//} //end NameOfEndpoint


 

//-----------=MIDI=---------------=MIDI=---------------=MIDI=-----
void OMsendBytes(const UInt8* bytes, UInt32 size)
{
}




//-----------=MIDI=---------------=MIDI=---------------=MIDI=-----
NSString *OMgetName(MIDIObjectRef object)
{
    return @"stubbed";
  
}

//-----------=MIDI=---------------=MIDI=---------------=MIDI=-----
NSString *OMgetDisplayName(MIDIObjectRef object)
{
    return @"stubbed";
}


//-----------=MIDI=---------------=MIDI=---------------=MIDI=-----
int  OMgetOnline(int which) 
{
    return 0;
}  //end OMgetOnline

//-----------=MIDI=---------------=MIDI=---------------=MIDI=-----
// Dumps MIDI status out to mididumpX.txt where X is value of which
void OMdumpFile(void)
{
} //end OMdumpFile 

//-----------=MIDI=---------------=MIDI=---------------=MIDI=-----
//void midiit()
//{
   
//} //end midiit

