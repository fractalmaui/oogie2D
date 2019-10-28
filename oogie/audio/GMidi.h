//
//    ____ __  __ _     _ _
//   / ___|  \/  (_) __| (_)
//  | |  _| |\/| | |/ _` | |
//  | |_| | |  | | | (_| | |
//   \____|_|  |_|_|\__,_|_|
//
//  GMidi.h
//  oogie2d
//
//  various general MIDI definitions...
//  created by dave scruton on 9/22/19.
//  copyright © 2019 fractallonomy. all rights reserved.
//


//percussion: mapped to sequential notes starting at mIdI 35
#define gm_percUssIoN_startKeY 35
NSString * const GM_Percussion_Names[] = {
    @"acoustic bass drum",      //35
    @"bass drum 1",
    @"side stick",
    @"acoustic snare",
    @"hand clap",
    @"electric snare",          //40
    @"low floor tom",
    @"closed hi hat",
    @"high floor tom",
    @"pedal hi hat",
    @"low tom",                 //45
    @"open hi hat",
    @"low mid tom",
    @"hi mid tom",
    @"crash cymbal 1",
    @"high tom",                //50
    @"ride cymbal 1",
    @"chinese cymbal",
    @"ride bell",
    @"tambourine",
    @"splash cymbal",           //55
    @"cowbell",
    @"crash cymbal 2",
    @"vibraslap",
    @"ride cymbal 2",
    @"hi bongo",                //60
    @"low bongo",
    @"mute hi conga",
    @"open hi conga",
    @"low conga",
    @"high timbale" ,           //65
    @"low timbale",
    @"high agogo",
    @"low agogo",
    @"cabasa",
    @"maracas",                 //70
    @"short whistle",
    @"long whistle",
    @"short guiro",
    @"long guiro",
    @"claves",                  //75
    @"hi wood block",
    @"low wood block",
    @"mute cuica",
    @"open cuica",
    @"mute triangle",          //80
    @"open triangle"
};

