#import "OPGLESRender.h"

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

#pragma mark - shaders

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

NSString *const vertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec2 texcoord;
 varying vec2 v_texcoord;
 
 void main()
 {
     gl_Position = position;
     v_texcoord = texcoord.xy;
 }
);
//NSString *const vertexShaderString = SHADER_STRING
//(
// attribute vec4 position;
// attribute vec2 texcoord;
// uniform mat4 modelViewProjectionMatrix;
// varying vec2 v_texcoord;
//
// void main()
// {
////    gl_Position = modelViewProjectionMatrix * position;
//    gl_Position = position;
//    v_texcoord = texcoord.xy;
//}
// );

NSString *const rgbFragmentShaderString = SHADER_STRING
(
 varying highp vec2 v_texcoord;
 uniform sampler2D s_texture;
 
 void main()
 {
    gl_FragColor = texture2D(s_texture, v_texcoord);
}
 );

NSString *const yuvFragmentShaderString = SHADER_STRING
(
 varying highp vec2 v_texcoord;
 uniform sampler2D s_texture_y;
 uniform sampler2D s_texture_u;
 uniform sampler2D s_texture_v;
 
 void main()
 {
    highp float y = texture2D(s_texture_y, v_texcoord).r;
    highp float u = texture2D(s_texture_u, v_texcoord).r - 0.5;
    highp float v = texture2D(s_texture_v, v_texcoord).r - 0.5;
    
    highp float r = y +             1.402 * v;
    highp float g = y - 0.344 * u - 0.714 * v;
    highp float b = y + 1.772 * u;
    
    gl_FragColor = vec4(r,g,b,1.0);
}
 );

static BOOL validateProgram(GLuint prog)
{
    GLint status;
    
    glValidateProgram(prog);
    
#ifdef DEBUG
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        HLAVLog( @"Program validate log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == GL_FALSE) {
        HLAVLog(@"Failed to validate program %d", prog);
        return NO;
    }
    
    return YES;
}

static GLuint compileShader(GLenum type, NSString *shaderString)
{
    GLint status;
    const GLchar *sources = (GLchar *)shaderString.UTF8String;
    
    GLuint shader = glCreateShader(type);
    if (shader == 0 || shader == GL_INVALID_ENUM) {
        HLAVLog(@"Failed to create shader %d", type);
        return 0;
    }
    
    glShaderSource(shader, 1, &sources, NULL);
    glCompileShader(shader);
    
#ifdef DEBUG
    GLint logLength;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(shader, logLength, &logLength, log);
        HLAVLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
        glDeleteShader(shader);
        HLAVLog(@"Failed to compile shader:\n");
        return 0;
    }
    
    return shader;
}

static void mat4f_LoadOrtho(float left, float right, float bottom, float top, float near, float far, float* mout)
{
    float r_l = right - left;
    float t_b = top - bottom;
    float f_n = far - near;
    float tx = - (right + left) / (right - left);
    float ty = - (top + bottom) / (top - bottom);
    float tz = - (far + near) / (far - near);
    
    mout[0] = 2.0f / r_l;
    mout[1] = 0.0f;
    mout[2] = 0.0f;
    mout[3] = 0.0f;
    
    mout[4] = 0.0f;
    mout[5] = 2.0f / t_b;
    mout[6] = 0.0f;
    mout[7] = 0.0f;
    
    mout[8] = 0.0f;
    mout[9] = 0.0f;
    mout[10] = -2.0f / f_n;
    mout[11] = 0.0f;
    
    mout[12] = tx;
    mout[13] = ty;
    mout[14] = tz;
    mout[15] = 1.0f;
}

#pragma mark -

@implementation OPGLESRender
- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setupRender];
    }
    return self;
}

- (BOOL) isValid;
{
    return _texture != 0;
}

- (NSString *) fragmentShader;
{
    return rgbFragmentShaderString;
}

- (void) resolveUniforms: (GLuint) program;
{
    _uniformSampler = glGetUniformLocation(_filterProgram, "s_texture");
}

- (void) feedTextureFrame: (HLAVFrameVideo *) frame;
{
    HLAVFrameVideoRGB *rgbFrame = (HLAVFrameVideoRGB *)frame;
    assert(rgbFrame.data.length == rgbFrame.width * rgbFrame.height * 3);
    
    _frameWidth = rgbFrame.width;
    _frameHeight = rgbFrame.height;
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    if (0 == _texture)
        glGenTextures(1, &_texture);
    
    glBindTexture(GL_TEXTURE_2D, _texture);
    
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_RGB,
                 (int)rgbFrame.width,
                 (int)rgbFrame.height,
                 0,
                 GL_RGB,
                 GL_UNSIGNED_BYTE,
                 rgbFrame.data.bytes);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
}

- (void) renderTexture;
{
    glUseProgram(_filterProgram);
    glClearColor(0.0f, 0.0f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    glBindTexture(GL_TEXTURE_2D, _texture);
    
    static const GLfloat imageVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    GLfloat noRotationTextureCoordinates[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };
    
    glVertexAttribPointer(_position, 2, GL_FLOAT, 0, 0, imageVertices);
    glEnableVertexAttribArray(_position);
    glVertexAttribPointer(_texcoord, 2, GL_FLOAT, 0, 0, noRotationTextureCoordinates);
    glEnableVertexAttribArray(_texcoord);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _texture);
    glUniform1i(_uniformSampler, 0);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void) setupRender;
{
    [self buildProgram:vertexShaderString fragmentShader:[self fragmentShader]];
    [self resolveUniforms:_filterProgram];
    
    return;
}

- (BOOL) prepareRender
{
    if (_texture <= 0) {
        return NO;
    }
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _texture);
    glUniform1i(_uniformSampler, 0);
    
    return YES;
}

- (void) releaseRender;
{
    if (_filterProgram) {
        glDeleteProgram(_filterProgram);
        _filterProgram = 0;
    }
    if(_texture) {
        glDeleteTextures(1, &_texture);
    }
}

- (BOOL) buildProgram:(NSString*) vertexShader fragmentShader:(NSString*) fragmentShader;
{
    
    BOOL result = NO;
    GLuint vertShader = 0, fragShader = 0;
    _filterProgram = glCreateProgram();
    vertShader = compileShader(GL_VERTEX_SHADER, vertexShader);
    if (!vertShader)
        goto exit;
    fragShader = compileShader(GL_FRAGMENT_SHADER, fragmentShader);
    if (!fragShader)
        goto exit;
    
    glAttachShader(_filterProgram, vertShader);
    glAttachShader(_filterProgram, fragShader);
    
    glLinkProgram(_filterProgram);
    
    _position = glGetAttribLocation(_filterProgram, "position");
    _texcoord = glGetAttribLocation(_filterProgram, "texcoord");
    
    
    GLint status;
    glGetProgramiv(_filterProgram, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
        NSLog(@"Failed to link program %d", _filterProgram);
        goto exit;
    }
    result = validateProgram(_filterProgram);
exit:
    if (vertShader)
        glDeleteShader(vertShader);
    if (fragShader)
        glDeleteShader(fragShader);
    
    if (result) {
        NSLog(@"OK setup GL programm");
    } else {
        glDeleteProgram(_filterProgram);
        _filterProgram = 0;
    }
    return result;
}

////缓存信息
//- (void)initVertex {
//    _vec4Position[0] = -1; _vec4Position[1] = -1;
//    _vec4Position[2] =  1; _vec4Position[3] = -1;
//    _vec4Position[4] = -1; _vec4Position[5] =  1;
//    _vec4Position[6] =  1; _vec4Position[7] =  1;
//}
//
//- (void)initTexCord {
//    _vec2Texcoord[0] = 0; _vec2Texcoord[1] = 1;
//    _vec2Texcoord[2] = 1; _vec2Texcoord[3] = 1;
//    _vec2Texcoord[4] = 0; _vec2Texcoord[5] = 0;
//    _vec2Texcoord[6] = 1; _vec2Texcoord[7] = 0;
//}
//
//- (void)initProjection {
//    [DLGPlayerView ortho:_mat4Projection];
//}

@end


@implementation OPGLESRenderRGB


@end
#pragma GCC diagnostic pop
