//
//  TopViewController.m
//  AppRTCDemo
//
//  Created by MotohiroNAKAMURA on 2015/07/07.
//
//

#import "TopViewController.h"
#import "ARDChatViewController.h"

@interface TopViewController ()

@end

@implementation TopViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)editingDidEnd:(id)sender {
    
    [self resignFirstResponder];
    
}

- (IBAction)pushJoin:(id)sender {
    
    // ルーム番号を取得
    NSString* roomText = [self.roomText text];
    if ([roomText isEqualToString:@""]) return;
    
    // 画面遷移
    ARDChatViewController *chatView = [[self storyboard] instantiateViewControllerWithIdentifier:@"ChatView"];
    [self presentViewController:chatView animated:YES completion:nil];
    
}
@end
