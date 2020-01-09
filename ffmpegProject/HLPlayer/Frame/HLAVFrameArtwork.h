//
//  HLAVFrameArtwork.h
//  ffmpegProject
//
//  Created by hailong on 2020/01/02.
//  Copyright © 2020 HL. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "HLAVFrame.h"

NS_ASSUME_NONNULL_BEGIN

@interface HLAVFrameArtwork : HLAVFrame
@property (nonatomic, strong) NSData *data;
- (nullable UIImage *) asImage;
@end

NS_ASSUME_NONNULL_END
