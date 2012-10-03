//
//  BBTwitterLoginViewController.h
//  Callezeta
//
//  Created by Alberto Gimeno Brieba on 17/08/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BBObject.h"

typedef void(^SuccessTwitterBlock)(BBObject* user, NSDictionary* extraInfo);
typedef void(^FailureTwitterBlock)(NSError* err);

@interface BBTwitterLoginViewController : UIViewController <UIWebViewDelegate>

@property (strong, nonatomic) IBOutlet UIWebView *webview;
@property (nonatomic, strong) NSString* twitterConsumerKey;
@property (nonatomic, strong) NSString* twitterConsumerSecret;

- (void)signup:(SuccessTwitterBlock)success failure:(FailureTwitterBlock)failure;

@end
