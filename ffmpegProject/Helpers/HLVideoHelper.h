//
//  HLVideoHelper.h
//  ffmpegProject
//
//  Created by hailong on 2019/12/20.
//  Copyright © 2019 HL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

//主要更具文件名推断封装类型

NS_ASSUME_NONNULL_BEGIN
@interface HLVideoHelper : NSObject

#pragma mark - remux
- (void) changeRemux:(NSString *)sender to:(NSString *)desFile;
//合并
- (void) mixAllFile:(NSArray*)files to:(NSString *)desFile;

- (void) justAudio:(NSArray *)files to:(NSString *)desFile;

- (UIImage *) thumbnailImageOfVideo:(NSString *) videoPath
                thumbnailFrameIndex:(NSInteger)frameIndex
                               size:(CGSize)desSize;



@end

NS_ASSUME_NONNULL_END
