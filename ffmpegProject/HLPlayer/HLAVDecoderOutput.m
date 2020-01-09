//
//  HLAVDecoderOutput.m
//  ffmpegProject
//
//  Created by hailong on 2020/01/07.
//  Copyright © 2020 HL. All rights reserved.
//

#import "HLAVDecoderOutput.h"

@implementation HLAVDecoderOutput
- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void) setup;
{
    self.videoframes = [NSMutableArray arrayWithCapacity:100];
    self.videoframesDuration = 0;
    
    self.audioframes = [NSMutableArray arrayWithCapacity:100];
    self.audioframesDuration = 0;
}

- (void) addOutput:(HLAVDecoderOutput*)output;
{
    if ([output.videoframes count] > 0) {
        [self.videoframes addObjectsFromArray:output.videoframes];
        self.videoframesDuration += output.videoframesDuration;
    }
    
    if ([output.audioframes count] > 0) {
        [self.audioframes addObjectsFromArray:output.audioframes];
        self.audioframesDuration += output.audioframesDuration;
    }
}

- (BOOL) hasAudioData;
{
    return self.audioframes && [self.audioframes count] > 0;
}

- (BOOL) hasVideoData;
{
    return self.videoframes && [self.videoframes count] > 0;
}

- (CGFloat)maxDuration;
{
    return MAX(self.audioframesDuration, self.videoframesDuration);
}

- (CGFloat)minPosition;
{
    return MIN([[self.audioframes firstObject] position], [[self.videoframes firstObject] position]);
}

- (HLAVFrameVideo *) consumerVideoFrame;
{
    if (!self.videoframes || [self.videoframes count] < 1) {
        return nil;
    }
    HLAVFrameVideo * frame = [self.videoframes firstObject];
    [self.videoframes removeObjectAtIndex:0];
    
    self.videoframesDuration -= frame.duration;
    return frame;
}

- (HLAVFrameAudio *) consumerAudioFrame;
{
    if (!self.audioframes || [self.audioframes count] < 1) {
        return nil;
    }
    HLAVFrameAudio * frame = [self.audioframes firstObject];
    [self.audioframes removeObjectAtIndex:0];
    
    self.audioframesDuration -= frame.duration;
    return frame;
}
@end
