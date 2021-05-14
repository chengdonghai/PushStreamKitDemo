//
//  AudioHWEncoder.h
//  PushStreamKitDemo
//
//  Created by Cheng.dh on 2021/2/9.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import "LFAudioFrame.h"

NS_ASSUME_NONNULL_BEGIN
@protocol AudioHWEncoderDelegate;

@interface AudioHWEncoder : NSObject
@property(nonatomic, weak) id<AudioHWEncoderDelegate> delegate;

- (void)encode:(CMSampleBufferRef)sampleBuffer timeStamp:(uint64_t)timeStamp;
@end

@protocol AudioHWEncoderDelegate <NSObject>

-(void)encodedAudio:(AudioHWEncoder *)encoder audioFrame:(LFAudioFrame *)audioFrame;

@end
NS_ASSUME_NONNULL_END
