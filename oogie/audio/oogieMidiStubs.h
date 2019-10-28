//    ____  ____  _____ _  _____ _      _  ____  _ 
//   /  _ \/  _ \/  __// \/  __// \__/|/ \/  _ \/ \
//   | / \|| / \|| |  _| ||  \  | |\/||| || | \|| |
//   | \_/|| \_/|| |_//| ||  /_ | |  ||| || |_/|| |
//   \____/\____/\____\\_/\____\\_/  \|\_/\____/\_/
//
//  oogieMidi.h: Basic MIDI stuff for iOS
//  oogieIPAD
//
//  Created by dave scruton on 5/19/13.
//  Copyright (c) 2013 fractallonomy. All rights reserved.
//

#ifndef oogieIPAD_oogieMidi_h
#define oogieIPAD_oogieMidi_h
#import <CoreMIDI/CoreMIDI.h>

#define MESSAGESIZEN 3             /* byte count for MIDI note messages   */
#define MESSAGESIZEC 2             /* byte count for MIDI program changes   */
#define MAXMCHANNELS 16
#define MAXMNOTES 127

void OMMIDIinit(void);
void OMResetAll(void);
void OMResetChannel(int chan);
int  OMgetOnline(int which);
void midiit(void) ;  //straw man. clobber
void OMdumpFile(void) ;  //Dumps midi to output file...
void OMflushOutput(void);
void OMProgramChange(ItemCount chan,int program);
void OMPlayNote(ItemCount chan,int note,int vel);
void OMEndNote(ItemCount chan,int note);
void OMSetDevice(int dev);
void OMsendBytes(const UInt8* bytes, UInt32 size);



NSString *OMgetName(MIDIObjectRef object);
NSString *OMgetDisplayName(MIDIObjectRef object);


#endif
