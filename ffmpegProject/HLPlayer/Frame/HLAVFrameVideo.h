//
//  HLAVFrameViedeo.h
//  ffmpegProject
//
//  Created by hailong on 2019/12/31.
//  Copyright © 2019 HL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HLAVFrame.h"

NS_ASSUME_NONNULL_BEGIN

@interface HLAVFrameVideo : HLAVFrame

@property (nonatomic) NSData *data;

@property (nonatomic) NSInteger width;
@property (nonatomic) NSInteger height;


- (instancetype) init;

@end

@interface HLAVFrameVideoRGB : HLAVFrameVideo
@property (nonatomic) NSUInteger linesize;
@property (nonatomic) BOOL hasAlpha;
@end

@interface HLAVFrameVideoYUV : HLAVFrameVideo
@property (nonatomic, strong) NSData *luma;    
@property (nonatomic, strong) NSData *chromaBlue;
@property (nonatomic, strong) NSData *chromaRed;
@end


NS_ASSUME_NONNULL_END
