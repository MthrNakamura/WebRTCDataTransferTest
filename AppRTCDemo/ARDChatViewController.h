//
//  ARDChatViewController.h
//  AppRTCDemo
//
//  Created by MotohiroNAKAMURA on 2015/07/07.
//
//

#import <UIKit/UIKit.h>
#import "JSQMessagesViewController/JSQMessages.h"

@interface ARDChatViewController : JSQMessagesViewController 


@property (strong, nonatomic) NSString* roomText;


@property (strong, nonatomic) NSMutableArray *messages;
@property (strong, nonatomic) JSQMessagesBubbleImage *incomingBubble;
@property (strong, nonatomic) JSQMessagesBubbleImage *outgoingBubble;
@property (strong, nonatomic) JSQMessagesAvatarImage *incomingAvatar;
@property (strong, nonatomic) JSQMessagesAvatarImage *outgoingAvatar;


@end
