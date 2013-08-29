//
//  ToneGeneratorViewController.m
//  ToneGenerator
//
//  Created by Matt Gallagher on 2010/10/20.
//  Copyright 2010 Matt Gallagher. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//

#import "ToneGeneratorViewController.h"
#import <AudioToolbox/AudioToolbox.h>

OSStatus RenderTone(
	void *inRefCon, 
	AudioUnitRenderActionFlags 	*ioActionFlags, 
	const AudioTimeStamp 		*inTimeStamp, 
	UInt32 						inBusNumber, 
	UInt32 						inNumberFrames, 
	AudioBufferList 			*ioData)

{
	// Fixed amplitude is good enough for our purposes
	const double amplitude = 0.25;
    
//    double sliderValue=2200;
	// Get the tone parameters out of the view controller
	ToneGeneratorViewController *viewController =
		(ToneGeneratorViewController *)inRefCon;
	double theta = viewController->theta;
	double theta_increment = 2.0 * M_PI * viewController->frequency / viewController->sampleRate;

	// This is a mono tone generator so we only need the first buffer
	const int channel = 0;
	Float32 *buffer = (Float32 *)ioData->mBuffers[channel].mData;
	
	// Generate the samples
	for (UInt32 frame = 0; frame < inNumberFrames; frame++) 
	{
		buffer[frame] = sin(theta) * amplitude;
		
		theta += theta_increment;
		if (theta > 2.0 * M_PI)
		{
			theta -= 2.0 * M_PI;
		}
	}
	
	// Store the theta back in the view controller
	viewController->theta = theta;

	return noErr;
}

void ToneInterruptionListener(void *inClientData, UInt32 inInterruptionState)
{
	ToneGeneratorViewController *viewController =
		(ToneGeneratorViewController *)inClientData;
	
	[viewController stop];
}

@implementation ToneGeneratorViewController

@synthesize frequencySlider;
@synthesize playButton;
@synthesize frequencyLabel;
@synthesize textinput, useCustomButton;


- (IBAction)useCustom:(id)sender {
    [self startCustomSequence];
    [self.useCustomButton setHidden:YES];
}

- (IBAction)startSequence:(id)sender {

    //Read from file
    NSError *err;
    NSString *dataFile = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"freq_data.txt"];
    NSString *contents = [[NSString alloc] initWithContentsOfFile:dataFile encoding:NSUTF8StringEncoding error:&err];
    
    if (contents) {
        NSScanner *scanner = [[NSScanner alloc] initWithString:contents];
        
        freqData = [[NSMutableArray alloc] init];
        while ([scanner isAtEnd] == NO) {
            float scannedValue = 0;
            if ([scanner scanFloat:&scannedValue]) {
                NSNumber *num = [[NSNumber alloc] initWithFloat:scannedValue];
                
                [freqData addObject:num];
            }
        }
        
    } else {
        NSLog(@"failed to read in data file %@", dataFile);
    }
    NSLog(@"Count of freq Data: %i", [freqData count]);
    
    
    myCounter=0;
    myChirpTimer = [NSTimer scheduledTimerWithTimeInterval:1.84/20
                                                    target:self
                                                  selector:@selector(updateChirp)
                                                  userInfo:nil
                                                   repeats:YES];

}



- (void)startCustomSequence {
    
    NSString *testString=textinput.text;
    NSData *stringData =[[NSData alloc] initWithData:[testString dataUsingEncoding:NSASCIIStringEncoding]];
    //    NSLog(@"%i",[test bytes]);
    NSLog([stringData description]); //HEX output to check against
    const unsigned char *dataBuffer = (const unsigned char *)[stringData bytes];
    
    textFreqData=[[NSMutableArray alloc] init];
    
    for (int i = 0; i < [stringData length]; ++i)
    {
        [textFreqData addObject:[NSNumber numberWithInt:dataBuffer[i] & 0xF0]];
        [textFreqData addObject:[NSNumber numberWithInt:dataBuffer[i] & 0x0F]];
    }
    
    myCounter=0;
    myTimer = [NSTimer scheduledTimerWithTimeInterval:1.84/20
                                               target:self
                                             selector:@selector(updateTimer)
                                             userInfo:nil
                                              repeats:YES];
}

-(void)updateChirp{
    if(myCounter==0){
        [self startPlaying];
    }
    if(myCounter>=[freqData count]-1){
        [myChirpTimer invalidate];
        myCounter=0;
        [self stopPlaying];
        return;
    }
    NSNumber *temp=[freqData objectAtIndex:myCounter];
    frequency= temp.doubleValue;
    NSLog(@"%f",frequency);
    myCounter++;
    
    
}

-(void)updateTimer{
    if(myCounter==0){
        [self startPlaying];
    }
    if(myCounter>=[textFreqData count]){
        [myTimer invalidate];
        myCounter=0;
        [self stopPlaying];
        [self.useCustomButton setHidden:NO];
        return;
    }
    NSNumber *temp=[textFreqData objectAtIndex:myCounter];
    double numDbl= temp.doubleValue;
//    NSLog(@"%f",numDbl);
    
    frequency=numDbl*(10000.0f-sliderValue)/15.0f+sliderValue;
    NSLog(@"%f",frequency);
    myCounter++;


}








- (IBAction)sliderChanged:(UISlider *)slider
{
    sliderValue=slider.value;
	frequency = slider.value;
	frequencyLabel.text = [NSString stringWithFormat:@"%4.1f Hz", frequency];
}

- (void)createToneUnit
{
	// Configure the search parameters to find the default playback output unit
	// (called the kAudioUnitSubType_RemoteIO on iOS but
	// kAudioUnitSubType_DefaultOutput on Mac OS X)
	AudioComponentDescription defaultOutputDescription;
	defaultOutputDescription.componentType = kAudioUnitType_Output;
	defaultOutputDescription.componentSubType = kAudioUnitSubType_RemoteIO;
	defaultOutputDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
	defaultOutputDescription.componentFlags = 0;
	defaultOutputDescription.componentFlagsMask = 0;
	
	// Get the default playback output unit
	AudioComponent defaultOutput = AudioComponentFindNext(NULL, &defaultOutputDescription);
	NSAssert(defaultOutput, @"Can't find default output");
	
	// Create a new unit based on this that we'll use for output
	OSErr err = AudioComponentInstanceNew(defaultOutput, &toneUnit);
	NSAssert1(toneUnit, @"Error creating unit: %ld", err);
	
	// Set our tone rendering function on the unit
	AURenderCallbackStruct input;
	input.inputProc = RenderTone;
	input.inputProcRefCon = self;
	err = AudioUnitSetProperty(toneUnit, 
		kAudioUnitProperty_SetRenderCallback, 
		kAudioUnitScope_Input,
		0, 
		&input, 
		sizeof(input));
	NSAssert1(err == noErr, @"Error setting callback: %ld", err);
	
	// Set the format to 32 bit, single channel, floating point, linear PCM
	const int four_bytes_per_float = 4;
	const int eight_bits_per_byte = 8;
	AudioStreamBasicDescription streamFormat;
	streamFormat.mSampleRate = sampleRate;
	streamFormat.mFormatID = kAudioFormatLinearPCM;
	streamFormat.mFormatFlags =
		kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
	streamFormat.mBytesPerPacket = four_bytes_per_float;
	streamFormat.mFramesPerPacket = 1;	
	streamFormat.mBytesPerFrame = four_bytes_per_float;		
	streamFormat.mChannelsPerFrame = 1;	
	streamFormat.mBitsPerChannel = four_bytes_per_float * eight_bits_per_byte;
	err = AudioUnitSetProperty (toneUnit,
		kAudioUnitProperty_StreamFormat,
		kAudioUnitScope_Input,
		0,
		&streamFormat,
		sizeof(AudioStreamBasicDescription));
	NSAssert1(err == noErr, @"Error setting stream format: %ld", err);
}


-(void)stopPlaying{
    AudioOutputUnitStop(toneUnit);
    AudioUnitUninitialize(toneUnit);
    AudioComponentInstanceDispose(toneUnit);
    toneUnit = nil;
}
-(void)startPlaying{
    [self createToneUnit];
    
    // Stop changing parameters on the unit
    OSErr err = AudioUnitInitialize(toneUnit);
    NSAssert1(err == noErr, @"Error initializing unit: %ld", err);
    
    // Start playback
    err = AudioOutputUnitStart(toneUnit);
    NSAssert1(err == noErr, @"Error starting unit: %ld", err);
    
}

- (IBAction)togglePlay:(UIButton *)selectedButton
{
	if (toneUnit)
	{
        [self stopPlaying];
		[selectedButton setTitle:NSLocalizedString(@"Test", nil) forState:0];
	}
	else
	{
        [self startPlaying];

		[selectedButton setTitle:NSLocalizedString(@"Stop", nil) forState:0];
	}
}

- (void)stop
{
	if (toneUnit)
	{
		[self togglePlay:playButton];
	}
}

- (void)viewDidLoad {
	[super viewDidLoad];

	[self sliderChanged:frequencySlider];
	sampleRate = 44100;

	OSStatus result = AudioSessionInitialize(NULL, NULL, ToneInterruptionListener, self);
	if (result == kAudioSessionNoError)
	{
		UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
		AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);
	}
	AudioSessionSetActive(true);
}

- (void)viewDidUnload {
	self.frequencyLabel = nil;
	self.playButton = nil;
	self.frequencySlider = nil;

	AudioSessionSetActive(false);
}

- (void)dealloc {
    [textinput release];
    [useCustomButton release];
    [super dealloc];
}
@end
