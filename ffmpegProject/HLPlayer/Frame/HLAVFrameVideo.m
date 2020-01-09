//
//  HLAVFrameViedeo.m
//  ffmpegProject
//
//  Created by hailong on 2019/12/31.
//  Copyright © 2019 HL. All rights reserved.
//

#import "HLAVFrameVideo.h"

@implementation HLAVFrameVideo

- (instancetype) init;
{
    self = [super init];
    if (self) {
        self.type = HLAVFrameTypeVideo;
    }
    return self;
}

@end

@implementation HLAVFrameVideoRGB

@end

@implementation HLAVFrameVideoYUV

@end
