/*
 * libjingle
 * Copyright 2014 Google Inc.
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

#import "ARDAppClient+Internal.h"

#if defined(WEBRTC_IOS)
#import <WebRTC/RTCAVFoundationVideoSource.h>
#endif
#import <WebRTC/RTCICEServer.h>
#import <WebRTC/RTCMediaConstraints.h>
#import <WebRTC/RTCMediaStream.h>
#import <WebRTC/RTCPair.h>
#import <WebRTC/RTCVideoCapturer.h>
#import <WebRTC/RTCAVFoundationVideoSource.h>
#import <WebRTC/RTCDataChannel.h>

#import "ARDAppEngineClient.h"
#import "ARDCEODTURNClient.h"
#import "ARDJoinResponse.h"
#import "ARDMessageResponse.h"
#import "ARDSignalingMessage.h"
#import "ARDUtilities.h"
#import "ARDWebSocketChannel.h"
#import "RTCICECandidate+JSON.h"
#import "RTCSessionDescription+JSON.h"

#import "ARDTransData.h"


#import <zlib.h>

static NSString * const kARDDefaultSTUNServerUrl =
    @"stun:stun.l.google.com:19302";
// TODO(tkchin): figure out a better username for CEOD statistics.
static NSString * const kARDTurnRequestUrl =
    @"https://computeengineondemand.appspot.com"
    @"/turn?username=iapprtc&key=4080218913";

static NSString * const kARDAppClientErrorDomain = @"ARDAppClient";
static NSInteger const kARDAppClientErrorUnknown = -1;
static NSInteger const kARDAppClientErrorRoomFull = -2;
static NSInteger const kARDAppClientErrorCreateSDP = -3;
static NSInteger const kARDAppClientErrorSetSDP = -4;
static NSInteger const kARDAppClientErrorInvalidClient = -5;
static NSInteger const kARDAppClientErrorInvalidRoom = -6;

@implementation ARDAppClient {
    //NSMutableData* receivedData;
    NSInteger numBlocks;
    double mean_mbps;
    double prevTime;
    double totalProcTime;
    int countChunk;
    NSMutableArray* receivedData;
}

@synthesize delegate = _delegate;
@synthesize state = _state;
@synthesize roomServerClient = _roomServerClient;
@synthesize channel = _channel;
@synthesize turnClient = _turnClient;
@synthesize peerConnection = _peerConnection;
@synthesize factory = _factory;
@synthesize messageQueue = _messageQueue;
@synthesize isTurnComplete = _isTurnComplete;
@synthesize hasReceivedSdp  = _hasReceivedSdp;
@synthesize roomId = _roomId;
@synthesize clientId = _clientId;
@synthesize isInitiator = _isInitiator;
@synthesize iceServers = _iceServers;
@synthesize webSocketURL = _websocketURL;
@synthesize webSocketRestURL = _websocketRestURL;
@synthesize defaultPeerConnectionConstraints =
    _defaultPeerConnectionConstraints;
//@synthesize dataChannel = _dataChannel;
@synthesize dataChannels = _dataChannels;

- (instancetype)init {
  if (self = [super init]) {
    _roomServerClient = [[ARDAppEngineClient alloc] init];
    NSURL *turnRequestURL = [NSURL URLWithString:kARDTurnRequestUrl];
    _turnClient = [[ARDCEODTURNClient alloc] initWithURL:turnRequestURL];
    [self configure];
  }
    numBlocks = -1;
    
  return self;
}

- (instancetype)initWithDelegate:(id<ARDAppClientDelegate>)delegate {
  if (self = [super init]) {
    _roomServerClient = [[ARDAppEngineClient alloc] init];
    _delegate = delegate;
    NSURL *turnRequestURL = [NSURL URLWithString:kARDTurnRequestUrl];
    _turnClient = [[ARDCEODTURNClient alloc] initWithURL:turnRequestURL];
    [self configure];
  }
    numBlocks = -1;
    
    return self;
}

// TODO(tkchin): Provide signaling channel factory interface so we can recreate
// channel if we need to on network failure. Also, make this the default public
// constructor.
- (instancetype)initWithRoomServerClient:(id<ARDRoomServerClient>)rsClient
                        signalingChannel:(id<ARDSignalingChannel>)channel
                              turnClient:(id<ARDTURNClient>)turnClient
                                delegate:(id<ARDAppClientDelegate>)delegate {
  NSParameterAssert(rsClient);
  NSParameterAssert(channel);
  NSParameterAssert(turnClient);
  if (self = [super init]) {
    _roomServerClient = rsClient;
    _channel = channel;
    _turnClient = turnClient;
    _delegate = delegate;
    [self configure];
  }
    numBlocks = -1;
    
  return self;
}

- (void)configure {
  _factory = [[RTCPeerConnectionFactory alloc] init];
  _messageQueue = [NSMutableArray array];
  _iceServers = [NSMutableArray arrayWithObject:[self defaultSTUNServer]];
}

- (void)dealloc {
  [self disconnect];
}

- (void)setState:(ARDAppClientState)state {
  if (_state == state) {
      return;
  }
  _state = state;
  [_delegate appClient:self didChangeState:_state];
}

- (void)connectToRoomWithId:(NSString *)roomId
                    options:(NSDictionary *)options {
  NSParameterAssert(roomId.length);
  NSParameterAssert(_state == kARDAppClientStateDisconnected);
  self.state = kARDAppClientStateConnecting;

  // Request TURN.
  __weak ARDAppClient *weakSelf = self;
  [_turnClient requestServersWithCompletionHandler:^(NSArray *turnServers,
                                                     NSError *error) {
    if (error) {
      NSLog(@"Error retrieving TURN servers: %@", error);
    }
    ARDAppClient *strongSelf = weakSelf;
    [strongSelf.iceServers addObjectsFromArray:turnServers];
    strongSelf.isTurnComplete = YES;
    
      
      [strongSelf startSignalingIfReady];
          
  }];

  // Join room on room server.
  [_roomServerClient joinRoomWithRoomId:roomId
      completionHandler:^(ARDJoinResponse *response, NSError *error) {
    ARDAppClient *strongSelf = weakSelf;
    if (error) {
      [strongSelf.delegate appClient:strongSelf didError:error];
      return;
    }
    NSError *joinError =
        [[strongSelf class] errorForJoinResultType:response.result];
    if (joinError) {
      NSLog(@"Failed to join room:%@ on room server.", roomId);
      [strongSelf disconnect];
      [strongSelf.delegate appClient:strongSelf didError:joinError];
      return;
    }
    NSLog(@"Joined room:%@ on room server.", roomId);
    strongSelf.roomId = response.roomId;
    strongSelf.clientId = response.clientId;
    strongSelf.isInitiator = response.isInitiator;
    for (ARDSignalingMessage *message in response.messages) {
      if (message.type == kARDSignalingMessageTypeOffer ||
          message.type == kARDSignalingMessageTypeAnswer) {
        strongSelf.hasReceivedSdp = YES;
        [strongSelf.messageQueue insertObject:message atIndex:0];
      } else {
        [strongSelf.messageQueue addObject:message];
      }
    }
    strongSelf.webSocketURL = response.webSocketURL;
    strongSelf.webSocketRestURL = response.webSocketRestURL;
    [strongSelf registerWithColliderIfReady];
          
     [strongSelf startSignalingIfReady];
              
  }];
}

- (void)disconnect {
  if (_state == kARDAppClientStateDisconnected) {
    return;
  }
  if (self.hasJoinedRoomServerRoom) {
    [_roomServerClient leaveRoomWithRoomId:_roomId
                                  clientId:_clientId
                         completionHandler:nil];
  }
  if (_channel) {
    if (_channel.state == kARDSignalingChannelStateRegistered) {
      // Tell the other client we're hanging up.
      ARDByeMessage *byeMessage = [[ARDByeMessage alloc] init];
      [_channel sendMessage:byeMessage];
    }
    // Disconnect from collider.
    _channel = nil;
  }
  _clientId = nil;
  _roomId = nil;
  _isInitiator = NO;
  _hasReceivedSdp = NO;
  _messageQueue = [NSMutableArray array];
  _peerConnection = nil;
  self.state = kARDAppClientStateDisconnected;
}

#pragma mark - ARDSignalingChannelDelegate

- (void)channel:(id<ARDSignalingChannel>)channel
    didReceiveMessage:(ARDSignalingMessage *)message {
  switch (message.type) {
    case kARDSignalingMessageTypeOffer:
    case kARDSignalingMessageTypeAnswer:
      // Offers and answers must be processed before any other message, so we
      // place them at the front of the queue.
      _hasReceivedSdp = YES;
      [_messageQueue insertObject:message atIndex:0];
      break;
    case kARDSignalingMessageTypeCandidate:
      [_messageQueue addObject:message];
      break;
    case kARDSignalingMessageTypeBye:
      // Disconnects can be processed immediately.
      [self processSignalingMessage:message];
      return;
  }
  [self drainMessageQueueIfReady];
}

- (void)channel:(id<ARDSignalingChannel>)channel
    didChangeState:(ARDSignalingChannelState)state {
  switch (state) {
    case kARDSignalingChannelStateOpen:
      break;
    case kARDSignalingChannelStateRegistered:
      break;
    case kARDSignalingChannelStateClosed:
    case kARDSignalingChannelStateError:
      // TODO(tkchin): reconnection scenarios. Right now we just disconnect
      // completely if the websocket connection fails.
      [self disconnect];
      break;
  }
}

#pragma mark - RTCPeerConnectionDelegate
// Callbacks for this delegate occur on non-main thread and need to be
// dispatched back to main queue as needed.

- (void)peerConnection:(RTCPeerConnection *)peerConnection
    signalingStateChanged:(RTCSignalingState)stateChanged {
  NSLog(@"Signaling state changed: %d", stateChanged);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
           addedStream:(RTCMediaStream *)stream {
  dispatch_async(dispatch_get_main_queue(), ^{
    NSLog(@"Received %lu video tracks and %lu audio tracks",
        (unsigned long)stream.videoTracks.count,
        (unsigned long)stream.audioTracks.count);
    if (stream.videoTracks.count) {
      RTCVideoTrack *videoTrack = stream.videoTracks[0];
      [_delegate appClient:self didReceiveRemoteVideoTrack:videoTrack];
    }
  });
}



- (void)peerConnection:(RTCPeerConnection *)peerConnection
        removedStream:(RTCMediaStream *)stream {
  NSLog(@"Stream was removed.");
}

- (void)peerConnectionOnRenegotiationNeeded:
    (RTCPeerConnection *)peerConnection {
  //NSLog(@"WARNING: Renegotiation needed but unimplemented.");
    NSLog(@"Renegotiation");
    //[peerConnection createOfferWithDelegate:self constraints:[self defaultOfferConstraints]];
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
    iceConnectionChanged:(RTCICEConnectionState)newState {
  NSLog(@"ICE state changed: %d", newState);
  dispatch_async(dispatch_get_main_queue(), ^{
    [_delegate appClient:self didChangeConnectionState:newState];
  });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
    iceGatheringChanged:(RTCICEGatheringState)newState {
  NSLog(@"ICE gathering state changed: %d", newState);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
       gotICECandidate:(RTCICECandidate *)candidate {
  dispatch_async(dispatch_get_main_queue(), ^{
    ARDICECandidateMessage *message =
        [[ARDICECandidateMessage alloc] initWithCandidate:candidate];
    [self sendSignalingMessage:message];
  });
}

- (void)peerConnection:(RTCPeerConnection*)peerConnection
    didOpenDataChannel:(RTCDataChannel*)dataChannel {
    
    //_dataChannel = dataChannel;

}

#pragma mark - RTCSessionDescriptionDelegate
// Callbacks for this delegate occur on non-main thread and need to be
// dispatched back to main queue as needed.

- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didCreateSessionDescription:(RTCSessionDescription *)sdp
                          error:(NSError *)error {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (error) {
      NSLog(@"Failed to create session description. Error: %@", error);
      [self disconnect];
      NSDictionary *userInfo = @{
        NSLocalizedDescriptionKey: @"Failed to create session description.",
      };
      NSError *sdpError =
          [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                     code:kARDAppClientErrorCreateSDP
                                 userInfo:userInfo];
      [_delegate appClient:self didError:sdpError];
      return;
    }
      
    [_peerConnection setLocalDescriptionWithDelegate:self
                                  sessionDescription:sdp];
    ARDSessionDescriptionMessage *message =
        [[ARDSessionDescriptionMessage alloc] initWithDescription:sdp];

    [self sendSignalingMessage:message];
  });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didSetSessionDescriptionWithError:(NSError *)error {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (error) {
      NSLog(@"Failed to set session description. Error: %@", error);
      [self disconnect];
      NSDictionary *userInfo = @{
        NSLocalizedDescriptionKey: @"Failed to set session description.",
      };
      NSError *sdpError =
          [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                     code:kARDAppClientErrorSetSDP
                                 userInfo:userInfo];
      [_delegate appClient:self didError:sdpError];
      return;
    }
    // If we're answering and we've just set the remote offer we need to create
    // an answer and set the local description.
    if (!_isInitiator && !_peerConnection.localDescription) {
      RTCMediaConstraints *constraints = [self defaultAnswerConstraints];
      [_peerConnection createAnswerWithDelegate:self
                                    constraints:constraints];

    }
  });
}

#pragma mark - Private

- (BOOL)hasJoinedRoomServerRoom {
  return _clientId.length;
}

// Begins the peer connection connection process if we have both joined a room
// on the room server and tried to obtain a TURN server. Otherwise does nothing.
// A peer connection object will be created with a stream that contains local
// audio and video capture. If this client is the caller, an offer is created as
// well, otherwise the client will wait for an offer to arrive.
- (void)startSignalingIfReady {
  if (!_isTurnComplete || !self.hasJoinedRoomServerRoom) {
    return;
  }
  self.state = kARDAppClientStateConnected;

  // Create peer connection.
  RTCMediaConstraints *constraints = [self defaultPeerConnectionConstraints];
  _peerConnection = [_factory peerConnectionWithICEServers:_iceServers
                                               constraints:constraints
                                                  delegate:self];
    
  // Create AV media stream and add it to the peer connection.
  //RTCMediaStream *localStream = [self createLocalMediaStream];
  //[_peerConnection addStream:localStream];
    
    
    // DataChannelを作成
    RTCDataChannelInit *datainit = [[RTCDataChannelInit alloc] init];
    
    
    if (!_dataChannels) {
        _dataChannels = [[NSMutableArray alloc] init];
    }
    
    for (int i = 0; i < NUM_DC; ++i) {
        NSString* ch_label = [NSString stringWithFormat:@"dc%03d", i];
        NSLog(@"creating data channel #%d", i);
        
        
        datainit.isNegotiated = YES;
        datainit.isOrdered = YES;
        datainit.maxRetransmits = 3;
        datainit.maxRetransmitTimeMs = 10;
        datainit.streamId = 12 + i;
        [datainit setProtocol:@"sctp"];
        
        RTCDataChannel* dc = [_peerConnection createDataChannelWithLabel:ch_label config:datainit];
        if (dc) {
            [_dataChannels addObject:dc];
            [dc setDelegate:self];
        }
    }

    
    
    
    if (_isInitiator) {
        // Send offer.
        [_peerConnection createOfferWithDelegate:self
                                 constraints:constraints];
    } else {
        // Check if we've received an offer.
        [self drainMessageQueueIfReady];
    }
}

// Processes the messages that we've received from the room server and the
// signaling channel. The offer or answer message must be processed before other
// signaling messages, however they can arrive out of order. Hence, this method
// only processes pending messages if there is a peer connection object and
// if we have received either an offer or answer.
- (void)drainMessageQueueIfReady {
  if (!_peerConnection || !_hasReceivedSdp) {
    return;
  }
  for (ARDSignalingMessage *message in _messageQueue) {
    [self processSignalingMessage:message];
  }
  [_messageQueue removeAllObjects];
}

// Processes the given signaling message based on its type.
- (void)processSignalingMessage:(ARDSignalingMessage *)message {
  NSParameterAssert(_peerConnection ||
      message.type == kARDSignalingMessageTypeBye);
  switch (message.type) {
    case kARDSignalingMessageTypeOffer:
    case kARDSignalingMessageTypeAnswer: {
      ARDSessionDescriptionMessage *sdpMessage =
          (ARDSessionDescriptionMessage *)message;
      RTCSessionDescription *description = sdpMessage.sessionDescription;
      [_peerConnection setRemoteDescriptionWithDelegate:self
                                     sessionDescription:description];
      break;
    }
    case kARDSignalingMessageTypeCandidate: {
      ARDICECandidateMessage *candidateMessage =
          (ARDICECandidateMessage *)message;
      [_peerConnection addICECandidate:candidateMessage.candidate];
      break;
    }
    case kARDSignalingMessageTypeBye:
      // Other client disconnected.
      // TODO(tkchin): support waiting in room for next client. For now just
      // disconnect.
      [self disconnect];
      break;
  }
}

// Sends a signaling message to the other client. The caller will send messages
// through the room server, whereas the callee will send messages over the
// signaling channel.
- (void)sendSignalingMessage:(ARDSignalingMessage *)message {
  if (_isInitiator) {
    __weak ARDAppClient *weakSelf = self;
    [_roomServerClient sendMessage:message
                         forRoomId:_roomId
                          clientId:_clientId
                 completionHandler:^(ARDMessageResponse *response,
                                     NSError *error) {
      ARDAppClient *strongSelf = weakSelf;
      if (error) {
        [strongSelf.delegate appClient:strongSelf didError:error];
        return;
      }
      NSError *messageError =
          [[strongSelf class] errorForMessageResultType:response.result];
      if (messageError) {
        [strongSelf.delegate appClient:strongSelf didError:messageError];
        return;
      }
    }];
  } else {
    [_channel sendMessage:message];
  }
}

- (RTCMediaStream *)createLocalMediaStream {
  RTCMediaStream* localStream = [_factory mediaStreamWithLabel:@"ARDAMS"];
  RTCVideoTrack* localVideoTrack = [self createLocalVideoTrack];
  if (localVideoTrack) {
    [localStream addVideoTrack:localVideoTrack];
    [_delegate appClient:self didReceiveLocalVideoTrack:localVideoTrack];
  }
  [localStream addAudioTrack:[_factory audioTrackWithID:@"ARDAMSa0"]];
  return localStream;
}

- (RTCVideoTrack *)createLocalVideoTrack {
  RTCVideoTrack* localVideoTrack = nil;
  // The iOS simulator doesn't provide any sort of camera capture
  // support or emulation (http://goo.gl/rHAnC1) so don't bother
  // trying to open a local stream.
  // TODO(tkchin): local video capture for OSX. See
  // https://code.google.com/p/webrtc/issues/detail?id=3417.
#if !TARGET_IPHONE_SIMULATOR && TARGET_OS_IPHONE
  RTCMediaConstraints *mediaConstraints = [self defaultMediaStreamConstraints];
  RTCAVFoundationVideoSource *source =
      [[RTCAVFoundationVideoSource alloc] initWithFactory:_factory
                                              constraints:mediaConstraints];
  localVideoTrack =
      [[RTCVideoTrack alloc] initWithFactory:_factory
                                      source:source
                                     trackId:@"ARDAMSv0"];
#endif
  return localVideoTrack;
}

#pragma mark - Collider methods

- (void)registerWithColliderIfReady {
  if (!self.hasJoinedRoomServerRoom) {
    return;
  }
  // Open WebSocket connection.
  if (!_channel) {
    _channel =
        [[ARDWebSocketChannel alloc] initWithURL:_websocketURL
                                         restURL:_websocketRestURL
                                        delegate:self];
  }
  [_channel registerForRoomId:_roomId clientId:_clientId];
}

#pragma mark - Defaults

- (RTCMediaConstraints *)defaultMediaStreamConstraints {
  RTCMediaConstraints* constraints =
      [[RTCMediaConstraints alloc]
          initWithMandatoryConstraints:nil
                   optionalConstraints:nil];
  return constraints;
}

- (RTCMediaConstraints *)defaultAnswerConstraints {
  return [self defaultOfferConstraints];
}

- (RTCMediaConstraints *)defaultOfferConstraints {
  NSArray *mandatoryConstraints = @[
     [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"false"],
      [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:@"false"]
  ];
    
    NSArray *optional = @[
    
        [[RTCPair alloc] initWithKey:@"OfferToReceiveDataChannel" value:@"true"],
        [[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement" value:@"true"]
                          
    ];
    
  RTCMediaConstraints* constraints =
      [[RTCMediaConstraints alloc]
          initWithMandatoryConstraints:mandatoryConstraints
                   optionalConstraints:optional];
  return constraints;
}

- (RTCMediaConstraints *)defaultPeerConnectionConstraints {
    
    /*
  if (_defaultPeerConnectionConstraints) {
    return _defaultPeerConnectionConstraints;
  }
  
  RTCMediaConstraints* constraints =
      [[RTCMediaConstraints alloc]
          initWithMandatoryConstraints:nil
                   optionalConstraints:nil];
    
  return constraints;
     */
    /*
    RTCPair* audio = [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"false"];
    RTCPair* video = [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:@"false"];
    //RTCPair *rtpDatachannels = [[RTCPair alloc] initWithKey:@"RtpDataChannels" value:@"true"];
    */
    RTCPair *sctpDatachannels = [[RTCPair alloc] initWithKey:@"internalSctpDataChannels" value:@"true"];
    RTCPair *dtlsSrtpKeyAgreeement = [[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement" value:@"true"];
    
    NSArray* mandatory = @[];//@[audio, video];
    NSArray *optional = @[sctpDatachannels, dtlsSrtpKeyAgreeement];
    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc]
                                initWithMandatoryConstraints:mandatory
                                optionalConstraints:optional];
   
    return constraints;
}

- (RTCICEServer *)defaultSTUNServer {
  NSURL *defaultSTUNServerURL = [NSURL URLWithString:kARDDefaultSTUNServerUrl];
  return [[RTCICEServer alloc] initWithURI:defaultSTUNServerURL
                                  username:@""
                                  password:@""];
}

#pragma mark - Errors

+ (NSError *)errorForJoinResultType:(ARDJoinResultType)resultType {
  NSError *error = nil;
  switch (resultType) {
    case kARDJoinResultTypeSuccess:
      break;
    case kARDJoinResultTypeUnknown: {
      error = [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                         code:kARDAppClientErrorUnknown
                                     userInfo:@{
        NSLocalizedDescriptionKey: @"Unknown error.",
      }];
      break;
    }
    case kARDJoinResultTypeFull: {
      error = [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                         code:kARDAppClientErrorRoomFull
                                     userInfo:@{
        NSLocalizedDescriptionKey: @"Room is full.",
      }];
      break;
    }
  }
  return error;
}

+ (NSError *)errorForMessageResultType:(ARDMessageResultType)resultType {
  NSError *error = nil;
  switch (resultType) {
    case kARDMessageResultTypeSuccess:
      break;
    case kARDMessageResultTypeUnknown:
      error = [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                         code:kARDAppClientErrorUnknown
                                     userInfo:@{
        NSLocalizedDescriptionKey: @"Unknown error.",
      }];
      break;
    case kARDMessageResultTypeInvalidClient:
      error = [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                         code:kARDAppClientErrorInvalidClient
                                     userInfo:@{
        NSLocalizedDescriptionKey: @"Invalid client.",
      }];
      break;
    case kARDMessageResultTypeInvalidRoom:
      error = [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                         code:kARDAppClientErrorInvalidRoom
                                     userInfo:@{
        NSLocalizedDescriptionKey: @"Invalid room.",
      }];
      break;
  }
  return error;
}

#pragma mark - RTCDataChannelDelegate
- (void)channel:(RTCDataChannel *)channel didReceiveMessageWithBuffer:(RTCDataBuffer *)buffer
{
    // 受信時刻
    double recTime = [NSDate timeIntervalSinceReferenceDate];
    
    
    
    // データを取得
    ARDTransData* data = [NSKeyedUnarchiver unarchiveObjectWithData:buffer.data];
    
    if (!receivedData)
        receivedData = [[NSMutableArray alloc] init];
    //[receivedData appendData:data.data];
    [receivedData addObject:data];
   
    if (data.isFirst) {
        mean_mbps = 0.0;
        countChunk = 0;
        prevTime = recTime;
        totalProcTime = 0.0;
    }
    
    ++countChunk;
    
    // 最後のデータを処理
    //NSLog(@"%d/%d", (int)receivedData.count, (int)data.total_chunk);
    if (data.total_chunk == receivedData.count) {
        
        NSLog(@"complete!");
        // 受信したデータを並べる
        NSArray* sorted = [receivedData sortedArrayUsingSelector:@selector(compareId:)];
        NSMutableData* merged = [[NSMutableData alloc] init];
        for (ARDTransData* d in sorted) {
            [merged appendData:d.data];
        }
        
        // 転送速度を計算
        double sendingTime = recTime - prevTime - totalProcTime;
        double mbps = (((double)((int)merged.length)) / (sendingTime + DBL_MIN)) / (1024.0 * 1024.0);
        
        NSString* timeStr;
        if (data.isFirst)
            timeStr = [[NSString alloc] initWithFormat:@"計測不能"];
        else
            timeStr = [[NSString alloc] initWithFormat:@"%lf MB/s (%lf MB / %lf s)", mbps, (double)((double)merged.length / (1024.0*1024.0)), sendingTime];
        
        
        //NSLog(@"time: %lf, speed: %lf MB/s", sendingTime, mbps);
        
        
        RTCDataBuffer* buf = [[RTCDataBuffer alloc] initWithData:merged isBinary:data.isBinary];
        [_delegate appClient:self didReceiveRemoteData:buf];
        numBlocks = -1;
        //NSLog(@"complete: %lf MB/s", mean_mbps / (double)countChunk);
        
        
        NSData* timeData = [timeStr dataUsingEncoding:NSUTF8StringEncoding];
        [_delegate appClient:self didReceiveRemoteData:[[RTCDataBuffer alloc] initWithData:timeData isBinary:NO]];
        
        receivedData = nil;
        
        return;
    }
    
    // ローカルの処理時間を計算
    double procEnd = [NSDate timeIntervalSinceReferenceDate];
    totalProcTime += (procEnd - recTime);
    
}



- (void)channelDidChangeState:(RTCDataChannel *)channel
{
    
    NSLog(@"DataChannel: change State");
    NSLog(@"****************************************");
    NSLog(@"label: %@", channel.label);
    NSLog(@"reliable: %@", channel.isReliable ? @"YES":@"NO");
    NSLog(@"ordered: %@", channel.isOrdered ? @"YES":@"NO");
    NSLog(@"maxRetransTime: %d", (unsigned int)channel.maxRetransmitTime);
    NSLog(@"maxRetransmits: %d", (unsigned int)channel.maxRetransmits);
    NSLog(@"protocol: %@", channel.protocol);
    NSLog(@"isNegotiated: %@", channel.isNegotiated ? @"YES":@"NO");
    NSLog(@"streamId: %d", (int)channel.streamId);
    NSLog(@"state: %u", channel.state);
    NSLog(@"buffer amount: %d", (int)channel.bufferedAmount);
    
    int num_dc = (int)_dataChannels.count;
    for (int i = 0; i < num_dc; ++i) {
        RTCDataChannel* dc = [_dataChannels objectAtIndex:i];
        if ([channel.label isEqualToString:dc.label]) {
            [_dataChannels removeObjectAtIndex:i];
            [_dataChannels addObject:channel];
            break;
        }
    }

    
    [_delegate appClient:self didChangeDataChannelState:channel.state];
}

- (NSMutableArray *)splitData:(NSData *)data
{
    NSMutableArray* res = [[NSMutableArray alloc] init];
    NSUInteger length = [data length];
    NSUInteger chunkSize = MAX_BLOCK_SIZE;
    NSRange dataRange;
    
    dataRange.location = 0;
    do {
        
        NSUInteger thisChunkSize =
            ((length - dataRange.location) > chunkSize) ? chunkSize : (length-dataRange.location);
        dataRange.length = thisChunkSize;
        NSData* chunk = [data subdataWithRange:dataRange];
        [res addObject:chunk];
        
        dataRange.location += thisChunkSize;
        
    } while (dataRange.location < length);
    
    return res;
}

- (void)sendData:(NSData *)data isBinary:(BOOL)isBinary userId:(NSString *)userId
{
    //[_dataChannel sendData:[[RTCDataBuffer alloc] initWithData:data isBinary:isBinary]];
    
    NSRange dataRange;
    NSUInteger dataSize = data.length;
    NSUInteger dataSplitCount = dataSize / MAX_BLOCK_SIZE;
    //NSUInteger restChunk = ((dataSize % MAX_BLOCK_SIZE)==0) ? 0 : 1;
    NSLog(@"dataSize: %d", (int)data.length);
    NSLog(@"count: %d", (int)dataSplitCount);
    
    //
    // データ本体を送信
    //
    dataRange.length = MAX_BLOCK_SIZE;
    dataRange.location = 0;
    NSMutableArray *dataArray = [self splitData:data];
    
    int numChunk = (int)dataArray.count;
    uint32_t count = 0;
    NSMutableArray* bufferArray = [[NSMutableArray alloc] init];
    for (NSData* d in dataArray) {

        ARDTransData* td = [[ARDTransData alloc] init];
        td.data = [[NSData alloc] initWithData:d];
        td.isBinary = isBinary;
        td.isLast = (count == (int)dataSplitCount);
        td.isFirst = (count == 0);
        td.chunk_id = count;
        td.total_chunk = (uint32_t)numChunk;
        
        NSData* data = [NSKeyedArchiver archivedDataWithRootObject:td];
        
        RTCDataBuffer* buffer = [[RTCDataBuffer alloc] initWithData:data isBinary:isBinary];
        [bufferArray addObject:buffer];
        ++count;
    }
    
    count = 0;
    for (RTCDataBuffer* buffer in bufferArray) {
        RTCDataChannel* dc = [_dataChannels objectAtIndex:count%NUM_DC];
        
        if (![dc sendData:buffer]) {
            NSLog(@"sending error");
            break;
        }
        else {
            [_delegate appClient:self didChangeDataProgress:(float)count/numChunk];
        }
        ++count;
    }
    
    [_delegate appClient:self didChangeDataProgress:1.0f];

}


@end
