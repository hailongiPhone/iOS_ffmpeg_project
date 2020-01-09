//
//  HLVideoHelper.m
//  ffmpegProject
//
//  Created by hailong on 2019/12/20.
//  Copyright © 2019 HL. All rights reserved.
//

#import "HLVideoHelper.h"

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>

//4.2
@interface HLVideoHelper ()
- (AVFormatContext *)openInput:(NSString *)filename;
- (AVFormatContext *)createOutputFormatContext:(NSString *)outputfilename;
- (void)setupOutPutFormat:(AVFormatContext *)o_fmtctx with:(AVFormatContext *)i_fmtctx justType:(enum AVMediaType) justType;
- (void)copyAllFrom:(AVFormatContext *)i_fmtctx to:(AVFormatContext *)o_fmtctx justType:(enum AVMediaType) justType;

- (float)calculateSclaeSize:(CGSize)original dest:(CGSize)dest;
- (UIImage *)imageFromAVPicture:(AVFrame *)imageFrame width:(int)width height:(int)height;
@end

@implementation HLVideoHelper

#pragma mark -
- (AVFormatContext *)openInput:(NSString *)filename;
{
    char input_str_full[500]={0};
    sprintf(input_str_full,"%s",[filename UTF8String]);
    AVFormatContext *input_fmtctx = NULL;
    if (avformat_open_input(&input_fmtctx, input_str_full, NULL, NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot open the file %s\n", input_str_full);
        return nil;
    }
    
    if (avformat_find_stream_info(input_fmtctx,0) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Failed to retrieve input stream information\n");
        return nil;
    }
    
    av_dump_format(input_fmtctx, 0, input_str_full, 0);
    
    
    return input_fmtctx;
}

- (AVFormatContext *)createOutputFormatContext:(NSString *)outputfilename;
{
    char output_str_full[500]={0};
    sprintf(output_str_full,"%s",[outputfilename UTF8String]);
    
    AVFormatContext *output_fmtctx = NULL;
    
    if (avformat_alloc_output_context2(&output_fmtctx, NULL, NULL, output_str_full) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot open the file %s\n", output_str_full);
        return nil;
    }
    
    if (avio_open(&output_fmtctx->pb, output_str_full, AVIO_FLAG_WRITE) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot open the output file '%s'\n", output_str_full);
        return nil;
    }
    
    return output_fmtctx;
}

- (void)setupOutPutFormat:(AVFormatContext *)o_fmtctx with:(AVFormatContext *)i_fmtctx justType:(enum AVMediaType) justType;
{
    int ret = 0;
    
    
    for (int i = 0; i < i_fmtctx->nb_streams; i++) {
        AVStream *out_stream = NULL;
        AVStream *in_stream = NULL;
        in_stream = i_fmtctx->streams[i];
        if (in_stream->codecpar->codec_type != AVMEDIA_TYPE_AUDIO &&
            in_stream->codecpar->codec_type != AVMEDIA_TYPE_VIDEO  &&
            in_stream->codecpar->codec_type != AVMEDIA_TYPE_SUBTITLE) {
            continue;
        }
        if (justType > 0 && justType != in_stream->codecpar->codec_type) {
            continue;
        }
        
        out_stream = avformat_new_stream(o_fmtctx, NULL);
        if (out_stream < 0) {
            av_log(NULL, AV_LOG_ERROR, "Alloc new Stream error\n");
            return ;
        }
        
        AVCodec *codec = avcodec_find_decoder(in_stream->codecpar->codec_id);
        AVCodecContext *codec_ctx = avcodec_alloc_context3(codec);
        ret = avcodec_parameters_to_context(codec_ctx, in_stream->codecpar);
        if (ret < 0){
            av_log(NULL, AV_LOG_ERROR,"Failed to copy in_stream codecpar to codec context\n");
            return;
        }
        
        
        
        //头信息存放位置问题，
        if (o_fmtctx->oformat->flags & AVFMT_GLOBALHEADER)
            codec_ctx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
        
        ret = avcodec_parameters_from_context(out_stream->codecpar, codec_ctx);
        
        out_stream->time_base = in_stream->time_base;
        out_stream->codecpar->codec_tag = 0;
        if (ret < 0){
            av_log(NULL, AV_LOG_ERROR,"Failed to copy codec context to out_stream codecpar context\n");
            return;
        }
        
    }
    av_dump_format(o_fmtctx, 0, o_fmtctx->url, 1);
    
    if ((ret = avformat_write_header(o_fmtctx, NULL)) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot write the header for the file  ret = %d\n", ret);
        return ;
    }
}

- (void)copyAllFrom:(AVFormatContext *)i_fmtctx to:(AVFormatContext *)o_fmtctx justType:(enum AVMediaType) justType;
{
    AVPacket pkt;
    av_init_packet(&pkt);
    pkt.data = NULL;
    pkt.size = 0;
    int ret = 0;
//    NSInteger dts = 0;
//    NSInteger fpts = 0;
    while (1) {
        AVStream *in_stream = NULL;
        AVStream *out_stream = NULL;
        
        ret = av_read_frame(i_fmtctx, &pkt);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Frame读取完毕 Read frame error %d\n", ret);
            break;
        }
        
        in_stream = i_fmtctx->streams[pkt.stream_index];
        
        if (justType > 0 && justType != in_stream->codecpar->codec_type) {
            continue;
        }
        
        
        if (in_stream->codecpar->codec_type != AVMEDIA_TYPE_AUDIO &&
            in_stream->codecpar->codec_type != AVMEDIA_TYPE_VIDEO  &&
            in_stream->codecpar->codec_type != AVMEDIA_TYPE_SUBTITLE) {
            continue;
        }
        out_stream = o_fmtctx->streams[pkt.stream_index];
        //        NSLog(@"pkt dts = %d",pkt.dts);
        //        NSLog(@"pkt pts = %d",pkt.pts);
        av_packet_rescale_ts(&pkt, in_stream->time_base, out_stream->time_base);
        //           pkt.pts = av_rescale_q_rnd(pkt.pts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX);
        //           pkt.dts = av_rescale_q_rnd(pkt.dts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX);
        //           pkt.duration = (int)av_rescale_q(pkt.duration, in_stream->time_base, out_stream->time_base);
        //           pkt.pos = -1;
        //        pkt.pts = pts;
        //        pkt.dts = dts;
        //        pts += pkt.duration;
        
//        dts = av_rescale_q_rnd(in_stream->start_time, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX);
//        fpts += av_rescale_q(pkt.duration, in_stream->time_base, out_stream->time_base);
        ////        pkt.dts -= fpts;
        //
        //
        //
//        pkt.pts -= in_stream->start_time;
        
        
        
        const AVBitStreamFilter * filter = NULL;
        if(in_stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO && in_stream->codecpar->codec_id == AV_CODEC_ID_H264){
            filter = av_bsf_get_by_name("h264_mp4toannexb");
        } else if(in_stream->codecpar->codec_id == AV_CODEC_ID_AAC) {
            filter = av_bsf_get_by_name("aac_adtstoasc");
        }
        if (filter != NULL) {
            AVBSFContext *  absCtx;
            ret = av_bsf_alloc(filter,&absCtx);
            if (ret < 0) {
                av_log(NULL, AV_LOG_ERROR, "aac_adtstoasc Error\n");
                break;
            }
            
            avcodec_parameters_copy(absCtx->par_in, in_stream->codecpar);
            absCtx->time_base_in = in_stream->time_base;
            av_bsf_init(absCtx);
            
            avcodec_parameters_copy(out_stream->codecpar, absCtx->par_out);
            
            
            if(av_bsf_send_packet(absCtx, &pkt) != 0){
                av_log(NULL, AV_LOG_ERROR, "av_bsf_send_packet Error\n");
                continue;
            }
            
            if(av_bsf_receive_packet(absCtx, &pkt) != 0){
                av_log(NULL, AV_LOG_ERROR, "av_bsf_receive_packet Error\n");
                continue;
            }
            
            
            if(av_write_frame(o_fmtctx, &pkt) != 0){
                av_log(NULL, AV_LOG_ERROR, "av_bsf_receive_packet Error\n");
                continue;
            }
            
            av_bsf_free(&absCtx);
            //            old
            //           AVBitStreamFilterContext* aacBitstreamFilterContext = av_bitstream_filter_init("aac_adtstoasc");
            //           av_bitstream_filter_filter(aacBitstreamFilterContext, out_stream->codec, NULL, &pkt.data, &pkt.size, pkt.data, pkt.size, 0);
        }else{
            ret = av_write_frame(o_fmtctx, &pkt);
            if (ret < 0) {
                av_log(NULL, AV_LOG_ERROR, "Muxing Error\n");
                break;
            }
        }
        
        
        
        av_packet_unref(&pkt);
    }
    
}

//在fmt_ctx 找到type指定的类型stream，保存stream_idx，并初始化解码器上下文AVCodecContext
static int open_codec_context(int *stream_idx,
                              AVCodecContext **dec_ctx, AVFormatContext *fmt_ctx, enum AVMediaType type)
{
    int ret, stream_index;
    AVStream *st;
    AVCodec *dec = NULL;
    AVDictionary *opts = NULL;
    
    ret = av_find_best_stream(fmt_ctx, type, -1, -1, NULL, 0);
    if (ret < 0) {
        fprintf(stderr, "Could not find %s stream in input file '%s'\n",
                av_get_media_type_string(type), fmt_ctx->url);
        return ret;
    } else {
        stream_index = ret;
        st = fmt_ctx->streams[stream_index];
        
        /* find decoder for the stream */
        dec = avcodec_find_decoder(st->codecpar->codec_id);
        if (!dec) {
            fprintf(stderr, "Failed to find %s codec\n",
                    av_get_media_type_string(type));
            return AVERROR(EINVAL);
        }
        
        /* Allocate a codec context for the decoder */
        *dec_ctx = avcodec_alloc_context3(dec);
        if (!*dec_ctx) {
            fprintf(stderr, "Failed to allocate the %s codec context\n",
                    av_get_media_type_string(type));
            return AVERROR(ENOMEM);
        }
        
        /* Copy codec parameters from input stream to output codec context */
        if ((ret = avcodec_parameters_to_context(*dec_ctx, st->codecpar)) < 0) {
            fprintf(stderr, "Failed to copy %s codec parameters to decoder context\n",
                    av_get_media_type_string(type));
            return ret;
        }
        
        /* Init the decoders, with or without reference counting */
        //        av_dict_set(&opts, "refcounted_frames", refcount ? "1" : "0", 0);
        av_dict_set(&opts, "refcounted_frames", "1",0);
        if ((ret = avcodec_open2(*dec_ctx, dec, &opts)) < 0) {
            fprintf(stderr, "Failed to open %s codec\n",
                    av_get_media_type_string(type));
            return ret;
        }
        *stream_idx = stream_index;
    }
    
    return 0;
}

#pragma mark -  interface

- (void) changeRemux:(NSString *)sender to:(NSString *)desFile;
{
    if (!sender || [sender length] < 1) {
        return;
    }
    
    if (!desFile || [desFile length] < 1) {
        return;
    }
    
    NSString *input_nsstr = sender;
    NSString * output_nsstr = desFile;//将需要创建的串拼接到后面
    
    //    av_register_all();
    
    AVFormatContext *input_fmtctx = [self openInput:input_nsstr];
    AVFormatContext *output_fmtctx =  [self createOutputFormatContext:output_nsstr];
    [self setupOutPutFormat:output_fmtctx with:input_fmtctx justType:-1];
    [self copyAllFrom:input_fmtctx to:output_fmtctx justType:-1];
    
    av_write_trailer(output_fmtctx);
    avio_close(output_fmtctx->pb);
    avformat_free_context(output_fmtctx);
    avformat_close_input(&input_fmtctx);
}

- (void) mixAllFile:(NSArray *)files to:(NSString *)desFile;
{
    if (!files || [files count] < 1) {
        return;
    }
    if (!desFile || [desFile length] < 1) {
        return;
    }
    
    
    NSString *input_nsstr= [files firstObject];
    NSString * output_nsstr = desFile;//将需要创建的串拼接到后面
    
    //    av_register_all();
    
    AVFormatContext *input_fmtctx = [self openInput:input_nsstr];
    AVFormatContext *output_fmtctx =  [self createOutputFormatContext:output_nsstr];
    [self setupOutPutFormat:output_fmtctx with:input_fmtctx justType:-1];
    [self copyAllFrom:input_fmtctx to:output_fmtctx justType:-1];
    
    NSInteger count = [files count];
    for (NSInteger i = 1 ; i < count ; i++) {
        NSString *input_nsstr= [files objectAtIndex:i];
        AVFormatContext *input_fmtctx = [self openInput:input_nsstr];
        [self copyAllFrom:input_fmtctx to:output_fmtctx justType:-1];
        avformat_close_input(&input_fmtctx);
    }
    
    av_write_trailer(output_fmtctx);
    avio_close(output_fmtctx->pb);
    avformat_free_context(output_fmtctx);
    avformat_close_input(&input_fmtctx);
    
}

- (void) justAudio:(NSArray *)files to:(NSString *)desFile;
{
    if (!files || [files count] < 1) {
        return;
    }
    if (!desFile || [desFile length] < 1) {
        return;
    }
    
    
    NSString *input_nsstr= [files firstObject];
    NSString * output_nsstr = desFile;//将需要创建的串拼接到后面
    
    //    av_register_all();
    
    AVFormatContext *input_fmtctx = [self openInput:input_nsstr];
    AVFormatContext *output_fmtctx =  [self createOutputFormatContext:output_nsstr];
    [self setupOutPutFormat:output_fmtctx with:input_fmtctx justType:-1];
    [self copyAllFrom:input_fmtctx to:output_fmtctx justType:AVMEDIA_TYPE_AUDIO];
    
    NSInteger count = [files count];
    for (NSInteger i = 1 ; i < count ; i++) {
        NSString *input_nsstr= [files objectAtIndex:i];
        AVFormatContext *input_fmtctx = [self openInput:input_nsstr];
        [self copyAllFrom:input_fmtctx to:output_fmtctx justType:AVMEDIA_TYPE_AUDIO];
        avformat_close_input(&input_fmtctx);
    }
    
    av_write_trailer(output_fmtctx);
    avio_close(output_fmtctx->pb);
    avformat_free_context(output_fmtctx);
    avformat_close_input(&input_fmtctx);
}

- (UIImage *)imageFromAVFrame:(AVFrame *)pFrame video_dec_ctx:(AVCodecContext *)video_dec_ctx outputHeight:(int)outputHeight outputWidth:(int)outputWidth {
    int ret = 0;
    UIImage * result;
    AVFrame *imageFrame = av_frame_alloc();
    ret = av_image_alloc(imageFrame->data, imageFrame->linesize, outputWidth, outputHeight, AV_PIX_FMT_RGB24, 1);
    if(ret < 0){
        av_frame_unref(imageFrame);
        return nil;
    }
    static int sws_flags =  SWS_FAST_BILINEAR;
    struct SwsContext * img_convert_ctx = sws_getContext(video_dec_ctx->width,
                                                         video_dec_ctx->height,
                                                         video_dec_ctx->pix_fmt,
                                                         outputWidth,
                                                         outputHeight,
                                                         AV_PIX_FMT_RGB24,
                                                         sws_flags, NULL, NULL, NULL);
    
    //转换RGBA
    sws_scale(img_convert_ctx,
              (void*)pFrame->data,
              pFrame->linesize,
              0,
              video_dec_ctx->height,
              imageFrame->data,
              imageFrame->linesize);
    sws_freeContext(img_convert_ctx);
    
    result = [self imageFromAVPicture:imageFrame width:outputWidth height:outputHeight];
    av_frame_unref(imageFrame);
    
    return result;
}

- (UIImage *) thumbnailImageOfVideo:(NSString *) videoPath
                thumbnailFrameIndex:(NSInteger)frameIndex
                               size:(CGSize)desSize;
{
    if (!videoPath) {
        return nil;
    }
    
    UIImage * result;
    
    int video_stream_idx;
    AVCodecContext *video_dec_ctx= NULL;
    
    
    AVFormatContext *input_fmtctx = [self openInput:videoPath];
    
    //加载解码器 上下文环境 stream idx
     if (open_codec_context(&video_stream_idx, &video_dec_ctx, input_fmtctx, AVMEDIA_TYPE_VIDEO) < 0) {
         goto initError;
     }
    
    AVPacket pkt;
    AVFrame * pFrame = av_frame_alloc();
    
    av_init_packet(&pkt);
    pkt.data = NULL;
    pkt.size = 0;
    int ret = 0;
    
    //seek
    int64_t targetFrame = frameIndex;
    avformat_seek_file(input_fmtctx, video_stream_idx, targetFrame, targetFrame, targetFrame, AVSEEK_FLAG_FRAME);
    avcodec_flush_buffers(video_dec_ctx);

    while (1 && !result) {
        
        ret = av_read_frame(input_fmtctx, &pkt);
        
        if (ret < 0 || pkt.stream_index != video_stream_idx ) {
            continue;
        }
        
        
        ret = avcodec_send_packet(video_dec_ctx, &pkt);
        while (ret >= 0) {
            ret = avcodec_receive_frame(video_dec_ctx, pFrame);
            if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF){
                continue;
            }else if (ret < 0) {
                fprintf(stderr, "Error during decoding\n");
                exit(1);
            }

            printf("saving frame %3d\n", video_dec_ctx->frame_number);
            
            int outputWidth = video_dec_ctx->width / 2;
            int outputHeight = video_dec_ctx->height / 2;
            float scale = [self calculateSclaeSize:CGSizeMake(outputWidth, outputHeight) dest:desSize];
            outputWidth *= scale;
            outputHeight *= scale;
            outputHeight = (outputHeight >> 4) << 4 ;
            outputWidth = (outputWidth >> 4) <<4 ;
            
            /* the picture is allocated by the decoder. no need to
               free it */
            //从AVFrame中读取颜色信息，
            result = [self imageFromAVFrame:pFrame video_dec_ctx:video_dec_ctx outputHeight:outputHeight outputWidth:outputWidth];
            
            
            
            break;
        }
    
    }
    
    
initError:
    av_frame_free(&pFrame);
    av_packet_unref(&pkt);

    avcodec_close(video_dec_ctx);
    avformat_close_input(&input_fmtctx);
    avformat_free_context(input_fmtctx);
    
    return result;
}

- (UIImage *)imageFromAVPicture:(AVFrame*)imageFrame width:(int)width height:(int)height {
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
//    //使用noCopy在释放picture时会奔溃
//    CFDataRef data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, pict.data[0], pict.linesize[0]*height,kCFAllocatorNull);
    CFDataRef data = CFDataCreate(kCFAllocatorDefault,
    imageFrame->data[0],
    imageFrame->linesize[0] * height);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(width,
                                       height,
                                       8,
                                       24,
                                       imageFrame->linesize[0],
                                       colorSpace,
                                       bitmapInfo,
                                       provider,
                                       NULL,
                                       NO,
                                       kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGDataProviderRelease(provider);
    CFRelease(data);
    
    return image;
}


- (float)calculateSclaeSize:(CGSize)original dest:(CGSize)dest;
{
    float scale = 1;
    if (CGSizeEqualToSize(original,dest)) {
        return scale;
    }
    
    //以高度优先缩放
    bool isHeight = YES;
    if(original.height < original.width){
        isHeight = NO;
    }
    
    if(isHeight){
        scale = dest.height / original.height;
    }else{
        scale = dest.width / original.width;
    }
    
    return scale;
    
}

@end
