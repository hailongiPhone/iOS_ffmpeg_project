//
//  HLAVHeader.h
//  ffmpegProject
//
//  Created by hailong on 2020/01/06.
//  Copyright © 2020 HL. All rights reserved.
//

#ifndef HLAVHeader_h
#define HLAVHeader_h

typedef NS_ENUM(NSUInteger, HLAVFrameType) {
    HLAVFrameTypeAudio,
    HLAVFrameTypeVideo,
    HLAVFrameTypeSubtitle,
    HLAVFrameTypeArtwork,
};

typedef NS_ENUM(NSUInteger, HLAVFrameVideoFormat) {
    HLAVFrameVideoFormatRGB,
    HLAVFrameVideoFormatYUV,
};


#define HLWeakify(obj) __weak typeof(obj) weak_obj = obj;
#define HLStrongify(obj) __strong typeof(weak_obj) obj = weak_obj;

#ifdef DEBUG
#define HLAVLog(args...) HLAVExtendNSLog(__FILE__,__LINE__,__PRETTY_FUNCTION__,args);
#else
#define HLAVLog(x...)
#endif
 
void HLAVExtendNSLog(const char *file, int lineNumber, const char *functionName, NSString *format, ...);

#endif /* HLAVHeader_h */
