//
//  HLAVDecoder.h
//  ffmpegProject
//
//  Created by hailong on 2020/01/02.
//  Copyright © 2020 HL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HLAVInfo.h"
#import "HLAVFrame.h"
#import "HLAVOutputFormat.h"
#import "HLAVDecoderOutput.h"


/**
 *  HLAVDecoder 对应于 打开一个音视频文件
 *      解封装
 *                      读取轨道信息 - 声音，视频，字幕  附加信息
 *      主要操作
 *                         读取音视频基本信息
 *                         读取音视频中的帧数据Frame
 *                         跳转到指定的时间点
 *                         指定视频输出格式
 *                         ？是否s需要指定音频的格式那？
 *                         音视频的同步格式？最简单是视频为主，按照视频每一帧的duration来判断更新
 */

NS_ASSUME_NONNULL_BEGIN

@protocol HLAVDecoderProtocol <NSObject>

@property (nonatomic, strong) HLAVInfo *avInfo;
@property (nonatomic, strong) HLAVOutputFormat * outputFormat;
@property (nonatomic, assign) BOOL  isEOF;


//input
- (BOOL) openFile: (NSString *) path
            error: (NSError **) perror;
- (void) closeFile;

//output
- (BOOL) setupOutputFormat: (HLAVOutputFormat *) outputFormat;
- (HLAVDecoderOutput *) decodeFrames: (CGFloat) minDuration;

//action
- (void)seek:(double)position;

@end


@interface HLAVDecoder : NSObject <HLAVDecoderProtocol>

@property (nonatomic, strong) HLAVInfo *avInfo;
@property (nonatomic, strong) HLAVOutputFormat * outputFormat;
@property (nonatomic, assign) BOOL  isEOF;

//input
- (BOOL) openFile: (NSString *) path
            error: (NSError **) perror;
- (void) closeFile;

//output
- (BOOL) setupOutputFormat: (HLAVOutputFormat *) outputFormat;
- (HLAVDecoderOutput *) decodeFrames: (CGFloat) minDuration;

//action
- (void) seek:(double)position;
@end

NS_ASSUME_NONNULL_END
