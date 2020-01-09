//
//  HLFFmpegHelper.m
//  ffmpegProject
//
//  Created by hailong on 2020/01/02.
//  Copyright © 2020 HL. All rights reserved.
//

#import "HLFFmpegHelper.h"

@implementation HLFFmpegHelper
#pragma mark -
+ (AVFormatContext *)openInput:(NSString *)filename;
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

+ (AVFormatContext *)createOutputFormatContext:(NSString *)outputfilename;
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

+ (void)setupOutPutFormat:(AVFormatContext *)o_fmtctx with:(AVFormatContext *)i_fmtctx justType:(enum AVMediaType) justType;
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

+ (void)copyAllFrom:(AVFormatContext *)i_fmtctx to:(AVFormatContext *)o_fmtctx justType:(enum AVMediaType) justType;
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


+(NSArray<NSNumber *> *) allStreamsWithType:(enum AVMediaType )codecType InFormatContext:(AVFormatContext *)formatCtx;
{
    AVStream *stream = NULL;
    
    NSMutableArray *ma = [NSMutableArray array];
    for (NSInteger i = 0; i < formatCtx->nb_streams; ++i){
        stream = formatCtx->streams[i];
        if (codecType == stream->codecpar->codec_type)
            [ma addObject: [NSNumber numberWithInteger: i]];
    }
    
    return [ma copy];
}

+(NSInteger) bestStreamIndexWithType:(enum AVMediaType )codecType InFormatContext:(AVFormatContext *)formatCtx;
{
    return av_find_best_stream(formatCtx, codecType, -1, -1, NULL, 0);
}

//- (int)findVideoStream:(AVFormatContext *)fmtctx context:(AVCodecContext **)context pictureStream:(int *)pictureStream {
//    int stream = -1;
//    for (int i = 0; i < fmtctx->nb_streams; ++i) {
//        if (fmtctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
//            int disposition = fmtctx->streams[i]->disposition;
//            if ((disposition & AV_DISPOSITION_ATTACHED_PIC) == 0) { // Not attached picture
//                AVCodecContext *codectx = [self openVideoCodec:fmtctx stream:i];
//                if (codectx != NULL) {
//                    if (context != NULL) *context = codectx;
//                    stream = i;
//                    break;
//                }
//            } else {
//                if (pictureStream != NULL) *pictureStream = i;
//            }
//        }
//    }
//    return stream;
//}
//
//- (int)findAudioStream:(AVFormatContext *)fmtctx context:(AVCodecContext **)context;
//{
//    int stream = -1;
//    for (int i = 0; i < fmtctx->nb_streams; ++i) {
//        if (fmtctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
//            AVCodecContext *codectx = [self openAudioCodec:fmtctx stream:i];
//            if (codectx != NULL) {
//                if (context != NULL) *context = codectx;
//                stream = i;
//                break;
//            }
//        }
//    }
//    return stream;
//}

//在fmt_ctx 找到type指定的类型stream，保存stream_idx，并初始化解码器上下文AVCodecContext
+ (AVCodecContext *) loadCodecFor:(AVFormatContext *)fmtctx streamIndex:(NSInteger)streamIndex;
{
    if (streamIndex < 0 || streamIndex >= fmtctx->nb_streams ) {
        return NULL;
    }
    
    AVStream *st;
    AVCodec *dec = NULL;
    AVDictionary *opts = NULL;
    AVCodecContext *dec_ctx = NULL;
    int ret = 0;
    st = fmtctx->streams[streamIndex];
    
    /* find decoder for the stream */
    dec = avcodec_find_decoder(st->codecpar->codec_id);
    if (!dec) {
        fprintf(stderr, "Failed to find codec\n");
        return NULL;
    }
    
    /* Allocate a codec context for the decoder */
    dec_ctx = avcodec_alloc_context3(dec);
    if (!dec_ctx) {
        fprintf(stderr, "Failed to allocate the codec context\n");
        return NULL;
    }
    
    /* Copy codec parameters from input stream to output codec context */
    if ((ret = avcodec_parameters_to_context(dec_ctx, st->codecpar)) < 0) {
        fprintf(stderr, "Failed to copy  codec parameters to decoder context\n");
        return NULL;
    }
    
    /* Init the decoders, with or without reference counting */
    //        av_dict_set(&opts, "refcounted_frames", refcount ? "1" : "0", 0);
    av_dict_set(&opts, "refcounted_frames", "1",0);
    if ((ret = avcodec_open2(dec_ctx, dec, &opts)) < 0) {
        fprintf(stderr, "Failed to open codec\n");
        return NULL;
    }
    
    return dec_ctx;
}

+ (UIImage *)imageFromAVPicture:(AVFrame*)imageFrame width:(int)width height:(int)height {
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


+ (float)calculateSclaeSize:(CGSize)original dest:(CGSize)dest;
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


//信息读取
+ (NSData *)dataFromVideoFrame:(UInt8 *)data linesize:(int)linesize width:(int)width height:(int)height;
{
//    width = MIN(linesize, width);
    CFDataRef dataref= CFDataCreate(kCFAllocatorDefault,
    data,
   linesize * height);
    NSData * dataaaa = (NSData *)CFBridgingRelease(dataref);
    return dataaaa;
}

//timebase
//static void avStreamFPSTimeBase(AVStream *st, CGFloat defaultTimeBase, CGFloat *pFPS, CGFloat *pTimeBase)
//{
//    CGFloat fps, timebase;
//
//    // ffmpeg提供了一个把AVRatioal结构转换成double的函数
//    // 默认0.04 意思就是25帧
//    if (st->time_base.den && st->time_base.num)
//        timebase = av_q2d(st->time_base);
//    else if(st->codec->time_base.den && st->codec->time_base.num)
//        timebase = av_q2d(st->codec->time_base);
//    else
//        timebase = defaultTimeBase;
//
//    if (st->codec->ticks_per_frame != 1) {
//    }
//
//    // 平均帧率
//    if (st->avg_frame_rate.den && st->avg_frame_rate.num)
//        fps = av_q2d(st->avg_frame_rate);
//    else if (st->r_frame_rate.den && st->r_frame_rate.num)
//        fps = av_q2d(st->r_frame_rate);
//    else
//        fps = 1.0 / timebase;
//
//    if (pFPS)
//        *pFPS = fps;
//    if (pTimeBase)
//        *pTimeBase = timebase;
//}


+ (void)stream:(AVStream *)stream fps:(double *)fps timebase:(double *)timebase default:(double)defaultTimebase;
{
    double f = 0, t = 0;
    if (stream->time_base.den > 0 && stream->time_base.num > 0) {
        t = av_q2d(stream->time_base);
    } else {
        t = defaultTimebase;
    }
    
    if (stream->avg_frame_rate.den > 0 && stream->avg_frame_rate.num) {
        f = av_q2d(stream->avg_frame_rate);
    } else if (stream->r_frame_rate.den > 0 && stream->r_frame_rate.num > 0) {
        f = av_q2d(stream->r_frame_rate);
    } else {
        f = 1 / t;
    }
    
    if (fps != NULL) *fps = f;
    if (timebase != NULL) *timebase = t;
}

+ (double)rotationFromVideoStream:(AVStream *)stream;
{
    double rotation = 0;
    AVDictionaryEntry *entry = av_dict_get(stream->metadata, "rotate", NULL, AV_DICT_MATCH_CASE);
    if (entry && entry->value) { rotation = av_strtod(entry->value, NULL); }
    uint8_t *display_matrix = av_stream_get_side_data(stream, AV_PKT_DATA_DISPLAYMATRIX, NULL);
    if (display_matrix) { rotation = -av_display_rotation_get((int32_t *)display_matrix); }
    return rotation;
}


+ (UIImage *)imageFromAVFrame:(AVFrame *)pFrame video_dec_ctx:(AVCodecContext *)video_dec_ctx outputHeight:(int)outputHeight outputWidth:(int)outputWidth {
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

@end



