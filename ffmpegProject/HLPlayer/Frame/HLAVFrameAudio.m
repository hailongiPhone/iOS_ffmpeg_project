//
//  HLAVFrameAudio.m
//  ffmpegProject
//
//  Created by hailong on 2019/12/31.
//  Copyright © 2019 HL. All rights reserved.
//

#import "HLAVFrameAudio.h"

@implementation HLAVFrameAudio
- (instancetype) init;
{
    self = [super init];
    if (self) {
        self.type = HLAVFrameTypeAudio;
    }
    return self;
}
@end
