//
//  HLAVFrameAudio.h
//  ffmpegProject
//
//  Created by hailong on 2019/12/31.
//  Copyright © 2019 HL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HLAVFrame.h"

NS_ASSUME_NONNULL_BEGIN

@interface HLAVFrameAudio : HLAVFrame

@property (nonatomic) NSData *data;

- (instancetype) init;
@end

NS_ASSUME_NONNULL_END
