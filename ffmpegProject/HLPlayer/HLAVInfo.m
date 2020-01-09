//
//  HLAVInfo.m
//  ffmpegProject
//
//  Created by hailong on 2020/01/02.
//  Copyright © 2020 HL. All rights reserved.
//

#import "HLAVInfo.h"

@implementation HLAVInfo

-(instancetype) init
{
    self = [super init];
    if (self) {
        self.artworkStream = HLAVNoStream;
        self.selectedSubtitleStream = HLAVNoStream;
        self.selectedAudioStream = HLAVNoStream;
    }
    
    return self;
}

- (BOOL) hasArtwork{
    return self.artworkStream != HLAVNoStream;
}

- (BOOL) hasAudioStream{
    return self.selectedAudioStream != HLAVNoStream;
}

- (BOOL) hasVideoStream{
    return self.videoStream != HLAVNoStream;
}

- (BOOL) hasSubtitleStream{
    return self.selectedSubtitleStream != HLAVNoStream;
}

@end
