# iOS_ffmpeg_project
FFmpeg 基础API的使用 + 基于FFmpeg的播放器功能 （iOS Objective-C ）


FFMpeg的学习
- [x] FFmpeg代码库
    - [x] 下载
    - [x] 编译  arm64 x86_64
- [ ]  格式转换
    - [x] TS转换mp4
    - [x] 抽取AAC音频
    - [x] m3u8合并
    - [x] 合并
    - [x] 合并转mp4

    - [ ] mp4转mp3
        - [ ] 音频转码
        

- [ ]  ffmepg播放器
    - [ ] 视频
        - [ ] 渲染
            - [ ] metal
            - [x] openglES
        - [x] 转码解码
            - [x] 转换成内部使用的像素RGB或者YUV信息结构
    - [x] 视频缓存读取
        - [x] 当发现不足时又解码
        - [x] 超出最大缓存时长时停止解码
        - [x] 缓存固定时间的帧
    - [x] 音视频同步
        - [x] 以音频为主，忽略/跳过视频，或者让视频等待
        - [x] 忽略同步，定时刷新
    - [x] 播放
        - [x] 视频-  定时刷新渲染新的帧
        - [x] 音频 — 由硬件驱动 callback的方式要新数据
    - [x] 音频

