//
//  Capture.m
//  PushStreamKitDemo
//
//  Created by Cheng.dh on 2021/2/8.
//

#import "Capture.h"
#import <AVFoundation/AVFoundation.h>

@interface Capture()<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate> {
    // 采集相关对象
    AVCaptureVideoDataOutput *videoOutput;
    AVCaptureAudioDataOutput *audioOutput;
    
    AVCaptureConnection *videoConnection;
    AVCaptureConnection *audioConnection;
    
    AVCaptureVideoPreviewLayer *_previewLayer;
    
    dispatch_queue_t acaptureQueue;
    dispatch_queue_t vcaptureQueue;
    dispatch_semaphore_t samaphore;
    
    AVCaptureDeviceInput *_deviceInput;
    int sampleCount;
 }
@property (nonatomic, assign) AVCaptureDevicePosition devicePosition;
@property (nonatomic, assign) AVCaptureVideoOrientation orientation;
@property (nonatomic, assign) AVCaptureSessionPreset preset;
@property (nonatomic, assign) BOOL isMirrored;
@end
/// 音视频采集
@implementation Capture

- (instancetype)init
{
    self = [super init];
    if (self) {
        acaptureQueue = dispatch_queue_create("acaptureQueue.com", DISPATCH_QUEUE_SERIAL);
        vcaptureQueue = dispatch_queue_create("vcaptureQueue.com", DISPATCH_QUEUE_SERIAL);
        samaphore = dispatch_semaphore_create(0);
        _devicePosition = AVCaptureDevicePositionFront;
        sampleCount = 0;
        _devicePosition = AVCaptureDevicePositionBack;
        _isMirrored = NO;
        _orientation = AVCaptureVideoOrientationPortrait;
        _preset = AVCaptureSessionPreset1280x720;
        [self createCaptureSession];
    }
    return self;
}

- (BOOL)createCaptureSession
{
    /** AVCaptureSession 采集会话对象，它一头连接着输入对象(比如麦克风采集音频，摄像头采集视频)
         *  一头连接着输出对象向app提供采集好的原始音视频数据
         *  通过它管理采集的开始与结束
         */
    _session = [[AVCaptureSession alloc] init];
    // 设置视频采集的宽高参数
    _session.sessionPreset = _preset;
    //实际的音频采集物理设备对象，通过此对象来创建音频输入对象；备注postion一定要是AVCaptureDevicePositionUnspecified
    
    AVCaptureDevice *micro = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInMicrophone mediaType:AVMediaTypeAudio position:AVCaptureDevicePositionUnspecified];
    AVCaptureDeviceInput *audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:micro error:nil];
    if (![_session canAddInput:audioInput]) {
        NSLog(@"can not add audioInput");
        return  NO;
    }
    [_session addInput:audioInput];
    
    // 采集物理设备对象，选择后置摄像头
    AVCaptureDevice *camera = [self videoDeviceWitchPosition:_devicePosition];
     // 通过视频物理设备对象创建视频输入对象
    AVCaptureDeviceInput *videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:camera error:nil];
    if (![_session canAddInput:videoInput]) {
        NSLog(@"can not add video input");
        return NO;
    }
    _deviceInput = videoInput;
    [_session addInput:videoInput];
    // 如果调用了[session startRunning]之后要想改变音视频输出对象配置参数，则必须调用[session beginConfiguration];和
        // [session commitConfiguration];才能生效。如果没有调用[session startRunning]则这两句代码可以不写
    [_session beginConfiguration];
    // AVCaptureVideoDataOutput 创建视频输出对象，对象用于向外部输出视频数据，通过该对象设置向外部输入的视频数据格式
        // 比如像素格式(iOS只支持kCVPixelFormatType_32BGRA/kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        // kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange三种格式)
    videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    NSDictionary *videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
    videoOutput.videoSettings = videoSettings;
    // 当采集速度过快而处理速度跟不上时的丢弃策略，默认丢弃最新采集的视频。这里设置为NO，表示不丢弃缓存起来
    videoOutput.alwaysDiscardsLateVideoFrames = YES;
 
    [videoOutput setSampleBufferDelegate:self queue:vcaptureQueue];

    [_session addOutput:videoOutput];
    
    // AVCaptureAudioDataOutput 创建音频输出对象
    audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    [audioOutput setSampleBufferDelegate:self queue:acaptureQueue];
    [_session addOutput:audioOutput];
    
    videoConnection = [videoOutput connectionWithMediaType:AVMediaTypeVideo];
    audioConnection = [audioOutput connectionWithMediaType:AVMediaTypeAudio];
    videoConnection.videoMirrored = _isMirrored;
    if([videoConnection isVideoOrientationSupported]) {
        videoConnection.videoOrientation = _orientation;
    }
    
    [_session commitConfiguration];
    
    return YES;
}
/// 更新帧率
- (void)updateFps:(int32_t)fps {
 
    AVCaptureDevice *vDevice = [self videoDeviceWitchPosition:_devicePosition];
    //获取当前支持的最大fps
    float maxRate = [(AVFrameRateRange *)[vDevice.activeFormat.videoSupportedFrameRateRanges objectAtIndex:0] maxFrameRate];
    //如果想要设置的fps小于或等于做大fps，就进行修改
    if (maxRate >= fps) {
        //实际修改fps的代码
        if ([vDevice lockForConfiguration:NULL]) {
            vDevice.activeVideoMinFrameDuration = CMTimeMake(10, (int)(fps * 10));
            vDevice.activeVideoMaxFrameDuration = vDevice.activeVideoMinFrameDuration;
            [vDevice unlockForConfiguration];
        }
    }
}
/// 切换摄像头（前置或后置）
- (void)changeCamaraPosition {
    dispatch_async(vcaptureQueue, ^{
        if (self.devicePosition == AVCaptureDevicePositionFront) {
            self.devicePosition = AVCaptureDevicePositionBack;
        } else {
            self.devicePosition = AVCaptureDevicePositionFront;
        }
        AVCaptureDevice *camera = [self videoDeviceWitchPosition:self.devicePosition];
        [self.session beginConfiguration];
        [self.session removeInput:self->_deviceInput];
        
        AVCaptureDeviceInput *videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:camera error:nil];
        if (!videoInput) {
            NSLog(@"can not init video input");
            return;
        }
        if (![self.session canAddInput:videoInput]) {
            NSLog(@"can not add video input");
            return;
        }
        self->_deviceInput = videoInput;
        [self.session addInput:videoInput];

        [self.session commitConfiguration];
        
     });
 
}
/// 设置视频采集方向
- (void)setVideoOrientation:(AVCaptureVideoOrientation)orientation
{
    _orientation = orientation;
    dispatch_async(vcaptureQueue, ^{
        self->videoConnection.videoOrientation = orientation;
    });
}
/// 设置是否镜像
- (void)setVideoMirrored:(BOOL)isMirrored
{
    _isMirrored = isMirrored;
    dispatch_async(vcaptureQueue, ^{
        self->videoConnection.videoMirrored = isMirrored;
    });
}
/// 设置采集分辨率
- (void)setVideoDimension:(AVCaptureSessionPreset)preset
{
    _preset = preset;
    dispatch_async(vcaptureQueue, ^{
        [self.session beginConfiguration];
        if ([self.session canSetSessionPreset:preset]) {
            [self.session setSessionPreset:preset];
        };
        [self.session commitConfiguration];
    });
}
#pragma mark - private functions
- (AVCaptureDevice *)videoDeviceWitchPosition:(AVCaptureDevicePosition)position
{
    AVCaptureDevice *videoDevice;

    if (@available(iOS 11.1, *)) {
        NSArray<AVCaptureDeviceType> *deviceTypes = @[
            AVCaptureDeviceTypeBuiltInWideAngleCamera,
#if TARGET_OS_IOS
            AVCaptureDeviceTypeBuiltInDualCamera,
            AVCaptureDeviceTypeBuiltInTrueDepthCamera
#endif
        ];
        AVCaptureDeviceDiscoverySession *session = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceTypes
                                                                                                          mediaType:AVMediaTypeVideo
                                                                                                           position:position];
        for (AVCaptureDevice *device in session.devices) {
            if (device.position == position) {
                videoDevice = device;
                break;
            }
        }
    } else if (@available(iOS 10.0, *)) {
        videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                         mediaType:AVMediaTypeVideo
                                                          position:position];
    } else {
        NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in cameras) {
            if (device.position == position) {
                videoDevice = device;
                break;
            }
        }
    }

    return videoDevice;
}

- (AVCaptureConnection *)getVideoConnection
{
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in [videoOutput connections]) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
                videoConnection = connection;
            }
        }
    }
    return videoConnection;
}
/// 开始采集
- (void)startRunning {
    [_session startRunning];
}
/// 停止采集
- (void)stopRunning {
    [_session stopRunning];
}
// 这里的sampleBuffer就是采集到的数据了,根据connection来判断，是Video还是Audio的数据
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    // 这里的sampleBuffer就是采集到的数据了,根据connection来判断，是Video还是Audio的数据
    if (connection == videoConnection) {
        NSLog(@"这里获的 video sampleBuffer，做进一步处理（编码H.264）%i", ++sampleCount);
        if (self.delegate) {
            [self.delegate capture:self videoBuffer:sampleBuffer];
        }
         
    } else if (connection == audioConnection) {
        NSLog(@"这里获得 audio sampleBuffer，做进一步处理（编码AAC）");
        if (self.delegate) {
            [self.delegate capture:self audioBuffer:sampleBuffer];
        }
    }
}

@end
