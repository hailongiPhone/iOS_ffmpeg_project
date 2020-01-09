//
//  HLAudioPlayer.h
//  ffmpegProject
//
//  Created by hailong on 2020/01/07.
//  Copyright © 2020 HL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

/**
 *   音频格式暂时是写死的，可以看情况，
 *   可以从Decoder中读取，也可以提供设置才行，
 *   有个不确定的问题是 iOS播放必须32位，而ffmpeg似乎解析出来是16位的
 */

NS_ASSUME_NONNULL_BEGIN

@protocol HLAudioPlayerDelegate;
@protocol HLAudioPlayerProtocol <NSObject>
@property (nonatomic, weak) id<HLAudioPlayerDelegate> delegate;

@property (nonatomic) float rate;
@property (nonatomic) float pitch;
@property (nonatomic) float volume;

@property (nonatomic) AudioStreamBasicDescription asbd;
- (BOOL)isPlaying;
- (void)play;
- (void)pause;
- (void)flush;

@end


@class HLAudioPlayer;
@protocol HLAudioPlayerDelegate <NSObject>

- (NSInteger) fillAudioData:(float*) sampleBuffer
                  numFrames:(NSInteger)frameNum
                numChannels:(NSInteger)channels;

@optional
- (void)audioPlayer:(HLAudioPlayer *)player
         willRender:(const AudioTimeStamp *)timestamp;
- (void)audioPlayer:(HLAudioPlayer *)player
          didRender:(const AudioTimeStamp *)timestamp;
@end


@interface HLAudioPlayer : NSObject <HLAudioPlayerProtocol>
@property (nonatomic, weak) id<HLAudioPlayerDelegate> delegate;

@property (nonatomic) float rate;       //速度
@property (nonatomic) float pitch;      //音调
@property (nonatomic) float volume;     

@property (nonatomic) AudioStreamBasicDescription asbd;
- (BOOL)isPlaying;
- (void)play;
- (void)pause;
- (void)flush;
@end

NS_ASSUME_NONNULL_END
