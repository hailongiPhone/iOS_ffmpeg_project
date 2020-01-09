//
//  HLAVRenderView.h
//  ffmpegProject
//
//  Created by hailong on 2020/01/06.
//  Copyright © 2020 HL. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HLAVDecoder.h"
#import "HLAVFrameVideo.h"

NS_ASSUME_NONNULL_BEGIN

@interface HLAVRenderView : UIView

- (instancetype) init;
- (instancetype) initWithCoder:(NSCoder *)coder;
- (instancetype) initWithFrame:(CGRect)frame;

- (instancetype) initWithFrame:(CGRect)frame
             decoder: (HLAVDecoder *) decoder;

- (void) render: (HLAVFrameVideo *) frame;
@end

NS_ASSUME_NONNULL_END
