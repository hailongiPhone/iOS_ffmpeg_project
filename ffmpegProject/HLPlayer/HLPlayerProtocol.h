//
//  HLPlayerInterface.h
//  ffmpegProject
//
//  Created by hailong on 2019/12/31.
//  Copyright © 2019 HL. All rights reserved.
//

#import <Foundation/Foundation.h>



@protocol HLPlayerControllerProtocol <NSObject>

//元数据？
@property (nonatomic, strong) NSDictionary *metadata;


//主要是内存考虑
@property (nonatomic) double minBufferDuration;
@property (nonatomic) double maxBufferDuration;

//播放进度
@property (nonatomic) double position;
@property (nonatomic) double duration;

//状态
@property (nonatomic) BOOL opened;
@property (nonatomic) BOOL playing;
@property (nonatomic) BOOL buffering;


//基本操作
- (void)open:(NSString *)url;
- (void)close;
- (void)play;
- (void)pause;

//获取当前的帧数据
- (id)currentVideoFrame;
- (id)currentAudioFrame;

@end


@protocol HLPlayerProtocol <NSObject>

//元数据？
@property (nonatomic, strong) NSDictionary *metadata;


//主要是内存考虑
@property (nonatomic) double minBufferDuration;
@property (nonatomic) double maxBufferDuration;

//播放进度
@property (nonatomic) double position;
@property (nonatomic) double duration;

//状态
@property (nonatomic) BOOL opened;
@property (nonatomic) BOOL playing;
@property (nonatomic) BOOL buffering;


//基本操作
- (void)open:(NSString *)url;
- (void)close;
- (void)play;
- (void)pause;

//控制器，展示其，同步器
@property (nonatomic) HLPlayerControllerProtocol playerContoller;
@property (nonatomic) id displayView;
@property (nonatomic) id soundManager;

@end



@protocol HLAVSynchronizer <NSObject>

@property (nonatomic) HLClock audioPTS;
@property (nonatomic) HLClock videoPTS;
@property (nonatomic) BOOL videoPTS;

@end



@protocol HLClock <NSObject>

@property (nonatomic) id pts;
@property (nonatomic) id drift;
@property (nonatomic) BOOL paused;


//double pts;           /* clock base */
//double pts_drift;     /* clock base minus time at which we updated the clock */
//double last_updated;
//double speed;
//int serial;           /* clock is based on a packet with this serial */
//int paused;
//int *queue_serial;    /* pointer to the current packet queue serial, used for obsolete clock detection */
@end


