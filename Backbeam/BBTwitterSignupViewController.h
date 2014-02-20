//
//  BBTwitterLoginViewController.h
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 17/08/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)

#import <UIKit/UIKit.h>
#import "BBObject.h"
#import "BBOAuth1a.h"
#import "Common.h"

@class BackbeamSession;

@interface BBTwitterSignupViewController : UIViewController

@property (strong, nonatomic) UIWebView *webview;

@property (strong, nonatomic) NSString *join;
@property (strong, nonatomic) NSArray *params;

@property (nonatomic, strong) BBOAuth1a *oauthClient;

- (id)initWith:(BackbeamSession*)session oauthClient:(BBOAuth1a*)oauthClient;

- (void)signup:(SuccessSocialSignupWebviewBlock)success
       failure:(FailureSocialSignupBlock)failure;

- (void)signup:(SuccessSocialSignupWebviewBlock)success
       failure:(FailureSocialSignupBlock)failure
      progress:(ProgressSocialBlock)progress;

@end

#endif
