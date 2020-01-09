//
//  HLAVFrame.h
//  ffmpegProject
//
//  Created by hailong on 2019/12/31.
//  Copyright © 2019 HL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HLAVFrame.h"
#import "HLAVHeader.h"

NS_ASSUME_NONNULL_BEGIN



@protocol HLAVFrameProtocol <NSObject>

@property (nonatomic) HLAVFrameType type;
@property (nonatomic) double position;
@property (nonatomic) double duration;

@end

@interface HLAVFrame: NSObject <HLAVFrameProtocol>

@property (nonatomic) HLAVFrameType type;
@property (nonatomic) double position;
@property (nonatomic) double duration;

@end

NS_ASSUME_NONNULL_END
