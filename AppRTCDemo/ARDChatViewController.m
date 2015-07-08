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

@interface ARDChatViewController () <ARDAppClientDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
{
    ARDAppClient *_client;
    UIAlertController* alert;
    NSTimer *timer;
    BOOL finishConnecting;
}

@end

@implementation ARDChatViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    self.inputToolbar.contentView.leftBarButtonItem = nil;//[JSQMessagesToolbarButtonFactory defaultAccessoryButtonItem];
    
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
    
    
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.inputToolbar.contentView.rightBarButtonItem.enabled = NO;
    finishConnecting = NO;
    [SVProgressHUD show];
    
    
    _client = [[ARDAppClient alloc] initWithDelegate:self];
    [_client connectToRoomWithId:self.roomText options:nil];
    
    timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(receiveAutoMessage) userInfo:nil repeats:YES];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -JSQMessagesViewControllerDelegate

- (void)didPressSendButton:(UIButton *)button withMessageText:(NSString *)text senderId:(NSString *)senderId senderDisplayName:(NSString *)senderDisplayName date:(NSDate *)date
{
    // 新しいメッセージデータを追加する
    JSQMessage *message = [JSQMessage messageWithSenderId:senderId
                                              displayName:senderDisplayName
                                                     text:text];
    
    [self.messages addObject:message];
    // メッセージの送信処理を完了する (画面上にメッセージが表示される)
    [self finishSendingMessageAnimated:YES];
    
    NSData* data = [message.text dataUsingEncoding:NSUTF8StringEncoding];
    [_client sendData:data];

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

- (void)didPressAccessoryButton:(UIButton *)sender
{
    
     [_client sendData:[@"chatprotocol://photo" dataUsingEncoding:NSUTF8StringEncoding]];
    /*
    // カメラが使用可能かどうか判定する
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        NSLog(@"カメラ機能へアクセスできません");
        return;
    }
    ®
    // UIImagePickerControllerのインスタンスを生成
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    
    // デリゲートを設定
    imagePickerController.delegate = self;
    
    // 画像の取得先をカメラに設定
    imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
    
    // 撮影画面をモーダルビューとして表示する
    [self presentViewController:imagePickerController animated:YES completion:nil];
    */
    
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
            [_client disconnect];
            [self dismissViewControllerAnimated:YES completion:nil];
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
    [_client disconnect];
}

- (void)appClient:(ARDAppClient *)client didReceiveRemoteData:(RTCDataBuffer *)buffer
{
    
    NSString* msg = [[NSString alloc] initWithData:buffer.data encoding:NSUTF8StringEncoding];
    NSLog(@"received msg: %@", msg);
    
    // 新しいメッセージデータを追加する
    JSQMessage *message = [JSQMessage messageWithSenderId:@"user2"
                                              displayName:@"underscore"
                                                     text:msg];
    [self.messages addObject:message];
}

/*
 
 kRTCDataChannelStateConnecting,
 kRTCDataChannelStateOpen,
 kRTCDataChannelStateClosing,
 kRTCDataChannelStateClosed
 
 */

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
        
        NSData* data = [[NSData alloc] initWithData:UIImagePNGRepresentation( image )];
        JSQMessagesBubbleImage* message = [[JSQMessagesBubbleImage alloc]initWithMessageBubbleImage:image highlightedImage:image];
        [self.messages addObject:message];
        
        [self finishSendingMessageAnimated:YES];
        
        // 画像を送信することを知らせる
        [_client sendData:data];
        
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
