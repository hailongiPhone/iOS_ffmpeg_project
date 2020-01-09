//
//  ViewController.m
//  ffmpegProject
//
//  Created by hailong on 2019/12/20.
//  Copyright © 2019 HL. All rights reserved.
//

#import "ViewController.h"
#import "HLVideoHelper.h"

#import "HLAVRenderView.h"
#import "HLAVDecoder.h"
#import "HLAVPlayer.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()
@property (nonatomic,strong)HLVideoHelper * videoHelper;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewSnapshot;
@property (weak, nonatomic) IBOutlet HLAVRenderView *renderView;


@property (nonatomic,strong)HLAVDecoder * decoder;

@property (nonatomic,strong)NSArray * avframes;
@property (nonatomic,assign)NSInteger avframeIndex;
@property (nonatomic,strong)CADisplayLink * displayLink;

@property (nonatomic,strong) HLAVPlayer* player;
@property (weak, nonatomic) IBOutlet UIView *outputView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.videoHelper = [HLVideoHelper new];
}
- (IBAction)onTapAction:(id)sender {
    
    [self concat];
}

- (IBAction)onTapActionSnapshot:(id)sender {
    [self snapshot];
}


#pragma action
- (void)concat;
{
    NSString * docsdir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString * output_nsstr = [docsdir stringByAppendingPathComponent:@"concat.mp4"];
    
    int count = 4;
    NSMutableArray * inputs = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i< count; i++) {
        NSString * ats = [NSString stringWithFormat:@"tsinput%d.ts",i];
        NSString *input_nsstr=[[NSBundle mainBundle] pathForResource:ats ofType:nil];
        [inputs addObject:input_nsstr];
    }
    
    [self.videoHelper mixAllFile:inputs to:output_nsstr];
}

- (void)remux;
{
    NSString * docsdir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString * output_nsstr = [docsdir stringByAppendingPathComponent:@"remux.mp4"];
    
    NSString *input_nsstr=[[NSBundle mainBundle] pathForResource:@"output0.ts" ofType:nil];
    
    [self.videoHelper changeRemux:input_nsstr to:output_nsstr];
}

- (void)justAudio;
{
    NSString * docsdir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString * output_nsstr = [docsdir stringByAppendingPathComponent:@"justAudio.m4a"];
    
    NSMutableArray * inputs = [NSMutableArray arrayWithCapacity:20];
    for (int i = 0; i< 20; i++) {
        NSString * ats = [NSString stringWithFormat:@"output%d.ts",i];
        NSString *input_nsstr=[[NSBundle mainBundle] pathForResource:ats ofType:nil];
        [inputs addObject:input_nsstr];
    }
    
    [self.videoHelper justAudio:inputs to:output_nsstr];
}

- (void) snapshot;
{
    NSString *input_nsstr=[[NSBundle mainBundle] pathForResource:@"1.mp4" ofType:nil];
    
    UIImage * image = [self.videoHelper thumbnailImageOfVideo:input_nsstr thumbnailFrameIndex:30 size:CGSizeMake(100, 50)];
    self.imageViewSnapshot.image = image;
    [self.imageViewSnapshot sizeToFit];
}

#pragma mark - Play

- (IBAction)onTapPlayButton:(id)sender {
    
//    NSString * docsdir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
//    NSString * input_nsstr = [docsdir stringByAppendingPathComponent:@"remux.mp4"];
    NSString *input_nsstr=[[NSBundle mainBundle] pathForResource:@"1.mp4" ofType:nil];
    self.decoder = [HLAVDecoder new];
    [self.decoder openFile:input_nsstr error:nil];

//    NSArray * arr = [self.decoder decodeFrames:0.04];
//    @synchronized (self.avframes) {
//        self.avframes = arr;
//        self.avframeIndex = 0;
//    }
//    [self startTimer];
    
}

- (void) startTimer;
{
    [self stopTiemr];
    // 初始化
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(timerCallback:)];
    // 设置 - 2桢回调一次，这里非时间，而是以桢为单位
//    self.displayLink.frameInterval = 2; //iOS10之前
    self.displayLink.preferredFramesPerSecond = 25; //iOS10及之后

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
    HLAVLog(@"displayLink.duration = %ld ; displayLink.frameInterval = %ld",displayLink.duration , displayLink.preferredFramesPerSecond);
    HLAVFrameVideo * frame;
    @synchronized (self.avframes) {
        if (!self.avframes || [self.avframes count] < 1) {
            return;
        }
        if (self.avframeIndex >= [self.avframes count]) {
            self.avframeIndex = 0;
        }
        frame = [self.avframes objectAtIndex:self.avframeIndex];
        self.avframeIndex++;
    }
    [self.renderView render:frame];
}

- (IBAction)onTapButtonPlayer:(id)sender {
    
//    NSString * docsdir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
//    NSString * output_nsstr = [docsdir stringByAppendingPathComponent:@"remux.mp4"];
    NSString *output_nsstr=[[NSBundle mainBundle] pathForResource:@"1.mp4" ofType:nil];
    self.player = [HLAVPlayer new];
    [self.player setupOutputView:self.outputView];
    [self.player open:output_nsstr];
    [self.player play];
}
- (IBAction)onTapButtonStop:(id)sender {
    [self.player pause];
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSLog(@"session samplerate = %@, volume = %f",@(session.sampleRate),session.outputVolume);
}

@end
