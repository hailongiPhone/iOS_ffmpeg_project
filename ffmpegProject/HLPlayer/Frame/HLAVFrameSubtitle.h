//
//  HLAVFrameSubtitle.h
//  ffmpegProject
//
//  Created by hailong on 2020/01/02.
//  Copyright © 2020 HL. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "HLAVFrame.h"

NS_ASSUME_NONNULL_BEGIN

@interface HLAVFrameSubtitle :HLAVFrame
@property (readonly, nonatomic, strong) NSString *text;
@end

NS_ASSUME_NONNULL_END
