//
//  BBGitHubSignupViewController.h
//  Communities
//
//  Created by Alberto Gimeno Brieba on 2/19/14.
//  Copyright (c) 2014 Level Apps S.L. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Common.h"

@interface BBGitHubSignupViewController : UIViewController

@property (nonatomic, strong) UIWebView *webview;

@property (nonatomic, strong) NSString *clientId;
@property (nonatomic, strong) NSString *clientSecret;
@property (nonatomic, strong) NSString *callbackURL;
@property (nonatomic, strong) NSString *scope;

- (void)signup:(SuccessSocialSignupWebviewBlock)success
       failure:(FailureSocialSignupBlock)failure
      progress:(ProgressSocialBlock)progress;

@end
