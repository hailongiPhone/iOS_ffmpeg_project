//
//  HLAVDecoderOutput.h
//  ffmpegProject
//
//  Created by hailong on 2020/01/07.
//  Copyright © 2020 HL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "HLAVFrame.h"
#import "HLAVFrameVideo.h"
#import "HLAVFrameAudio.h"

/**
 *  作为HLAVDecoder 处理的输出
 *
 */


NS_ASSUME_NONNULL_BEGIN

@interface HLAVDecoderOutput : NSObject

@property (nonatomic,strong)NSMutableArray<HLAVFrameVideo *> * videoframes;
@property (nonatomic,assign)CGFloat videoframesDuration;

@property (nonatomic,strong)NSMutableArray<HLAVFrameAudio *> * audioframes;
@property (nonatomic,assign)CGFloat audioframesDuration;

- (instancetype)init;

- (void) addOutput:(HLAVDecoderOutput*)output;
- (HLAVFrameVideo *) consumerVideoFrame;
- (HLAVFrameAudio *) consumerAudioFrame;

- (BOOL) hasAudioData;
- (BOOL) hasVideoData;

- (CGFloat)maxDuration;
- (CGFloat)minPosition;
@end

NS_ASSUME_NONNULL_END
