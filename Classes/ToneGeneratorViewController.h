//
//  ToneGeneratorViewController.h
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

#import <UIKit/UIKit.h>
#import <AudioUnit/AudioUnit.h>

@interface ToneGeneratorViewController : UIViewController
{
	UILabel *frequencyLabel;
	UIButton *playButton;
	UISlider *frequencySlider;
	AudioComponentInstance toneUnit;

@public
	double frequency;
    double sliderValue;
	double sampleRate;
	double theta;
    int myCounter;
    NSTimer *myTimer;
    NSTimer *myChirpTimer;
    NSMutableArray *freqData;
    NSMutableArray *textFreqData;
}

@property (nonatomic, retain) IBOutlet UISlider *frequencySlider;
@property (nonatomic, retain) IBOutlet UIButton *playButton;
@property (nonatomic, retain) IBOutlet UILabel *frequencyLabel;


@property (retain, nonatomic) IBOutlet UITextField *textinput;
@property (retain, nonatomic) IBOutlet UIButton *useCustomButton;

- (IBAction)useCustom:(id)sender;

- (IBAction)startSequence:(id)sender;

- (IBAction)sliderChanged:(UISlider *)frequencySlider;
- (IBAction)togglePlay:(UIButton *)selectedButton;
- (void)stop;

@end

