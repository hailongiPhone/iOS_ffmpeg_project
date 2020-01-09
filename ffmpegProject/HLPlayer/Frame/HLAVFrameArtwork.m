//
//  HLAVFrameArtwork.m
//  ffmpegProject
//
//  Created by hailong on 2020/01/02.
//  Copyright © 2020 HL. All rights reserved.
//

#import "HLAVFrameArtwork.h"

@implementation HLAVFrameArtwork
- (instancetype) init;
{
    self = [super init];
    if (self) {
        self.type = HLAVFrameTypeSubtitle;
    }
    return self;
}

- (UIImage *) asImage;
{
    return nil;
}
@end
