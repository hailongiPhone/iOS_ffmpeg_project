//
//  HLAVOutputFormat.m
//  ffmpegProject
//
//  Created by hailong on 2020/01/06.
//  Copyright © 2020 HL. All rights reserved.
//

#import "HLAVOutputFormat.h"

@implementation HLAVOutputFormat

+ (instancetype)defaultFormat;
{
    HLAVOutputFormat * tmp = [HLAVOutputFormat new];
    tmp.videoFormat = HLAVFrameVideoFormatRGB;
    tmp.sampleRate = 44100;
    tmp.channels = 2;
    return tmp;
}
@end
