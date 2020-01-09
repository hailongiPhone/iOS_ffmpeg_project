//
//  OPGLESRender.h
//  ffmpegProject
//
//  Created by hailong on 2020/01/06.
//  Copyright © 2020 HL. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <OpenGLES/gltypes.h>
#import "HLAVFrameVideo.h"

NS_ASSUME_NONNULL_BEGIN

@protocol OPGLESRenderProtocol

- (void) feedTextureFrame: (HLAVFrameVideo *) frame;
- (void) renderTexture;
- (void) releaseRender;

- (BOOL) isValid;

//方便扩展
- (NSString *) fragmentShader;
- (void) resolveUniforms: (GLuint) program;

@end

@interface OPGLESRender : NSObject <OPGLESRenderProtocol>
{
    @protected
    NSInteger   _frameWidth;
    NSInteger   _frameHeight;
    GLuint  _filterProgram;
    GLint   _position;
    GLint   _texcoord;
    
    GLuint  _texture;
    GLint   _uniformSampler;
}

- (BOOL) isValid;
- (NSString *) fragmentShader;
- (void) resolveUniforms: (GLuint) program;
- (void) renderTexture;
- (void) feedTextureFrame: (HLAVFrameVideo *) frame;

- (BOOL) prepareRender;
- (void) releaseRender;

- (BOOL) buildProgram:(NSString*) vertexShader fragmentShader:(NSString*) fragmentShader;

//@property(nonatomic,assign) NSInteger   frameWidth;
//@property(nonatomic,assign) NSInteger   frameHeight;
//
//@property(nonatomic,assign) GLuint  filterProgram;
//@property(nonatomic,assign) GLint   position;
//@property(nonatomic,assign) GLint   texcoord;
//
//@property(nonatomic,assign) GLuint  texture;
//@property(nonatomic,assign) GLint   uniformSampler;
@end


@interface OPGLESRenderRGB : OPGLESRender
@end

NS_ASSUME_NONNULL_END
