//
//  HLFFmpegHelper.h
//  ffmpegProject
//
//  Created by hailong on 2020/01/02.
//  Copyright © 2020 HL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/imgutils.h>
#include <libavutil/display.h>
#include <libavutil/eval.h>
#include <libswscale/swscale.h>

NS_ASSUME_NONNULL_BEGIN

@interface HLFFmpegHelper : NSObject
+ (nullable AVFormatContext *)openInput:(NSString *)filename;


//输出
+ (nullable AVFormatContext *)createOutputFormatContext:(NSString *)outputfilename;
+ (void)setupOutPutFormat:(AVFormatContext *)o_fmtctx with:(AVFormatContext *)i_fmtctx justType:(enum AVMediaType) justType;
+ (void)copyAllFrom:(AVFormatContext *)i_fmtctx to:(AVFormatContext *)o_fmtctx justType:(enum AVMediaType) justType;

//stream获取
+(NSArray<NSNumber *> *) allStreamsWithType:(enum AVMediaType )codecType InFormatContext:(AVFormatContext *)formatCtx;
+(NSInteger) bestStreamIndexWithType:(enum AVMediaType )codecType InFormatContext:(AVFormatContext *)formatCtx;
//- (int)findVideoStream:(AVFormatContext *)fmtctx context:(AVCodecContext **)context pictureStream:(int *)pictureStream;
//- (int)findAudioStream:(AVFormatContext *)fmtctx context:(AVCodecContext **)context;

//解码器加载
+ (nullable AVCodecContext *) loadCodecFor:(AVFormatContext *)fmtctx streamIndex:(NSInteger)streamIndex;

//图片格式转换
+ (float)calculateSclaeSize:(CGSize)original dest:(CGSize)dest;
+ (UIImage *)imageFromAVPicture:(AVFrame *)imageFrame width:(int)width height:(int)height;


//数据读取
+ (NSData *)dataFromVideoFrame:(UInt8 *)data linesize:(int)linesize width:(int)width height:(int)height;
+ (void)stream:(AVStream *)stream fps:(double *)fps timebase:(double *)timebase default:(double)defaultTimebase;
+ (double)rotationFromVideoStream:(AVStream *)stream;

+ (nullable UIImage *)imageFromAVFrame:(AVFrame *)pFrame video_dec_ctx:(AVCodecContext *)video_dec_ctx outputHeight:(int)outputHeight outputWidth:(int)outputWidth;
@end

NS_ASSUME_NONNULL_END
