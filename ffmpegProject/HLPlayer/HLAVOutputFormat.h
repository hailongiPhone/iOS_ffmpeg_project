//
//  HLAVOutputFormat.h
//  ffmpegProject
//
//  Created by hailong on 2020/01/06.
//  Copyright © 2020 HL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "HLAVHeader.h"

NS_ASSUME_NONNULL_BEGIN

@interface HLAVOutputFormat : NSObject


@property (nonatomic,assign) HLAVFrameVideoFormat videoFormat;

//默认为0 暂时没有使用
@property (nonatomic,assign) NSInteger width;
@property (nonatomic,assign) NSInteger height;

//声音 默认 采样率44100 声道2
@property (nonatomic,assign) CGFloat sampleRate;
@property (nonatomic,assign) NSInteger channels;

+ (instancetype)defaultFormat;
@end

NS_ASSUME_NONNULL_END
