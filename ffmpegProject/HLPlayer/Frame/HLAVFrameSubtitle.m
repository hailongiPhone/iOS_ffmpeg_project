//
//  HLAVFrameSubtitle.m
//  ffmpegProject
//
//  Created by hailong on 2020/01/02.
//  Copyright © 2020 HL. All rights reserved.
//

#import "HLAVFrameSubtitle.h"

@implementation HLAVFrameSubtitle
- (instancetype) init;
{
    self = [super init];
    if (self) {
        self.type = HLAVFrameTypeSubtitle;
    }
    return self;
}

@end


