//
//  CapturePreviewView.m
//  PushStreamKitDemo
//
//  Created by Cheng.dh on 2021/2/9.
//

#import "CapturePreviewView.h"
#import <AVFoundation/AVCaptureVideoPreviewLayer.h>

@implementation CapturePreviewView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    }
    return self;
}
+(Class)layerClass
{
    return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureVideoPreviewLayer *)previewLayer
{
    return (AVCaptureVideoPreviewLayer *)self.layer;
}
 
@end
