//
//  BBTwitterLoginViewController.h
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 17/08/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BBObject.h"

@class BackbeamSession;

@interface BBTwitterLoginViewController : UIViewController <UIWebViewDelegate>

@property (strong, nonatomic) IBOutlet UIWebView *webview;
@property (nonatomic, strong) NSString* twitterConsumerKey;
@property (nonatomic, strong) NSString* twitterConsumerSecret;

- (id)initWith:(BackbeamSession*)session;

- (void)signup:(SuccessTwitterBlock)success
       failure:(FailureTwitterBlock)failure;

@end
