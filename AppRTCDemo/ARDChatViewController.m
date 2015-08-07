//
//  ARDChatViewController.m
//  AppRTCDemo
//
//  Created by MotohiroNAKAMURA on 2015/07/07.
//
//

#import "ARDChatViewController.h"
#import "ARDChatView.h"
#import "ARDAppClient.h"
#import <WebRTC/RTCDataChannel.h>
#import "SVProgressHUD.h"

#import "ARDAppDelegate.h"

#define NUM_SHOW_MSG 4

@interface ARDChatViewController () <ARDAppClientDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
{
    //ARDAppClient *_client;
    UIAlertController* alert;
    NSTimer *timer;
    BOOL finishConnecting;
    BOOL flg_choosing_media;
    
    ARDAppDelegate *ard_delegate;
}

@end

@implementation ARDChatViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    self.inputToolbar.contentView.leftBarButtonItem = [JSQMessagesToolbarButtonFactory defaultAccessoryButtonItem];
    
    // ① 自分の senderId, senderDisplayName を設定
    self.senderId = @"user1";
    self.senderDisplayName = @"classmethod";
    // ② MessageBubble (背景の吹き出し) を設定
    JSQMessagesBubbleImageFactory *bubbleFactory = [JSQMessagesBubbleImageFactory new];
    self.incomingBubble = [bubbleFactory  incomingMessagesBubbleImageWithColor:[UIColor jsq_messageBubbleLightGrayColor]];
    self.outgoingBubble = [bubbleFactory  outgoingMessagesBubbleImageWithColor:[UIColor jsq_messageBubbleGreenColor]];
    // ③ アバター画像を設定
    self.incomingAvatar = [JSQMessagesAvatarImageFactory avatarImageWithImage:[UIImage imageNamed:@"user_icon_1.png"] diameter:64];
    self.outgoingAvatar = [JSQMessagesAvatarImageFactory avatarImageWithImage:[UIImage imageNamed:@"user_icon_2.png"] diameter:64];
    // ④ メッセージデータの配列を初期化
    self.messages = [NSMutableArray array];
    
    flg_choosing_media = NO;
    
    ard_delegate = [[UIApplication sharedApplication] delegate];
    
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.inputToolbar.contentView.rightBarButtonItem.enabled = NO;
    finishConnecting = NO;
    [SVProgressHUD show];
    
    
    [ard_delegate.client setDelegate:self];
    [ard_delegate.client connectToRoomWithId:self.roomText options:nil];
    
    timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(receiveAutoMessage) userInfo:nil repeats:YES];
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    NSLog(@"view will dissapear");
    [ard_delegate.client setDelegate:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)unableToolBar
{
    self.inputToolbar.contentView.rightBarButtonItem.enabled = NO;
    self.inputToolbar.contentView.leftBarButtonItem.enabled = NO;
}

- (void)enableToolBar
{
    self.inputToolbar.contentView.rightBarButtonItem.enabled = YES;
    self.inputToolbar.contentView.leftBarButtonItem.enabled = YES;
}

#pragma mark -JSQMessagesViewControllerDelegate

- (void)didPressSendButton:(UIButton *)button withMessageText:(NSString *)text senderId:(NSString *)senderId senderDisplayName:(NSString *)senderDisplayName date:(NSDate *)date
{
    [self unableToolBar];
    
    // 新しいメッセージデータを追加する
    JSQMessage *message = [JSQMessage messageWithSenderId:senderId
                                              displayName:senderDisplayName
                                                     text:text];
    
    if ([self.messages count] == NUM_SHOW_MSG) {
        [self.messages removeObjectAtIndex:0];
    }
    [self.messages addObject:message];
    
    [SVProgressHUD showProgress:0.0f];
    // メッセージの送信処理を完了する (画面上にメッセージが表示される)
    //[self finishSendingMessageAnimated:YES];
    
    NSData* data = [message.text dataUsingEncoding:NSUTF8StringEncoding];
    [ard_delegate.client sendData:data isBinary:NO userId:self.senderId];

}


//
// 画像を送信
//
- (void)didPressAccessoryButton:(UIButton *)sender
{
    [self unableToolBar];
    
    UIImage* image = [UIImage imageNamed:@"image_mediam.jpg"];
    JSQPhotoMediaItem* pmi = [[JSQPhotoMediaItem alloc] initWithImage:image];
    JSQMessage *message = [JSQMessage messageWithSenderId:self.senderId displayName:self.senderDisplayName media:pmi];
    if ([self.messages count] == NUM_SHOW_MSG) {
        [self.messages removeObjectAtIndex:0];
    }
    [self.messages addObject:message];
    
    NSData* data = [[NSData alloc] initWithData:UIImagePNGRepresentation( image )];
    [ard_delegate.client sendData:data isBinary:YES userId:self.senderId];
    
    [SVProgressHUD showProgress:0.0f];
    image = nil;
}

- (id<JSQMessageData>)collectionView:(JSQMessagesCollectionView *)collectionView messageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.messages objectAtIndex:indexPath.item];
}

- (id<JSQMessageBubbleImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView messageBubbleImageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    JSQMessage *message = [self.messages objectAtIndex:indexPath.item];
    if ([message.senderId isEqualToString:self.senderId]) {
        return self.outgoingBubble;
    }
    return self.incomingBubble;
}

// ③ アイテムごとのアバター画像を返す
- (id<JSQMessageAvatarImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView avatarImageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    JSQMessage *message = [self.messages objectAtIndex:indexPath.item];
    if ([message.senderId isEqualToString:self.senderId]) {
        return self.outgoingAvatar;
    }
    return self.incomingAvatar;
}

#pragma mark - UICollectionViewDataSource

// ④ アイテムの総数を返す
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.messages.count;
}

#pragma mark - Auto Message

// ⑥ 返信メッセージを受信する (自動)
- (void)receiveAutoMessage
{
    // メッセージの受信処理を完了する (画面上にメッセージが表示される)
    [self finishReceivingMessageAnimated:YES];
    
    if (finishConnecting) {
        [SVProgressHUD dismiss];
        self.inputToolbar.contentView.rightBarButtonItem.enabled = YES;
    }
}

- (void)didFinishMessageTimer:(NSTimer*)timer
{
    // 効果音を再生する
    //[JSQSystemSoundPlayer jsq_playMessageSentSound];
    
    
    // メッセージの受信処理を完了する (画面上にメッセージが表示される)
    [self finishReceivingMessageAnimated:YES];
}



// ================================
//  以下、AppClientDelegateメソッド
// ================================

#pragma mark -ARDAppClientDelegate


- (void)appClient:(ARDAppClient *)client
   didChangeState:(ARDAppClientState)state {
    switch (state) {
        case kARDAppClientStateConnected:
            NSLog(@"Client connected.");
            break;
        case kARDAppClientStateConnecting:
            NSLog(@"Client connecting.");
            break;
        case kARDAppClientStateDisconnected:
            NSLog(@"Client disconnected.");
            break;
    }
}

- (void)appClient:(ARDAppClient *)client
didChangeConnectionState:(RTCICEConnectionState)state {
    NSLog(@"ICE state changed: %d", state);
    switch (state) {
        case RTCICEConnectionNew:
        case RTCICEConnectionConnected:
        case RTCICEConnectionCompleted:
            break;
        case RTCICEConnectionFailed:
        case RTCICEConnectionDisconnected:
        case RTCICEConnectionClosed:
            if (!flg_choosing_media) {
                [ard_delegate.client disconnect];
                [self dismissViewControllerAnimated:YES completion:nil];
            }
            break;
            
        default:
            break;
    }
    
}

- (void)appClient:(ARDAppClient *)client
didReceiveLocalVideoTrack:(RTCVideoTrack *)localVideoTrack {
    
}

- (void)appClient:(ARDAppClient *)client
didReceiveRemoteVideoTrack:(RTCVideoTrack *)remoteVideoTrack {
    
}

- (void)appClient:(ARDAppClient *)client
         didError:(NSError *)error {
    [ard_delegate.client disconnect];
}

- (void)processRemoteText:(NSData *)data
{
    
    NSString* msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    // 新しいメッセージデータを追加する
    JSQMessage *message = [JSQMessage messageWithSenderId:@"user2"
                                              displayName:@"underscore"
                                                     text:msg];
    if ([self.messages count] == NUM_SHOW_MSG) {
        [self.messages removeObjectAtIndex:0];
    }
    [self.messages addObject:message];
    
}

- (void)processRemotePhoto:(NSData *)data
{
    UIImage* image = [[UIImage alloc] initWithData:data];
    JSQPhotoMediaItem* pmi = [[JSQPhotoMediaItem alloc] initWithImage:image];
    
    JSQMessage* message = [JSQMessage messageWithSenderId:@"user2" displayName:@"underscore" media:pmi];
    if ([self.messages count] == NUM_SHOW_MSG) {
        [self.messages removeObjectAtIndex:0];
    }
    [self.messages addObject:message];
    
    image = nil;
}

- (void)processRemoteVideo:(NSData *)data
{
}

- (void)appClient:(ARDAppClient *)client didReceiveRemoteData:(RTCDataBuffer *)buffer
{
    if (buffer.isBinary) {
        // バイナリデータ
        [self processRemotePhoto:buffer.data];
    }
    else {
        // テキストデータ
        [self processRemoteText:buffer.data];
    }
}

- (void)appClient:(ARDAppClient *)client didChangeDataProgress:(float)progress
{
    [SVProgressHUD showProgress:progress];
    NSLog(@"progress: %f", progress);
    if (progress == 1.0f) {
        
        [SVProgressHUD dismiss];
        
        
        [self enableToolBar];
        [self finishSendingMessageAnimated:YES];
    }
}


- (void)appClient:(ARDAppClient *)client didChangeDataChannelState:(RTCDataChannelState)state
{
    switch (state) {
        case kRTCDataChannelStateConnecting:
            NSLog(@"connecting");
            finishConnecting = NO;
            break;
        case kRTCDataChannelStateOpen:
            NSLog(@"data channel open");
            finishConnecting = YES;
            break;
            
        case kRTCDataChannelStateClosing:
        case kRTCDataChannelStateClosed:
            NSLog(@"closing or closed");
            finishConnecting = YES;
            break;
            
        default:
            break;
    }
}



#pragma mark -UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *image = (UIImage *)[info objectForKey:UIImagePickerControllerOriginalImage];
    if (image != nil) {
        
        // 写真を送信
        NSData* data = [[NSData alloc] initWithData:UIImagePNGRepresentation( image )];
        JSQPhotoMediaItem* pmi = [[JSQPhotoMediaItem alloc] initWithImage:image];
        JSQMessage *message = [JSQMessage messageWithSenderId:self.senderId displayName:self.senderDisplayName media:pmi];
        [self.messages addObject:message];
        
        // 画像を送信することを知らせる
        [ard_delegate.client sendData:data isBinary:NO userId:self.senderId];
        
        
        [self finishSendingMessageAnimated:YES];
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    
}

#pragma mark -UINavigationControllerDelegate
- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    
}

@end
