//
//  TopViewController.h
//  AppRTCDemo
//
//  Created by MotohiroNAKAMURA on 2015/07/07.
//
//

#import <UIKit/UIKit.h>

@interface TopViewController : UIViewController

@property (strong, nonatomic) IBOutlet UITextField *roomText;
- (IBAction)editingDidEnd:(id)sender;
- (IBAction)pushJoin:(id)sender;



@end
