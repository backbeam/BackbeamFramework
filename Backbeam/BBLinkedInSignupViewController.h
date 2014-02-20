//
//  BBLinkedInSignupViewController.h
//  Communities
//
//  Created by Alberto Gimeno Brieba on 2/19/14.
//  Copyright (c) 2014 Level Apps S.L. All rights reserved.
//

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
#import "Common.h"

@interface BBLinkedInSignupViewController : UIViewController

@property (nonatomic, strong) UIWebView *webview;

@property (nonatomic, strong) NSString *clientId;
@property (nonatomic, strong) NSString *clientSecret;
@property (nonatomic, strong) NSString *scope;

- (void)signup:(SuccessSocialSignupWebviewBlock)success
       failure:(FailureSocialSignupBlock)failure
      progress:(ProgressSocialBlock)progress;

@end
#endif
