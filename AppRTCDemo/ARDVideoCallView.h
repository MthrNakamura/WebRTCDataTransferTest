/*
 * libjingle
 * Copyright 2015 Google Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice,
 *     this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright notice,
 *     this list of conditions and the following disclaimer in the documentation
 *     and/or other materials provided with the distribution.
 *  3. The name of the author may not be used to endorse or promote products
 *     derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <UIKit/UIKit.h>

#import <WebRTC/RTCEAGLVideoView.h>

@class ARDVideoCallView;
@protocol ARDVideoCallViewDelegate <NSObject>

// Called when the camera switch button is pressed.
- (void)videoCallViewDidSwitchCamera:(ARDVideoCallView *)view;

// Called when the hangup button is pressed.
- (void)videoCallViewDidHangup:(ARDVideoCallView *)view;

@end

// Video call view that shows local and remote video, provides a label to
// display status, and also a hangup button.
@interface ARDVideoCallView : UIView

@property(nonatomic, readonly) UILabel *statusLabel;
@property(nonatomic, readonly) RTCEAGLVideoView *localVideoView;
@property(nonatomic, readonly) RTCEAGLVideoView *remoteVideoView;
@property(nonatomic, weak) id<ARDVideoCallViewDelegate> delegate;

@end