//
//  HLAVRenderView.m
//  ffmpegProject
//
//  Created by hailong on 2020/01/06.
//  Copyright © 2020 HL. All rights reserved.
//

#import "HLAVRenderView.h"

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import "OPGLESRender.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"

@interface HLAVRenderView () {
    CAEAGLLayer *_eaglLayer;
    EAGLContext *_context;
    
    GLuint _frameBuffer;
    GLuint _renderBuffer;
    
    GLuint _programHandle;
    
    GLint _backingWidth;
    GLint _backingHeight;
    
    
    dispatch_queue_t _dispatchQueue;
}
@property(nonatomic,strong) HLAVDecoder * decoder;
@property(nonatomic,strong) OPGLESRenderRGB * render;
@property(nonatomic,strong) HLAVFrameVideo * lastFrame;

@end

@implementation HLAVRenderView

- (instancetype) init;
{
    self = [super init];
    if (self && ![self setup]) {
        self = nil;
    }
    return self;
}

- (instancetype) initWithCoder:(NSCoder *)coder;
{
    self = [super initWithCoder:coder];
    if (self && ![self setup]) {
        self = nil;
    }
    return self;
}
- (instancetype) initWithFrame:(CGRect)frame;
{
    self = [super initWithFrame:frame];
    if (self && ![self setup]) {
        self = nil;
    }
    return self;
}
- (instancetype) initWithFrame:(CGRect)frame
                       decoder: (HLAVDecoder *) decoder;
{
    self = [super initWithFrame:frame];
    if (self) {
        self.decoder = decoder;
        if (![self setup]) {
            self = nil;
        }
    }
    return self;
}

#pragma mark - OpenGL ES Setup

+ (Class) layerClass
{
    return [CAEAGLLayer class];
}

- (BOOL) setup;
{
    BOOL result =  [self setupEAGL];
    if (result) {
        [self setupQueue];
    }
    
    return result;
}
- (BOOL) setupEAGL {
    
    _eaglLayer = (CAEAGLLayer *)self.layer;
    _eaglLayer.opaque = YES;
    
    _eaglLayer.drawableProperties = @{ kEAGLDrawablePropertyRetainedBacking : @(NO),
                                       kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8
                                       };
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (_context == nil) return NO;
    if (![EAGLContext setCurrentContext:_context]) return NO;
    
    if (![self createGLBuffer]) {
        return NO;
    }
    
    GLenum glError = glGetError();
    if (glError != GL_NO_ERROR) {
        return NO;
    }
    
    return YES;
}

- (BOOL) createGLBuffer;
{
    glGenFramebuffers(1, &_frameBuffer);
    glGenRenderbuffers(1, &_renderBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    return status == GL_FRAMEBUFFER_COMPLETE;
}

- (void) deleteGLBuffer {
    glDeleteFramebuffers(1, &_frameBuffer);
    _frameBuffer = 0;
    
    glDeleteRenderbuffers(1, &_renderBuffer);
    _renderBuffer = 0;
}

- (void)reload {
    [self deleteGLBuffer];
    [self createGLBuffer];
    
    [self loadShaders];
//    [self deleteGLProgram];
//    [self createGLBuffer];
//    [self createGLProgram];
//    [self updatePosition];
//    [self updateScale];
//    [self updateRotationMatrix];
    [self render:self.lastFrame];
}


#pragma mark - View Lifecycle

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self reload];
}

- (void)setContentMode:(UIViewContentMode)contentMode
{
    [super setContentMode:contentMode];
    //可能渲染区域变更，宽高比变了所以需要更新顶点坐标，重新绘制
//    [self updateVertices];
//    if (_renderer.isValid)
//        [self render:nil];
}

#pragma mark - Shader

- (BOOL)loadShaders
{
    if (!self.render) {
        self.render = [OPGLESRenderRGB new];
    }
    
    return YES;
}

- (void)render: (HLAVFrameVideo *) frame
{
    if (!frame) {
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(_dispatchQueue, ^{
        __strong typeof(self) strongSelf = weakSelf;
        [EAGLContext setCurrentContext:strongSelf->_context];
        glBindFramebuffer(GL_FRAMEBUFFER, strongSelf->_frameBuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, strongSelf->_renderBuffer);
        
        glViewport(0, 0, strongSelf->_backingWidth, strongSelf->_backingHeight);
        
        if (frame) {
            [strongSelf.render feedTextureFrame:frame];
            [strongSelf.render renderTexture];
        }

        [strongSelf->_context presentRenderbuffer:GL_RENDERBUFFER];
        strongSelf.lastFrame = frame;
    });
}

#pragma mark - setup Queue
- (void) setupQueue;
{
      _dispatchQueue = dispatch_queue_create("viedeoRenderQueue", DISPATCH_QUEUE_SERIAL);
}
@end

#pragma clang diagnostic pop
