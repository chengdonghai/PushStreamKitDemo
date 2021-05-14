//
//  H264HWEncoder.h
//  PushStreamKitDemo
//
//  Created by Cheng.dh on 2021/2/9.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import "LFVideoFrame.h"
typedef struct HW_ENCODER_CONFIGURATION {
    int fps;
    int width;
    int height;
    int bitRate;
    int keyframeInterval;
} HWEncodeConfiguration;
NS_ASSUME_NONNULL_BEGIN
@protocol VideoHWEncoderDelegate;
@interface VideoHWEncoder : NSObject
@property(nonatomic, weak) id<VideoHWEncoderDelegate> delegate;
- (instancetype)initWithConfig:(HWEncodeConfiguration)config;
- (HWEncodeConfiguration *)config;

/// 开始编码
/// @param sampleBuffer 采样数据
- (void)encode:(CMSampleBufferRef)sampleBuffer timeStamp:(uint64_t)timeStamp;

@end
@protocol VideoHWEncoderDelegate <NSObject>

-(void)encodedVideo:(VideoHWEncoder *)encoder videoFrame:(LFVideoFrame *)videoFrame;

@end
NS_ASSUME_NONNULL_END
