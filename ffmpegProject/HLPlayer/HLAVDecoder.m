//
//  HLAVDecoder.m
//  ffmpegProject
//
//  Created by hailong on 2020/01/02.
//  Copyright © 2020 HL. All rights reserved.
//

#import "HLAVDecoder.h"

#import <Accelerate/Accelerate.h>

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>

#import "HLFFmpegHelper.h"
#import "HLAVFrame.h"

#import "HLAVFrameAudio.h"
#import "HLAVFrameVideo.h"
#import "HLAVFrameSubtitle.h"
#import "HLAVFrameArtwork.h"
#import "HLAVDecoderOutput.h"


static void avStreamFPSTimeBase(AVStream *st, CGFloat defaultTimeBase, CGFloat *pFPS, CGFloat *pTimeBase)
{
    CGFloat fps, timebase;
    
    // ffmpeg提供了一个把AVRatioal结构转换成double的函数
    // 默认0.04 意思就是25帧
    if (st->time_base.den && st->time_base.num)
        timebase = av_q2d(st->time_base);
    else if(st->time_base.den && st->time_base.num)
        timebase = av_q2d(st->time_base);
    else
        timebase = defaultTimeBase;
    
//    if (st->codec->ticks_per_frame != 1) {
//    }
    
    // 平均帧率
    if (st->avg_frame_rate.den && st->avg_frame_rate.num)
        fps = av_q2d(st->avg_frame_rate);
    else if (st->r_frame_rate.den && st->r_frame_rate.num)
        fps = av_q2d(st->r_frame_rate);
    else
        fps = 1.0 / timebase;
    
    if (pFPS)
        *pFPS = fps;
    if (pTimeBase)
        *pTimeBase = timebase;
}


@interface HLAVDecoder (){
    AVFormatContext *_formatCtx;
    
    AVCodecContext *_videoCodecCtx;
    AVCodecContext *_audioCodecCtx;
    AVCodecContext *_subtitleCodecCtx;
    
    AVFrame             *_videoFrame;
    AVFrame             *_audioFrame;

    
    //YUV->RGB缓存相关
    AVFrame             *_rgbFrame;
    BOOL                _rgbFrameValid;
    
    //YUV->RGB使用libsscale
    struct SwsContext   *_swsContext;
    
    //音频使用 libswresample
    SwrContext          *_swrContext;
    void                *_swrBuffer;
    NSUInteger          _swrBufferSize;
    
    
}
@property (nonatomic, assign) HLAVFrameVideoFormat ouputFrameVideoFormat;

//@property (nonatomic, assign) AVFormatContext     *_formatCtx;
//@property (nonatomic, assign) AVCodecContext      *_videoCodecCtx;
//@property (nonatomic, assign)AVCodecContext      *_audioCodecCtx;

-(HLAVFrameVideo *)handleVideoFrame:(AVFrame *)packet;
-(HLAVFrameAudio *)handleAudioFrame:(AVFrame *)packet;
-(HLAVFrameSubtitle *)handleSubtitleFrame:(AVFrame *)packet;
-(HLAVFrameArtwork *)handleArtworkFrame:(AVFrame *)packet;

@end

@implementation HLAVDecoder

//input
- (BOOL) openFile: (NSString *) path
            error: (NSError **) perror;
{
    NSAssert(path, @"nil path");
    NSAssert(!_formatCtx, @"already open");
    
    BOOL result = YES;
    
    //解封装
    _formatCtx = [HLFFmpegHelper openInput:path];
    if (!_formatCtx) {
        return NO;
    }
    
    self.outputFormat = [HLAVOutputFormat defaultFormat];
    self.avInfo = [HLAVInfo new];
    self.avInfo.path = path;
    
    //读取轨道信息stream
    [self readAllStreamInfo:_formatCtx toAVInfo:self.avInfo];
    
    //加载解码器
    [self loadCoders:_formatCtx streamInfo:self.avInfo];
    
    //加载基础时间信息
    [self readbaseInfo:_formatCtx toAVInfo:self.avInfo];
    
    //视频数据和声音数据都要按照平台熟悉进行数据格式修正,以及输出格式来调整
    [self lazyLoadVideoAdjust:_videoCodecCtx];
    
    return result;
}

- (void) readAllStreamInfo:(AVFormatContext *) formatCtx toAVInfo:(HLAVInfo*)avinfo;
{
    NSMutableArray *aArr = [NSMutableArray array];
    NSMutableArray *subtitleArr = [NSMutableArray array];
    NSInteger artworkStream = HLAVNoStream;
    NSInteger videoStream = HLAVNoStream;
    
    AVStream * stream = NULL;
    for (NSInteger i = 0; i < formatCtx->nb_streams; ++i){
        stream = formatCtx->streams[i];
        switch (stream->codecpar->codec_type) {
            case AVMEDIA_TYPE_VIDEO:{
                int disposition = stream->disposition;
                if ((disposition & AV_DISPOSITION_ATTACHED_PIC) == 0) { // Not attached picture
                    videoStream = i;
                }else{
                    artworkStream = i;
                }
            }
                break;
            case AVMEDIA_TYPE_AUDIO:
                [aArr addObject:@(i)];
                break;
            case AVMEDIA_TYPE_SUBTITLE:
                [subtitleArr addObject:@(i)];
                break;
            default:
                break;
        }
    }
    
    avinfo.videoStream = videoStream;
    avinfo.audioStreams = [aArr copy];
    avinfo.subtitleStreams = [subtitleArr copy];
    avinfo.artworkStream = artworkStream;
    avinfo.selectedAudioStream = [[aArr firstObject] integerValue];
    avinfo.selectedSubtitleStream = [[subtitleArr firstObject] integerValue];
}

//需要等gstream信息，coder加载完成后才能读取
- (void) readbaseInfo:(AVFormatContext *) formatCtx toAVInfo:(HLAVInfo*)avinfo;
{
    avinfo.frameWidth = _videoCodecCtx->width;
    avinfo.frameHeight = _videoCodecCtx->height;
    
    if ([avinfo hasVideoStream]) {
        [self readVideoInfo:formatCtx->streams[avinfo.videoStream]
                   toAVInfo:avinfo];
    }
    
    if([avinfo hasAudioStream]){
        [self readAudioInfo:formatCtx->streams[avinfo.selectedAudioStream]
                   toAVInfo:avinfo];
    }
    
    
}

- (void)readVideoInfo:(AVStream *) vstream toAVInfo:(HLAVInfo*)avinfo;
{
    
    CGFloat fps;
    CGFloat timebase;
    avStreamFPSTimeBase(vstream, 0.04, &fps, &timebase);
    avinfo.fps = fps;
    avinfo.videoTimebase = timebase;
    
}

- (void)readAudioInfo:(AVStream *) vstream toAVInfo:(HLAVInfo*)avinfo;
{
    
    CGFloat timebase;
    avStreamFPSTimeBase(vstream, 0.025, 0, &timebase);
    avinfo.audioTimebase = timebase;
    
}

- (void) loadCoders:(AVFormatContext *) formatCtx streamInfo:(HLAVInfo *)avInfo;
{
    _videoCodecCtx = [HLFFmpegHelper loadCodecFor:formatCtx streamIndex:avInfo.videoStream];
    _audioCodecCtx = [HLFFmpegHelper loadCodecFor:formatCtx streamIndex:avInfo.selectedAudioStream];;
    _subtitleCodecCtx = [HLFFmpegHelper loadCodecFor:formatCtx streamIndex:avInfo.selectedSubtitleStream];
}


- (struct SwsContext *) lazyLoadVideoAdjust:(AVCodecContext *)video_dec_ctx;
{
    if (_swsContext) {
        return _swsContext;
    }
    
    int ret = 0;
    int outputWidth = video_dec_ctx->width;
    int outputHeight = video_dec_ctx->height;
    _rgbFrame = av_frame_alloc();
    
    ret = av_image_alloc(_rgbFrame->data, _rgbFrame->linesize, outputWidth, outputHeight, AV_PIX_FMT_RGB24, 1);
    if(ret < 0){
        HLAVLog(@"lazyLoadVideoAdjust _rgbFrame error");
        return nil;
    }
    static int sws_flags =  SWS_FAST_BILINEAR;
    _swsContext = sws_getContext(video_dec_ctx->width,
                                 video_dec_ctx->height,
                                 video_dec_ctx->pix_fmt,
                                 outputWidth,
                                 outputHeight,
                                 AV_PIX_FMT_RGB24,
                                 sws_flags, NULL, NULL, NULL);
    
    return _swsContext;
    
}

- (void) freeSwsContext;
{
    if (_swsContext) {
        sws_freeContext(_swsContext);
        _swsContext = NULL;
    }
}

- (void) closeFile;
{
    
}

//output
- (BOOL) setupOutputFormat: (HLAVOutputFormat *) outputFormat;
{
    BOOL result = NO;
    if (outputFormat) {
        self.outputFormat = outputFormat;
    }
    
    return result;
}
- (HLAVDecoderOutput *) decodeFrames: (CGFloat) minDuration;
{
    if (!self.avInfo && ( !self.avInfo.hasVideoStream && !self.avInfo.hasAudioStream )) {
        return nil;
    }
    
    AVPacket packet;
    HLAVDecoderOutput * output = [HLAVDecoderOutput new];
    BOOL finished = NO;
    while (!finished) {
        if (av_read_frame(_formatCtx, &packet) < 0) {
            self.isEOF = YES;
            break;
        }
        
        HLAVDecoderOutput * tmp;
        
        if (packet.stream_index == self.avInfo.videoStream) {
            tmp = [self handleVideoPacket:&packet];
            
        } else if (packet.stream_index == self.avInfo.selectedAudioStream) {
            tmp = [self handleAudioPacket:&packet];
        } else if (packet.stream_index == self.avInfo.artworkStream) {
            [self handleArtworkPacket:&packet];
        } else if (packet.stream_index == self.avInfo.selectedSubtitleStream) {
            [self handleSubtitlePacket:&packet];
        }
        
        if (tmp) {
            [output addOutput:tmp];
        }
        
        if (output.maxDuration > minDuration)
            finished = YES;
        
        av_packet_unref(&packet);
    }
    
    return output;
}

//Frame处理
- (AVFrame *) lazyloadVideoFrame;
{
    if (_videoFrame) {
        return _videoFrame;
    }
    
    _videoFrame = av_frame_alloc();
    return _videoFrame;
}

- (AVFrame *) lazyloadAudioFrame;
{
    if (_audioFrame) {
        return _audioFrame;
    }
    
    _audioFrame = av_frame_alloc();
    return _audioFrame;
}

-(HLAVDecoderOutput *)handleVideoPacket:(AVPacket *)pkt;
{
    int ret = 0;
    HLAVDecoderOutput * output = [HLAVDecoderOutput new];
    AVCodecContext * video_dec_ctx = _videoCodecCtx;
    AVFrame * pFrame = [self lazyloadVideoFrame];
    
    ret = avcodec_send_packet(video_dec_ctx, pkt);
    while (ret >= 0) {
        ret = avcodec_receive_frame(video_dec_ctx, pFrame);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF){
            continue;
        }else if (ret < 0) {
            fprintf(stderr, "Error during decoding\n");
            exit(1);
        }
        
        printf("saving frame %3d\n", video_dec_ctx->frame_number);
        
        //图片尺寸大小播放器的时候没必要修改，反而增加复杂度
        //                int outputWidth = video_dec_ctx->width;
        //                int outputHeight = video_dec_ctx->height;
        //        float scale = [self calculateSclaeSize:CGSizeMake(outputWidth, outputHeight) dest:desSize];
        //        outputWidth *= scale;
        //        outputHeight *= scale;
        //        outputHeight = (outputHeight >> 4) << 4 ;
        //        outputWidth = (outputWidth >> 4) <<4 ;
        
        /* the picture is allocated by the decoder. no need to
         free it */
        //从AVFrame中读取颜色信息，-- 更具视频输出来确定格式
        //        id iamge = [HLFFmpegHelper imageFromAVFrame:pFrame
        //                             video_dec_ctx:video_dec_ctx
        //                              outputHeight:outputHeight
        //                               outputWidth:outputWidth];
        HLAVFrameVideo* videoframe = [self handleVideoFrame:pFrame];
        [output.videoframes addObject:videoframe];
        output.videoframesDuration += videoframe.duration;
        
        break;
    }
    
    return output;
}

-(HLAVFrameVideo *)handleVideoFrame:(AVFrame *)avframe;
{
    HLAVFrameVideo *frame;
    
    double videoTimeBase = self.avInfo.videoTimebase;
    
    if (self.outputFormat.videoFormat == HLAVFrameVideoFormatYUV) {
        
        HLAVFrameVideoYUV * yuvFrame = [HLAVFrameVideoYUV new];
        yuvFrame.luma = [HLFFmpegHelper dataFromVideoFrame:_videoFrame->data[0]
                                                  linesize:_videoFrame->linesize[0]
                                                     width:_videoCodecCtx->width
                                                    height:_videoCodecCtx->height];
        
        yuvFrame.chromaBlue = [HLFFmpegHelper dataFromVideoFrame:_videoFrame->data[1]
                                                        linesize:_videoFrame->linesize[1]
                                                           width:_videoCodecCtx->width / 2
                                                          height:_videoCodecCtx->height / 2];
        
        yuvFrame.chromaRed = [HLFFmpegHelper dataFromVideoFrame:_videoFrame->data[2]
                                                       linesize:_videoFrame->linesize[2]
                                                          width:_videoCodecCtx->width / 2
                                                         height:_videoCodecCtx->height / 2];
        
        frame = yuvFrame;
        
    } else {
        if (!_swsContext &&
            ![self lazyLoadVideoAdjust:_videoCodecCtx]) {
            
            HLAVLog(@" _swsContext 加载失败");
            return nil;
        }
        
        int outputWidth = _videoCodecCtx->width;
        int outputHeight = _videoCodecCtx->height;
        
        AVFrame *imageFrame = av_frame_alloc();
        int ret = av_image_alloc(imageFrame->data, imageFrame->linesize, outputWidth, outputHeight, AV_PIX_FMT_RGB24, 1);
        if(ret < 0){
            av_frame_unref(imageFrame);
            return nil;
        }
        
        //转换RGBA
        sws_scale(_swsContext,
                  (void*)avframe->data,
                  avframe->linesize,
                  0,
                  outputHeight,
                  imageFrame->data,
                  imageFrame->linesize);
        
        HLAVFrameVideoRGB *rgbFrame = [HLAVFrameVideoRGB new];
        
        rgbFrame.linesize = imageFrame->linesize[0];
        rgbFrame.data = [HLFFmpegHelper dataFromVideoFrame:imageFrame->data[0]
                                                  linesize:imageFrame->linesize[0]
                                                     width:_videoCodecCtx->width
                                                    height:_videoCodecCtx->height];;
        frame = rgbFrame;
    }
    
    frame.width = _videoCodecCtx->width;
    frame.height = _videoCodecCtx->height;
    
    //时间计算
    frame.position = avframe->best_effort_timestamp * videoTimeBase;
    
    const int64_t frameDuration = _videoFrame->pkt_duration;
    if (frameDuration) {
        
        frame.duration = frameDuration * videoTimeBase;
        frame.duration += _videoFrame->repeat_pict * videoTimeBase * 0.5;
        
        //if (_videoFrame->repeat_pict > 0) {
        //    LoggerVideo(0, @"_videoFrame.repeat_pict %d", _videoFrame->repeat_pict);
        //}
        
    } else {
        
        // sometimes, ffmpeg unable to determine a frame duration
        // as example yuvj420p stream from web camera
        frame.duration = 1.0 / self.avInfo.fps;
    }
    
    HLAVLog(@"VFD: %.4f %.4f | %lld ",
            frame.position,
            frame.duration,
            avframe->pkt_pos);
    
    return frame;
}

-(HLAVDecoderOutput *)handleAudioPacket:(AVPacket *)packet;
{
    HLAVDecoderOutput * output = [HLAVDecoderOutput new];
    
    AVCodecContext * codecCtx = _audioCodecCtx;
    AVFrame * pFrame = [self lazyloadAudioFrame];
    int ret = 0;
    
    ret = avcodec_send_packet(codecCtx, packet);
    while (ret >= 0) {
        ret = avcodec_receive_frame(codecCtx, pFrame);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF){
            continue;
        }else if (ret < 0) {
            fprintf(stderr, "Error during decoding\n");
            exit(1);
        }
        
//        printf("audio frame %3d\n", codecCtx->frame_number);
        
        HLAVFrameAudio* audioFrame = [self handleAudioFrame:pFrame];
        
        [output.audioframes addObject:audioFrame];
        output.audioframesDuration += audioFrame.duration;
    }
    
    return output;
}

- (HLAVFrameAudio *) handleAudioFrame:(AVFrame *)frame;
{
    if (!_swrContext &&
        ![self lazyLoadAudioAdjust:_audioCodecCtx]) {
        
        HLAVLog(@" _swrContext 加载失败");
        return nil;
    }
    
    float sampleRate = self.outputFormat.sampleRate;
    int channels = (int)self.outputFormat.channels;
    float timebase = self.avInfo.audioTimebase;
    int numFrames = 0;
    void * audioData;
    
    
    const int ratio = MAX(1, sampleRate / _audioCodecCtx->sample_rate) *
    MAX(1, channels / _audioCodecCtx->channels) * 2;
    
    const int bufSize = av_samples_get_buffer_size(NULL,
                                                   channels,
                                                   frame->nb_samples * ratio,
                                                   AV_SAMPLE_FMT_S16,
                                                   1);
    
    if (!_swrBuffer || _swrBufferSize < bufSize) {
        _swrBufferSize = bufSize;
        _swrBuffer = realloc(_swrBuffer, _swrBufferSize);
    }
    
    Byte *outbuf[2] = { _swrBuffer, 0 };
    
    numFrames = swr_convert(_swrContext,
                            outbuf,
                            frame->nb_samples * ratio,
                            (const uint8_t **)frame->data,
                            frame->nb_samples);
    
    if (numFrames < 0) {
        HLAVLog(@"fail resample audio");
        return nil;
    }
    
    //int64_t delay = swr_get_delay(_swrContext, audioManager.samplingRate);
    //if (delay > 0)
    //    LoggerAudio(0, @"resample delay %lld", delay);
    
    audioData = _swrBuffer;
    
    NSUInteger numElements = numFrames * channels;
    NSMutableData *data = [NSMutableData dataWithLength:numElements * sizeof(float)];
    
    float scale = 1.0 / (float)INT16_MAX ;
    vDSP_vflt16((SInt16 *)audioData, 1, data.mutableBytes, 1, numElements);
    vDSP_vsmul(data.mutableBytes, 1, &scale, data.mutableBytes, 1, numElements);
    
    HLAVFrameAudio *audioframe = [HLAVFrameAudio new];
    audioframe.position = _audioFrame->best_effort_timestamp * timebase;
    audioframe.duration = _audioFrame->pkt_duration * timebase;
    audioframe.data = data;
    
    if (audioframe.duration == 0) {
        // sometimes ffmpeg can't determine the duration of audio frame
        // especially of wma/wmv format
        // so in this case must compute duration
        audioframe.duration = data.length / (sizeof(float) * channels * sampleRate);
    }
    
//    HLAVLog(@"AFD: %.4f %.4f | %.4f ",
//            audioframe.position,
//            audioframe.duration,
//            audioframe.data.length / (8.0 * 44100.0));

    return audioframe;
}

//加载音频的时候，要考虑播放器是否支持相应的采样率，声道数，一般默认44100，2声道
- (SwrContext *) lazyLoadAudioAdjust:(AVCodecContext *)codecCtx;
{
    
    int numOutputChannels = (int)self.outputFormat.channels;
    int sampleRate = self.outputFormat.sampleRate;
    
    SwrContext *swrContext = NULL;
    
    swrContext = swr_alloc_set_opts(NULL,
                                    av_get_default_channel_layout(numOutputChannels),
                                    AV_SAMPLE_FMT_S16,
                                    sampleRate,
                                    av_get_default_channel_layout(codecCtx->channels),
                                    codecCtx->sample_fmt,
                                    codecCtx->sample_rate,
                                    0,
                                    NULL);
    
    if (!swrContext ||
        swr_init(swrContext)) {
        
        if (swrContext)
            swr_free(&swrContext);
        
        swrContext = NULL;
    }
    
    
    _swrContext = swrContext;
    
    return _swrContext;
}

-(HLAVFrameSubtitle *)handleSubtitlePacket:(AVPacket *)packet;
{
    //    int pktSize = packet.size;
    //
    //    while (pktSize > 0) {
    //
    //        AVSubtitle subtitle;
    //        int gotsubtitle = 0;
    //        int len = avcodec_decode_subtitle2(_subtitleCodecCtx,
    //                                          &subtitle,
    //                                          &gotsubtitle,
    //                                          &packet);
    //
    //        if (len < 0) {
    //            LoggerStream(0, @"decode subtitle error, skip packet");
    //            break;
    //        }
    //
    //        if (gotsubtitle) {
    //
    //            KxSubtitleFrame *frame = [self handleSubtitle: &subtitle];
    //            if (frame) {
    //                [result addObject:frame];
    //            }
    //            avsubtitle_free(&subtitle);
    //        }
    //
    //        if (0 == len)
    //            break;
    //
    //        pktSize -= len;
    //    }
    return nil;
    
}

-(HLAVFrameSubtitle *)handleSubtitleFrame:(AVFrame *)packet;
{
    return nil;
}
-(HLAVFrameArtwork *)handleArtworkFrame:(AVFrame *)packet;
{
    return nil;
}
-(HLAVFrameArtwork *)handleArtworkPacket:(AVPacket *)packet;
{
    //    if (packet.size) {
    //
    //        KxArtworkFrame *frame = [[KxArtworkFrame alloc] init];
    //        frame.picture = [NSData dataWithBytes:packet.data length:packet.size];
    //        [result addObject:frame];
    //    }
    return nil;
}

//action
- (void) seek:(double)position;
{
    //    _position = seconds;
    //    _isEOF = NO;
    //
    //    if (_videoStream != -1) {
    //        int64_t ts = (int64_t)(seconds / _videoTimeBase);
    //        avformat_seek_file(_formatCtx, _videoStream, ts, ts, ts, AVSEEK_FLAG_FRAME);
    //        avcodec_flush_buffers(_videoCodecCtx);
    //    }
    //
    //    if (_audioStream != -1) {
    //        int64_t ts = (int64_t)(seconds / _audioTimeBase);
    //        avformat_seek_file(_formatCtx, _audioStream, ts, ts, ts, AVSEEK_FLAG_FRAME);
    //        avcodec_flush_buffers(_audioCodecCtx);
    //    }
}




@end
