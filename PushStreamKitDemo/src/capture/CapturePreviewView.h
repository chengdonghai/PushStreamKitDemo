//
//  CapturePreviewView.h
//  PushStreamKitDemo
//
//  Created by Cheng.dh on 2021/2/9.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@class AVCaptureVideoPreviewLayer;

@interface CapturePreviewView : UIView

- (AVCaptureVideoPreviewLayer *)previewLayer;

@end

NS_ASSUME_NONNULL_END
