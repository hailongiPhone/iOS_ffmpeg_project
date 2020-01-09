//
//  HLAVPlayer.m
//  ffmpegProject
//
//  Created by hailong on 2020/01/07.
//  Copyright © 2020 HL. All rights reserved.
//

#import "HLAVPlayer.h"
#import "HLAVHeader.h"
#import "HLAVDecoder.h"
#import "HLAVRenderView.h"
#import "HLAVDecoderOutput.h"
#import "HLAudioPlayer.h"




@interface HLAVPlayer () <HLAudioPlayerDelegate>
{
    dispatch_queue_t _dispatchQueue;
}

@property(nonatomic, assign) BOOL decoding;
@property(nonatomic, strong) HLAVDecoder * decoder;
@property(nonatomic, strong) HLAVRenderView * renderView;
@property(nonatomic, strong) UIView * outputView;

@property(nonatomic, strong) HLAudioPlayer * audioplayer;

//一次要求的数据，可能是1帧多的数据，makeupPosition记录在后一帧里的位置
@property(nonatomic, assign) NSUInteger makeupPosition;
@property(nonatomic, strong) HLAVFrameAudio * makeupFrame;

//解码后的数据
@property (nonatomic,strong)HLAVDecoderOutput * cacheFrame;

- (void)setupDecoderAndRenderView:(HLAVFrameVideoFormat) format;

//刷新问题
@property (nonatomic,strong)CADisplayLink * displayLink;
@end

@implementation HLAVPlayer

#pragma mark - Interface

- (void)open:(NSString *)url;
{
//    SString * docsdir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
//    NSString * output_nsstr = [docsdir stringByAppendingPathComponent:@"remux.mp4"];
    
    if (self.decoder) {
        [self.decoder openFile:url error:nil];
    }
    
}
- (void)close;
{
    if (self.decoder) {
        [self.decoder closeFile];
    }
}

- (void)play;
{
    [self startTimer];
    
    self.playing = YES;
    [self asyncDecodeFrames];
    [self playAudio];
}

- (void)pause;
{
    self.playing = NO;
    [self stopTiemr];
    
    [self pauseAudio];
    
}

- (void)seek:(double)position;
{
    
}

- (void)setupOutputView:(UIView *)outupView;
{
    self.outputView = outupView;
    [self.outputView addSubview:self.renderView];
}
#pragma mark - LifeCycle

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setupQueue];
        [self setupDecoderAndRenderView:HLAVFrameVideoFormatRGB];
        [self setupAudioPlayer];
        [self startTimer];
        
        [self setupFrameCache];
        
    }
    return self;
}



//decoder和RenderView像素格式要保持一致
- (void)setupDecoderAndRenderView:(HLAVFrameVideoFormat) format;
{
    self.decoder = [HLAVDecoder new];
    self.renderView = [[HLAVRenderView alloc] initWithFrame:CGRectMake(0, 0, 100, 50)];
    
}

#pragma mark - 同步问题
- (void) startTimer;
{
    [self stopTiemr];
    // 初始化
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(timerCallback:)];
    // 设置 - 2桢回调一次，这里非时间，而是以桢为单位
//    self.displayLink.frameInterval = 2; //iOS10之前
    self.displayLink.preferredFramesPerSecond = 30; //iOS10及之后

    // 加入RunLoop
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void) stopTiemr;
{
    // 暂停
    self.displayLink.paused = YES;
    // 销毁
    [self.displayLink invalidate];
    self.displayLink = nil;
}
- (void) timerCallback:(CADisplayLink *)displayLink;
{
    if (!self.playing) {
        return;
    }

    //已经读取完毕
    if ([self hasDecodeEnd]) {
        [self pause];
        return;
    }
    
    
    
    if (self.cacheFrame.maxDuration < self.minBufferDuration) {
        [self asyncDecodeFrames];
    }
    
    HLAVFrameVideo * frame = [self consumerVideoFrame];
    
    [self.renderView render:frame];
}

#pragma mark - 线程相关
- (void) setupQueue;
{
    _dispatchQueue  = dispatch_queue_create("KxMovie", DISPATCH_QUEUE_SERIAL);
}

- (void) asyncDecodeFrames
{
    if (self.decoding || self.decoder.isEOF)
        return;
    
    __weak typeof(self) weakSelf = self;
    __weak typeof(_decoder) weakDecoder = self.decoder;
    
    
    self.decoding = YES;
    dispatch_async(_dispatchQueue, ^{
        
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf.playing)
            return;
        BOOL good = YES;
        while (good) {
            
            good = NO;
            
            @autoreleasepool {
                
                __strong typeof(weakDecoder) decoder = weakDecoder;
                
                if (decoder) {
                    
                    HLAVDecoderOutput *decoderOutput = [decoder decodeFrames:strongSelf.minBufferDuration];
                    [strongSelf producerFrame:decoderOutput];
                    NSLog(@"产生音乐信息");
                }
            }
        }
                
        weakSelf.decoding = NO;
    });
}

#pragma mark - Cache Frame

- (void) setupFrameCache;
{
    self.cacheFrame = [HLAVDecoderOutput new];
    self.minBufferDuration = 0.2;
    self.maxBufferDuration = 0.4;
}

- (void) producerFrame:( HLAVDecoderOutput *) decoderOutput;
{
    @synchronized (self.cacheFrame) {
        [self.cacheFrame addOutput:decoderOutput];
    }
}

- (HLAVFrameVideo *)consumerVideoFrame;
{
    HLAVFrameVideo * frame ;
    @synchronized (self.cacheFrame) {
        frame = [self.cacheFrame consumerVideoFrame];
    }
    
    return frame;
}

- (HLAVFrameAudio *)consumerAudioFrame;
{
    HLAVFrameAudio * frame ;
    @synchronized (self.cacheFrame) {
        frame = [self.cacheFrame consumerAudioFrame];
    }
    
    return frame;
}


#pragma mark - 时间长度等判断
- (BOOL) hasDecodeEnd;
{
    if (!self.decoder) {
        return YES;
    }
    return self.decoder.isEOF;
}


#pragma mark - audio

- (void) setupAudioPlayer;
{
    self.audioplayer = [HLAudioPlayer new];
    self.audioplayer.rate = 1.0;
    self.audioplayer.pitch = 0.0;
    self.audioplayer.volume = 1.0;
    
    self.audioplayer.delegate = self;
}

- (void) playAudio;
{
    [self.audioplayer play];
}

- (void) pauseAudio;
{
    [self.audioplayer pause];
}

//这里返回给硬件需要的帧数
- (NSInteger) fillAudioData:(float*) sampleBuffer
                  numFrames:(NSInteger)numberOfFrames
                numChannels:(NSInteger)channels;
{
    NSLog(@"audioPlayer");
    
    if (!self.playing) return 0;
    
    const NSUInteger frameSize = channels * sizeof(float);
    
    while(numberOfFrames > 0) {
        @autoreleasepool {
            if (!self.makeupFrame) {
                self.makeupFrame = [self consumerAudioFrame];
                self.makeupPosition = 0;
            }
            
            NSData *frameData = self.makeupFrame.data;
            NSInteger channels = [self.decoder.outputFormat channels];
            
            if (frameData == nil) {
                //实在没数据就0
                NSLog(@"读取声音信息失败");
                memset(sampleBuffer, 0, numberOfFrames * frameSize * sizeof(float));
                return 0;
            }
            
            
            //makeup位置计算
            const void *bytes = (Byte *)frameData.bytes + self.makeupPosition;
            const NSUInteger remainingBytesInFrame = frameData.length - self.makeupPosition;
            
            //参考好像没有* channels  -- 注意每次循环是有更新大小的 numberOfFrames sampleBuffer
            const NSUInteger requireBytesToCopy = numberOfFrames * frameSize;
            
            const NSUInteger bytesToCopy = MIN(requireBytesToCopy, remainingBytesInFrame);
            const NSUInteger framesToCopy = bytesToCopy / frameSize;
    

            memcpy(sampleBuffer, bytes, bytesToCopy);
            
            //每次循环是有更新大小的 numberOfFrames 数据保存的位置sampleBuffer
            numberOfFrames -= framesToCopy;
            sampleBuffer += framesToCopy * channels;

            if (bytesToCopy < remainingBytesInFrame) {
                self.makeupPosition += bytesToCopy;
            } else {
                self.makeupFrame = nil;
                self.makeupPosition = 0;
            }
        }
    }
    
    return 0;
}

- (void)audioPlayer:(HLAudioPlayer *)player
         willRender:(const AudioTimeStamp *)timestamp;
{
    NSLog(@"willRender  timestamp");
}

- (void)audioPlayer:(HLAudioPlayer *)player
          didRender:(const AudioTimeStamp *)timestamp;
{
    NSLog(@" didRender timestamp");
}
@end