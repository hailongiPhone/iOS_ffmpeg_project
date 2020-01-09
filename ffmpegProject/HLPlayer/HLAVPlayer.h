//
//  HLAVPlayer.h
//  ffmpegProject
//
//  Created by hailong on 2020/01/07.
//  Copyright © 2020 HL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 *  协调decode界面 和界面渲染相关的操作
 *              decode和RenderView之间有像素格式的关联问题
 *                 这里面涉及多线程，生产者消费者问题，
 *                 缓存多少帧合适--解码多少帧作为缓存合适
 *
 *                 输入：文件url + 指定输出UIView
 *                 输出：把RenderView加到UIView中去
 *
 *                 还是参考AVplayer 与 AVPlayerLayer的关系来做
 */
NS_ASSUME_NONNULL_BEGIN

@protocol HLAVPlayerProtocol <NSObject>


- (void)setupOutputView:(UIView *)outupView;

- (void)open:(NSString *)url;
- (void)close;
- (void)play;
- (void)pause;
- (void)seek:(double)position;

@property (nonatomic) double minBufferDuration;
@property (nonatomic) double maxBufferDuration;
@property (nonatomic) double position;
@property (nonatomic) double duration;
@property (nonatomic) BOOL opened;
@property (nonatomic) BOOL playing;
@property (nonatomic) BOOL buffering;
@property (nonatomic, strong) NSDictionary *metadata;


@end

@interface HLAVPlayer : NSObject <HLAVPlayerProtocol>

- (void)setupOutputView:(UIView *)outupView;

- (void)open:(NSString *)url;
- (void)close;
- (void)play;
- (void)pause;
- (void)seek:(double)position;

@property (nonatomic) double minBufferDuration;
@property (nonatomic) double maxBufferDuration;
@property (nonatomic) double position;
@property (nonatomic) double duration;
@property (nonatomic) BOOL opened;
@property (nonatomic) BOOL playing;
@property (nonatomic) BOOL buffering;
@property (nonatomic, strong) NSDictionary *metadata;

@end

NS_ASSUME_NONNULL_END
