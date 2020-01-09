//
//  HLAVInfo.h
//  ffmpegProject
//
//  Created by hailong on 2020/01/02.
//  Copyright © 2020 HL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

/**
 *  HLAVInfo 音视频文件加载后读取的信息
 *  区分 音视频固有信息 以及 decoder 过程中的帮助信息
 *      视频轨道应该只有一个，声道，和字幕应该有多个
 *
 */

NS_ASSUME_NONNULL_BEGIN

static const NSInteger HLAVNoStream = NSIntegerMax;


@interface HLAVInfo : NSObject

@property (nonatomic, strong) NSString *path;
@property (nonatomic, assign) BOOL isNetwork;

@property (nonatomic, assign) BOOL isEOF;
@property (nonatomic, assign) CGFloat startTime;
@property (nonatomic, assign) CGFloat position;     //当前解析到的positon还是播放的position
@property (nonatomic, assign) CGFloat duration;
@property (nonatomic, assign) CGFloat fps;

//video
@property (nonatomic, assign) BOOL isYUV;
@property (nonatomic, assign) BOOL hasVideo;
@property (nonatomic, assign) double videoFPS;
@property (nonatomic, assign) double videoTimebase;
@property (nonatomic, assign) CGFloat sampleRate;
@property (nonatomic, assign) NSUInteger frameWidth;
@property (nonatomic, assign) NSUInteger frameHeight;
@property (nonatomic, strong) NSString *videoStreamFormatName;

//audio
@property (nonatomic, assign) BOOL hasAudio;
@property (nonatomic, assign) double audioTimebase;
@property (readwrite, nonatomic) NSUInteger audioStreamsCount;

//stream
@property (nonatomic, readwrite)NSInteger videoStream;
@property (nonatomic, strong)NSArray<NSNumber*> *audioStreams;
@property (nonatomic, strong)NSArray<NSNumber*> *subtitleStreams;
@property (nonatomic, readwrite) NSInteger artworkStream;
@property (nonatomic, readonly) BOOL hasArtwork;
@property (nonatomic, readwrite) NSInteger selectedSubtitleStream;
@property (nonatomic, readonly) BOOL hasSubtitleStream;
@property (nonatomic, readwrite) NSInteger selectedAudioStream;
@property (nonatomic, readonly) BOOL hasAudioStream;
@property (nonatomic, readonly) BOOL hasVideoStream;

//other
@property (nonatomic, assign) BOOL hasPicture;
@property (readwrite, nonatomic, strong) NSDictionary *info;

@end

NS_ASSUME_NONNULL_END
