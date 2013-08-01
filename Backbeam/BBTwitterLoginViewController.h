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

@class BackbeamSession;

@interface BBTwitterLoginViewController : UIViewController <UIWebViewDelegate>

@property (strong, nonatomic) IBOutlet UIWebView *webview;

- (id)initWith:(BackbeamSession*)session oauthClient:(BBOAuth1a*)oauthClient;

- (void)signup:(SuccessTwitterBlock)success
       failure:(FailureTwitterBlock)failure;

- (void)signup:(SuccessTwitterBlock)success
       failure:(FailureTwitterBlock)failure
      progress:(ProgressTwitterBlock)progress;

@end

#endif
