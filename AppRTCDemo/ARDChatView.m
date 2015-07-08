//
//  ARDChatView.m
//  AppRTCDemo
//
//  Created by MotohiroNAKAMURA on 2015/07/07.
//
//

#import "ARDChatView.h"


@implementation ARDChatView


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

+ (id)loadFromNib
{
    NSString *nibName = NSStringFromClass([self class]);
    UINib *nib = [UINib nibWithNibName:nibName bundle:nil];
    return [[nib instantiateWithOwner:nil options:nil] objectAtIndex:0];
}

@end
