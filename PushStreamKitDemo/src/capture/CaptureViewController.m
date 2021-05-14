//
//  CaptureViewController.m
//  PushStreamKitDemo
//
//  Created by Cheng.dh on 2021/2/8.
//

#import "CaptureViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "Capture.h"
#import "CapturePreviewView.h"
#import "VideoHWEncoder.h"
#import "AudioHWEncoder.h"
#import "LFStreamRTMPSocket.h"

@interface CaptureViewController ()<CaptureDelegate, VideoHWEncoderDelegate, AudioHWEncoderDelegate>
{
    AVCaptureVideoPreviewLayer *_previewLayer;
}
@property(nonatomic, strong) Capture *capture;
@property(nonatomic, strong) CapturePreviewView *preview;
@property(nonatomic, strong) VideoHWEncoder *videoEncoder;
@property(nonatomic, strong) AudioHWEncoder *audioEncoder;
@property(nonatomic, strong) LFStreamRTMPSocket *socket;
@property(nonatomic, strong) AVSampleBufferDisplayLayer *displayLayer;
@end

@implementation CaptureViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    LFLiveStreamInfo *info = [[LFLiveStreamInfo alloc] init];
    info.url = @"rtmp://192.168.60.9:1935/live/livestream";
    
    _videoEncoder = [[VideoHWEncoder alloc] init];
    _audioEncoder = [[AudioHWEncoder alloc] init];
    _videoEncoder.delegate = self;
    _audioEncoder.delegate = self;
    
    LFLiveVideoConfiguration* videoConfig = [[LFLiveVideoConfiguration alloc] init];
    videoConfig.videoSize = CGSizeMake(_videoEncoder.config->width, _videoEncoder.config->height);
    videoConfig.videoBitRate = _videoEncoder.config->bitRate;
    videoConfig.videoFrameRate = _videoEncoder.config->fps;
    LFLiveAudioConfiguration *audioConfig = [[LFLiveAudioConfiguration alloc]init];
    audioConfig.audioSampleRate = LFLiveAudioSampleRate_44100Hz;
    audioConfig.audioBitrate = LFLiveAudioBitRate_Default;
    audioConfig.numberOfChannels = 1;
    info.audioConfiguration = audioConfig;
    info.videoConfiguration = videoConfig;
    _socket = [[LFStreamRTMPSocket alloc] initWithStream:info];
    [_socket start];
    
    _capture = [[Capture alloc] init];
    _capture.delegate = self;
    [_capture updateFps:_videoEncoder.config->fps];
    [self showPreview];
    //[self showSampleLayer];
    self.view.backgroundColor = UIColor.whiteColor;
    
    
    // Do any additional setup after loading the view.
}
- (void)dealloc
{
    [_socket stop];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.capture startRunning];
    
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.capture stopRunning];
}

- (void)showPreview {
    self.preview = [[CapturePreviewView alloc] initWithFrame:self.view.bounds];
    _preview.previewLayer.session = self.capture.session;
    _preview.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:_preview atIndex:0];
}

-(void)showSampleLayer {
    _displayLayer = [[AVSampleBufferDisplayLayer alloc] init];
    _displayLayer.frame = CGRectMake(0, 0, _videoEncoder.config->width / 5.0, _videoEncoder.config->height / 5.0);
    _displayLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.preview.layer insertSublayer:_displayLayer above:_preview.previewLayer];
}
- (IBAction)changeCamara:(id)sender {
    [self.capture changeCamaraPosition];
    [self.preview removeFromSuperview];
    [self showPreview];
    
}
- (IBAction)closeAction:(id)sender {
    [self dismissViewControllerAnimated:true completion:nil];
}
// MARK: Capture Delegate
- (void)capture:(Capture *)capture audioBuffer:(CMSampleBufferRef _Nullable)buffer
{
    [_audioEncoder encode:buffer timeStamp:CACurrentMediaTime()*1000];
}

-(void)capture:(Capture *)capture videoBuffer:(CMSampleBufferRef _Nullable)buffer
{
    //CFRetain(buffer);
     [_displayLayer enqueueSampleBuffer:buffer];
    [_videoEncoder encode:buffer timeStamp:CACurrentMediaTime()*1000];
    //CFRelease(buffer);
}
// MARK: Encoded Delegate
- (void)encodedAudio:(AudioHWEncoder *)encoder audioFrame:(LFAudioFrame *)audioFrame
{
    [_socket sendFrame:audioFrame];
}

- (void)encodedVideo:(VideoHWEncoder *)encoder videoFrame:(LFVideoFrame *)videoFrame
{
    [_socket sendFrame:videoFrame];
}

@end
