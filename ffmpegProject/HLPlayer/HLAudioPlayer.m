//
//  HLAudioPlayer.m
//  ffmpegProject
//
//  Created by hailong on 2020/01/07.
//  Copyright © 2020 HL. All rights reserved.
//

#import "HLAudioPlayer.h"
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>

#define MAX_FRAME_SIZE 4096
#define MAX_CHAN       2

#define ChannelsPerFrame 2
#define SampleRate  44100


#define BytesPerFrame (sizeof(float))
#define BitsPerChannel (BytesPerFrame * 8)

@interface HLAudioPlayer ()

{
    AUGraph _graph;
    AUNode _mixerNode;
    AUNode _outputNode;
    AUNode _timePitchNode;
    AudioUnit _mixerUnit;
    AudioUnit _outputUnit;
    AudioUnit _timePitchUnit;
    
    float *_outData;
}

@property (nonatomic, readonly) BOOL needsTimePitchNode;

@end

@implementation HLAudioPlayer

+ (AudioComponentDescription)mixerACD
{
    AudioComponentDescription acd;
    acd.componentType = kAudioUnitType_Mixer;
    acd.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    acd.componentManufacturer = kAudioUnitManufacturer_Apple;
    return acd;
}

+ (AudioComponentDescription)outputACD
{
    AudioComponentDescription acd;
    acd.componentType = kAudioUnitType_Output;
    acd.componentSubType = kAudioUnitSubType_RemoteIO;
    acd.componentManufacturer = kAudioUnitManufacturer_Apple;
    return acd;
}

+ (AudioComponentDescription)timePitchACD
{
    AudioComponentDescription acd;
    acd.componentType = kAudioUnitType_FormatConverter;
    acd.componentSubType = kAudioUnitSubType_NewTimePitch;
    acd.componentManufacturer = kAudioUnitManufacturer_Apple;
    return acd;
}

+ (AudioStreamBasicDescription)commonASBD
{
   
    AudioStreamBasicDescription asbd;
    asbd.mBitsPerChannel   = BitsPerChannel;
    asbd.mBytesPerFrame    = BytesPerFrame;
    asbd.mChannelsPerFrame = ChannelsPerFrame;
    asbd.mFormatFlags      = kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved;
    asbd.mFormatID         = kAudioFormatLinearPCM;
    asbd.mFramesPerPacket  = 1;
    asbd.mBytesPerPacket   = asbd.mFramesPerPacket * asbd.mBytesPerFrame;
    asbd.mSampleRate       = SampleRate;
    return asbd;
}

- (instancetype)init
{
    if (self = [super init]) {
        [self setup];
    }
    return self;
}

- (void)dealloc
{
    [self destroy];
}

#pragma mark - Setup/Destory

- (void) setupAudioSession
{
    AVAudioSession * session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    NSTimeInterval bufferDuration = 0.002;
    [session setPreferredIOBufferDuration:bufferDuration error:nil];
    double samplerate =44100;
    [session setPreferredSampleRate:samplerate error:nil];
    [session setActive:YES error:nil];
}
- (void)setup
{
    [self setupAudioSession];
    
    _outData = (float *)calloc(MAX_FRAME_SIZE*MAX_CHAN, sizeof(float));
    
    self.rate = 1.0;
    self.pitch = 0.0;
    self.volume = [[AVAudioSession sharedInstance] outputVolume];
    
    AudioStreamBasicDescription asbd = [self.class commonASBD];
    AudioComponentDescription mixerACD = [self.class mixerACD];
    AudioComponentDescription outputACD = [self.class outputACD];
    AudioComponentDescription timePitchACD = [self.class timePitchACD];
    
    NewAUGraph(&_graph);
    AUGraphAddNode(_graph, &mixerACD, &_mixerNode);
    AUGraphAddNode(_graph, &outputACD, &_outputNode);
    AUGraphAddNode(_graph, &timePitchACD, &_timePitchNode);
    
    AUGraphOpen(_graph);
    AUGraphNodeInfo(_graph, _mixerNode, &mixerACD, &_mixerUnit);
    AUGraphNodeInfo(_graph, _outputNode, &outputACD, &_outputUnit);
    AUGraphNodeInfo(_graph, _timePitchNode, &timePitchACD, &_timePitchUnit);
    
    UInt32 value = 4096;
    UInt32 size = sizeof(value);
    AudioUnitScope scope = kAudioUnitScope_Global;
    AudioUnitPropertyID param = kAudioUnitProperty_MaximumFramesPerSlice;
    AudioUnitSetProperty(_mixerUnit, param, scope, 0, &value, size);
    AudioUnitSetProperty(_outputUnit, param, scope, 0, &value, size);
    AudioUnitSetProperty(_timePitchUnit, param, scope, 0, &value, size);
    
    AURenderCallbackStruct inputCallbackStruct;
    inputCallbackStruct.inputProc = inputCallback;
    inputCallbackStruct.inputProcRefCon = (__bridge void *)self;
    AUGraphSetNodeInputCallback(_graph, _mixerNode, 0, &inputCallbackStruct);
    AudioUnitAddRenderNotify(_outputUnit, outputCallback, (__bridge void *)self);
    
    AudioUnitParameterID mixerParam;
    mixerParam = kMultiChannelMixerParam_Volume;
    
    AudioUnitGetParameter(_mixerUnit, mixerParam, kAudioUnitScope_Input, 0, &_volume);
    AudioUnitGetParameter(_timePitchUnit, kNewTimePitchParam_Rate, kAudioUnitScope_Global, 0, &_rate);
    AudioUnitGetParameter(_timePitchUnit, kNewTimePitchParam_Pitch, kAudioUnitScope_Global, 0, &_pitch);
    
    [self setAsbd:asbd];
    [self reconnectTimePitchNodeForce:YES];

    AUGraphInitialize(_graph);
}

- (void)destroy
{
    AUGraphStop(_graph);
    AUGraphUninitialize(_graph);
    AUGraphClose(_graph);
    DisposeAUGraph(_graph);
    
    

    if (_outData) {
        free(_outData);
        _outData = NULL;
    }
}

- (void)disconnectNodeInput:(AUNode)sourceNode destNode:(AUNode)destNode
{
    UInt32 count = 8;
    AUNodeInteraction interactions[8];
    if (AUGraphGetNodeInteractions(_graph, destNode, &count, interactions) == noErr) {
        for (UInt32 i = 0; i < MIN(count, 8); i++) {
            AUNodeInteraction interaction = interactions[i];
            if (interaction.nodeInteractionType == kAUNodeInteraction_Connection) {
                AUNodeConnection connection = interaction.nodeInteraction.connection;
                if (connection.sourceNode == sourceNode) {
                    AUGraphDisconnectNodeInput(_graph, connection.destNode, connection.destInputNumber);
                    break;
                }
            }
        }
    }
}

- (void)reconnectTimePitchNodeForce:(BOOL)force
{
    BOOL needsTimePitchNode = (_rate != 1.0) || (_pitch != 0.0);
    if (_needsTimePitchNode != needsTimePitchNode || force) {
        _needsTimePitchNode = needsTimePitchNode;
        if (needsTimePitchNode) {
            [self disconnectNodeInput:_mixerNode destNode:_outputNode];
            AUGraphConnectNodeInput(_graph, _mixerNode, 0, _timePitchNode, 0);
            AUGraphConnectNodeInput(_graph, _timePitchNode, 0, _outputNode, 0);
        } else {
            [self disconnectNodeInput:_mixerNode destNode:_timePitchNode];
            [self disconnectNodeInput:_timePitchNode destNode:_outputNode];
            AUGraphConnectNodeInput(_graph, _mixerNode, 0, _outputNode, 0);
        }
        AUGraphUpdate(_graph, NULL);
    }
}

#pragma mark - Interface

- (void)play
{
    if ([self isPlaying] == NO) {
        AUGraphStart(_graph);
    }
}

- (void)pause
{
    if ([self isPlaying] == YES) {
        AUGraphStop(_graph);
    }
}

- (void)flush
{
    AudioUnitReset(_mixerUnit, kAudioUnitScope_Global, 0);
    AudioUnitReset(_outputUnit, kAudioUnitScope_Global, 0);
    AudioUnitReset(_timePitchUnit, kAudioUnitScope_Global, 0);
}

#pragma mark - Setter & Getter

- (BOOL)isPlaying
{
    Boolean ret = FALSE;
    AUGraphIsRunning(_graph, &ret);
    return ret == TRUE ? YES : NO;
}

- (void)setVolume:(float)volume
{
    if (_volume == volume) {
        return;
    }
    AudioUnitParameterID param;
    param = kMultiChannelMixerParam_Volume;
    if (AudioUnitSetParameter(_mixerUnit, param, kAudioUnitScope_Input, 0, volume, 0) == noErr) {
        _volume = volume;
    }
}

- (void)setRate:(float)rate
{
    if (_rate == rate) {
        return;
    }
    if (AudioUnitSetParameter(_timePitchUnit, kNewTimePitchParam_Rate, kAudioUnitScope_Global, 0, rate, 0) == noErr) {
        _rate = rate;
        [self reconnectTimePitchNodeForce:NO];
    }
}

- (void)setPitch:(float)pitch
{
    if (_pitch == pitch) {
        return;
    }
    if (AudioUnitSetParameter(_timePitchUnit, kNewTimePitchParam_Pitch, kAudioUnitScope_Global, 0, pitch, 0) == noErr) {
        _pitch = pitch;
        [self reconnectTimePitchNodeForce:NO];
    }
}

- (void)setAsbd:(AudioStreamBasicDescription)asbd
{
    UInt32 size = sizeof(AudioStreamBasicDescription);
    AudioUnitPropertyID param = kAudioUnitProperty_StreamFormat;
    if (AudioUnitSetProperty(_mixerUnit, param, kAudioUnitScope_Input, 0, &asbd, size) == noErr &&
        AudioUnitSetProperty(_mixerUnit, param, kAudioUnitScope_Output, 0, &asbd, size) == noErr &&
        AudioUnitSetProperty(_outputUnit, param, kAudioUnitScope_Input, 0, &asbd, size) == noErr &&
        AudioUnitSetProperty(_timePitchUnit, param, kAudioUnitScope_Input, 0, &asbd, size) == noErr &&
        AudioUnitSetProperty(_timePitchUnit, param, kAudioUnitScope_Output, 0, &asbd, size) == noErr) {
        _asbd = asbd;
    } else {
        AudioUnitSetProperty(_mixerUnit, param, kAudioUnitScope_Input, 0, &_asbd, size);
        AudioUnitSetProperty(_mixerUnit, param, kAudioUnitScope_Output, 0, &_asbd, size);
        AudioUnitSetProperty(_outputUnit, param, kAudioUnitScope_Input, 0, &_asbd, size);
        AudioUnitSetProperty(_timePitchUnit, param, kAudioUnitScope_Input, 0, &_asbd, size);
        AudioUnitSetProperty(_timePitchUnit, param, kAudioUnitScope_Output, 0, &_asbd, size);
    }
}

#pragma mark - Callback

- (OSStatus)render:(AudioBufferList *)ioData count:(UInt32)inNumberFrames {
    //默认数据都清0 -- 即时没有返回数据也有0数据
    UInt32 numberBuffers = ioData->mNumberBuffers;
    for (int iBuffer=0; iBuffer < numberBuffers; ++iBuffer) {
        memset(ioData->mBuffers[iBuffer].mData, 0, ioData->mBuffers[iBuffer].mDataByteSize);
    }
    
    int channels  = ChannelsPerFrame;
//    int bytesPerFrame = BytesPerFrame;
    int channelsPerFrame = ChannelsPerFrame;
    int bitsPerChannel = BitsPerChannel;
    
    if(self.delegate)
    {
        [self.delegate fillAudioData:_outData numFrames:inNumberFrames numChannels:channels];
        
        //这个16位和32位没有处理
//        for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
//            memcpy((SInt16 *)ioData->mBuffers[iBuffer].mData, _outData, ioData->mBuffers[iBuffer].mDataByteSize);
//        }
        
        if (bitsPerChannel == 32) {
            float scalar = 0;
            for (UInt32 i = 0; i < numberBuffers; ++i) {
                AudioBuffer buf = ioData->mBuffers[i];
                UInt32 channels = buf.mNumberChannels;
                for (UInt32 j = 0; j < channels; ++j) {
                    vDSP_vsadd(_outData + i + j, channelsPerFrame, &scalar, (float *)buf.mData + j, channels, inNumberFrames);
                }
            }
        } else if (bitsPerChannel == 16) {
            float scalar = INT16_MAX;
            vDSP_vsmul(_outData, 1, &scalar, _outData, 1, inNumberFrames * channelsPerFrame);
            for (UInt32 i = 0; i < numberBuffers; ++i) {
                AudioBuffer buf = ioData->mBuffers[i];
                UInt32 channels = buf.mNumberChannels;
                for (UInt32 j = 0; j < channels; ++j) {
                    vDSP_vfix16(_outData + i + j, channelsPerFrame, (short *)buf.mData + j, channels, inNumberFrames);
                }
            }
        }
    }
    
    
    
//    _frameReaderBlock(_audioData, inNumberFrames, _channelsPerFrame);
    
    
    
    return noErr;
}

static OSStatus inputCallback(void *inRefCon,
                              AudioUnitRenderActionFlags *ioActionFlags,
                              const AudioTimeStamp *inTimeStamp,
                              UInt32 inBusNumber,
                              UInt32 inNumberFrames,
                              AudioBufferList *ioData)
{
    @autoreleasepool {
        HLAudioPlayer *self = (__bridge HLAudioPlayer *)inRefCon;
        [self render:ioData count:inNumberFrames];
    }
    return noErr;
}

static OSStatus outputCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData)
{
    @autoreleasepool {
        HLAudioPlayer *self = (__bridge HLAudioPlayer *)inRefCon;
        if ((*ioActionFlags) & kAudioUnitRenderAction_PreRender) {
            if ([self.delegate respondsToSelector:@selector(audioPlayer:willRender:)]) {
                [self.delegate audioPlayer:self willRender:inTimeStamp];
            }
        } else if ((*ioActionFlags) & kAudioUnitRenderAction_PostRender) {
            if ([self.delegate respondsToSelector:@selector(audioPlayer:didRender:)]) {
                [self.delegate audioPlayer:self didRender:inTimeStamp];
            }
        }
    }
    return noErr;
}

@end
