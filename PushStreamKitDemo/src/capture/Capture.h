//
//  Capture.h
//  PushStreamKitDemo
//
//  Created by Cheng.dh on 2021/2/8.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
@protocol CaptureDelegate;

NS_ASSUME_NONNULL_BEGIN

/// 采集音视频
@class AVCaptureSession;
 
@interface Capture : NSObject
{
    
}
@property(nonatomic, strong, readonly) AVCaptureSession *session;
@property(nonatomic, weak) id<CaptureDelegate> delegate;

- (void)startRunning;
- (void)stopRunning;
- (void)changeCamaraPosition;
/// 更新帧率
- (void)updateFps:(int32_t)fps;
@end

NS_ASSUME_NONNULL_END
 
@protocol CaptureDelegate <NSObject>

@required
-(void)capture:(Capture *_Nonnull)capture videoBuffer:(CMSampleBufferRef _Nullable)buffer;
-(void)capture:(Capture *_Nonnull)capture audioBuffer:(CMSampleBufferRef _Nullable)buffer;

@end
