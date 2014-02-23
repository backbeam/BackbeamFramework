//
//  BBLinkedInSignupViewController.m
//  Communities
//
//  Created by Alberto Gimeno Brieba on 2/19/14.
//  Copyright (c) 2014 Level Apps S.L. All rights reserved.
//

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)

#import "BBLinkedInSignupViewController.h"
#import "BBUtils.h"
#import "NSDictionary+SanityChecks.h"
#import "AFNetworking.h"
#import "Backbeam.h"

@interface BBLinkedInSignupViewController () <UIWebViewDelegate>

@property (nonatomic, copy) SuccessSocialSignupWebviewBlock success;
@property (nonatomic, copy) FailureSocialSignupBlock failure;
@property (nonatomic, copy) ProgressSocialBlock progress;

@property (nonatomic, assign) BOOL waitingToFinish;

@property (nonatomic, strong) NSString *stateParam;

@end

@implementation BBLinkedInSignupViewController

#define LINKEDIN_AUTHORIZE_URL    @"https://www.linkedin.com/uas/oauth2/authorization"
#define LINKEDIN_ACCESS_TOKEN_URL @"https://www.linkedin.com/uas/oauth2/accessToken"
#define LINKEDIN_CALLBACK_URL     @"http://localhost/sign-in-with-linkedin/"

- (id)init
{
    self = [super init];
    if (self) {
        self.scope = @"r_basicprofile";
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    
    self.webview = [[UIWebView alloc] init];
    self.webview.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webview.delegate = self;
    
    self.view = self.webview;
    if (self.success || self.failure || self.progress) {
        [self startSignup];
    }
}

- (void)startSignup {
    if (!self.clientId || !self.clientSecret || !self.scope) {
        if (self.failure) {
            [[NSOperationQueue currentQueue] addOperationWithBlock:^{
                self.failure([BBError errorWithStatus:@"InvalidAPIKeysOrScope" result:nil]);
            }];
        }
        return;
    }
    
    self.stateParam = [BBUtils nonce];
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    [params setObject:@"code"               forKey:@"response_type"];
    [params setObject:self.clientId         forKey:@"client_id"];
    [params setObject:self.scope            forKey:@"scope"];
    [params setObject:self.stateParam       forKey:@"state"];
    [params setObject:LINKEDIN_CALLBACK_URL forKey:@"redirect_uri"];
    
    self.waitingToFinish = YES;
    if (self.progress) {
        self.progress(BBSocialSignupProgressLoadingAuthorizationPage);
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@?%@", LINKEDIN_AUTHORIZE_URL, [BBUtils queryString:params]];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
    [self.webview loadRequest:request];
}

- (void)signup:(SuccessSocialSignupWebviewBlock)success failure:(FailureSocialSignupBlock)failure progress:(ProgressSocialBlock)progress {
    self.success = success;
    self.failure = failure;
    self.progress = progress;
    
    if (self.webview) {
        [self startSignup];
    }
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    if ([request.URL.description hasPrefix:LINKEDIN_CALLBACK_URL]) {
        NSDictionary *values = [BBUtils parseQueryString:request.URL.query];
        NSString *code = [values stringForKey:@"code"];
        NSString *state = [values stringForKey:@"state"];
        
        if (!code || !state) {
            if (self.failure) {
                self.failure([BBError errorWithStatus:@"LinkedInInvalidResponse" result:nil]);
            }
        } else if (![self.stateParam isEqualToString:state]) {
            if (self.failure) {
                self.failure([BBError errorWithStatus:@"LinkedInInvalidState" result:nil]);
            }
        } else {
            NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
            [params setObject:@"authorization_code" forKey:@"grant_type"];
            [params setObject:code                  forKey:@"code"];
            [params setObject:self.clientId         forKey:@"client_id"];
            [params setObject:self.clientSecret     forKey:@"client_secret"];
            [params setObject:LINKEDIN_CALLBACK_URL forKey:@"redirect_uri"];
            
            NSString *urlString = [NSString stringWithFormat:@"%@?%@", LINKEDIN_ACCESS_TOKEN_URL, [BBUtils queryString:params]];
            
            if (self.progress) {
                self.progress(BBSocialSignupProgressAuthorizating);
            }
            
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
            AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
            operation.responseSerializer = [AFJSONResponseSerializer serializer];
            
            [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id JSON) {
                if (![JSON isKindOfClass:[NSDictionary class]]) {
                    if (self.failure) {
                        self.failure([BBError errorWithStatus:@"LinkedInInvalidResponseFormat" result:nil]);
                    }
                    return;
                }
                NSDictionary *dict = (NSDictionary*)JSON;
                NSString *accessToken = [dict stringForKey:@"access_token"];
                if (!accessToken) {
                    if (self.failure) {
                        self.failure([BBError errorWithStatus:@"LinkedInMissingAccessToken" result:nil]);
                    }
                    return;
                }
                
                if (self.progress) {
                    self.progress(BBSocialSignupProgressRedirecting);
                }
                
                [Backbeam linkedInSignupWithAccessToken:accessToken success:^(BBObject *user, BOOL isNew) {
                    if (self.success) {
                        self.success(user, @{ @"accessToken": accessToken }, isNew);
                    }
                } failure:^(NSError *err) {
                    if (self.failure) {
                        self.failure(err);
                    }
                }];
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                if (self.failure) {
                    self.failure(error);
                }
            }];
            
            [operation start];
        }
        
        return NO;
    }
    return YES;
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if (self.progress && self.waitingToFinish) {
        self.waitingToFinish = NO;
        self.progress(BBSocialSignupProgressLoadedAuthorizationPage);
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end

#endif
