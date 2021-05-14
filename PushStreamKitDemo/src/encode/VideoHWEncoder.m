//
//  H264HWEncoder.m
//  PushStreamKitDemo
//
//  Created by Cheng.dh on 2021/2/9.
//

#import "VideoHWEncoder.h"
#import <VideoToolbox/VideoToolbox.h>
@interface VideoHWEncoder()
@end
 
@implementation VideoHWEncoder
{
    NSUInteger _frameID;
    VTCompressionSessionRef compressSession;
    HWEncodeConfiguration _configuration;
    dispatch_queue_t aQuene;
    NSData *sps;
    NSData *pps;
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        _configuration.fps = 20;
        _configuration.bitRate = 800 * 1024;
        _configuration.height = 1280;
        _configuration.width = 720;
        _configuration.keyframeInterval = 30;
        [self setupCompressionSession];
    }
    return self;
}
- (instancetype)initWithConfig:(HWEncodeConfiguration)config
{
    self = [super init];
    if (self) {
        _configuration = config;
        [self setupCompressionSession];
    }
    return self;
}

- (HWEncodeConfiguration *)config
{
    return &_configuration;
}
- (void) setupCompressionSession {
    aQuene = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    // 1. 第几帧数据
    _frameID = 0;
    
    // 2. 视频宽高
    int width = _configuration.width, height = _configuration.height;
 
    // 3.创建CompressionSession对象,该对象用于对画面进行编码
    // kCMVideoCodecType_H264 : 表示使用h.264进行编码
    // didCompressH264 : 当一次编码结束会在该函数进行回调,可以在该函数中将数据,写入文件中
    VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH2641, (__bridge void*)self, &compressSession);
    // 4.设置实时编码输出（直播必然是实时输出,否则会有延迟）
    VTSessionSetProperty(compressSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    // 5.设置期望帧率(每秒多少帧,如果帧率过低,会造成画面卡顿)
    int fps = _configuration.fps;
    CFNumberRef  fpsRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &fps);
    VTSessionSetProperty(compressSession, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef);
    
    // 6.设置码率(码率: 编码效率, 码率越高,则画面越清晰, 如果码率较低会引起马赛克 --> 码率高有利于还原原始画面,但是也不利于传输)
    int bitRate = _configuration.bitRate;
    CFNumberRef bitRateRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRate);
    VTSessionSetProperty(compressSession, kVTCompressionPropertyKey_AverageBitRate, bitRateRef);
    NSArray *limit = @[@(bitRate * 1.5/8), @(1)];
    VTSessionSetProperty(compressSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)limit);
    // 7.设置关键帧（GOPsize)间隔
    int frameInterval = _configuration.keyframeInterval;
    CFNumberRef  frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &frameInterval);
    VTSessionSetProperty(compressSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, frameIntervalRef);
    // 8.基本设置结束, 准备进行编码
    VTCompressionSessionPrepareToEncodeFrames(compressSession);

}
// 编码完成回调
void didCompressH2641(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer) {
    // 1.判断状态是否等于没有错误
    if (status != noErr) {
        return;
    }

    // 2.根据传入的参数获取对象
    VideoHWEncoder* encoder = (__bridge VideoHWEncoder*)outputCallbackRefCon;
    uint64_t timeStamp = [((__bridge_transfer NSNumber *)sourceFrameRefCon) longLongValue];

    // 3.判断是否是关键帧
    bool isKeyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    // 判断当前帧是否为关键帧
    // 获取sps & pps数据
    if (isKeyframe && !encoder->sps)
    {
        // 获取编码后的信息（存储于CMFormatDescriptionRef中）
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);

        // 获取SPS信息
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );

        // 获取PPS信息
        size_t pparameterSetSize, pparameterSetCount;
        const uint8_t *pparameterSet;
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );

        // 装sps/pps转成NSData，以方便写入文件
        NSData *sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
        NSData *pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
        encoder->sps=sps;
        encoder->pps=pps;
        // 写入文件
        [encoder gotSpsPps:sps pps:pps];
    }

    // 获取数据块
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4; // 返回的nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length

        // 循环获取nalu数据
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            uint32_t NALUnitLength = 0;
            // Read the NAL unit length
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);

            // 从大端转系统端
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);

            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            [encoder gotEncodedData:data isKeyFrame:isKeyframe];
            LFVideoFrame *frame = [LFVideoFrame new];
            frame.isKeyFrame = isKeyframe;
            frame.pps = encoder->pps;
            frame.sps = encoder->sps;
            frame.data = data;
            frame.timestamp = timeStamp;
            if (encoder.delegate) {
                [encoder.delegate encodedVideo:encoder videoFrame:frame];
            }
            // 移动到写一个块，转成NALU单元
            // Move to the next NAL unit in the block buffer
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}

- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps
{
    // 1.拼接NALU的header
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1;
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];

//     2.将NALU的头&NALU的体写入文件
//    [self.fileHandle writeData:ByteHeader];
//    [self.fileHandle writeData:sps];
//    [self.fileHandle writeData:ByteHeader];
//    [self.fileHandle writeData:pps];

}
- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame
{
//    if (self.fileHandle != NULL)
//    {
//        const char bytes[] = "\x00\x00\x00\x01";
//        size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
//        NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
//        [self.fileHandle writeData:ByteHeader];
//        [self.fileHandle writeData:data];
//    }
}
- (void)encode:(CMSampleBufferRef)sampleBuffer timeStamp:(uint64_t)timestamp
{
    
    dispatch_sync(aQuene, ^{
        _frameID++;
        // Get the CV Image buffer
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        
        // Create properties
        CMTime presentationTimeStamp = CMTimeMake(_frameID, 1000);
        //CMTime duration = CMTimeMake(1, DURATION);
        VTEncodeInfoFlags flags;
        NSDictionary *properties = nil;
        if (_frameID % (int32_t)_configuration.keyframeInterval == 0) {
            properties = @{(__bridge NSString *)kVTEncodeFrameOptionKey_ForceKeyFrame: @YES};
        }
        NSNumber *timeNumber = @(timestamp);
        // Pass it to the encoder
        OSStatus statusCode = VTCompressionSessionEncodeFrame(compressSession,
                                                              imageBuffer,
                                                              presentationTimeStamp,
                                                              kCMTimeInvalid,
                                                              (__bridge CFDictionaryRef)properties, (__bridge void *)timeNumber, &flags);
        // Check for error
        if (statusCode != noErr) {
            NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
            return;
        }
        NSLog(@"H264: VTCompressionSessionEncodeFrame Success");
    });
}

- (void) close
{
    // Mark the completion
    VTCompressionSessionCompleteFrames(compressSession, kCMTimeInvalid);
    
    // End the session
    VTCompressionSessionInvalidate(compressSession);
    CFRelease(compressSession);
    compressSession = NULL;
}

- (void)dealloc
{
    [self close];
}
@end
