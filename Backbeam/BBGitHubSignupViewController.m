//
//  BBGitHubSignupViewController.m
//  Communities
//
//  Created by Alberto Gimeno Brieba on 2/19/14.
//  Copyright (c) 2014 Level Apps S.L. All rights reserved.
//

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
#import "BBGitHubSignupViewController.h"
#import "BBUtils.h"
#import "NSDictionary+SanityChecks.h"
#import "AFNetworking.h"
#import "Backbeam.h"

@interface BBGitHubSignupViewController () <UIWebViewDelegate>

@property (nonatomic, copy) SuccessSocialSignupWebviewBlock success;
@property (nonatomic, copy) FailureSocialSignupBlock failure;
@property (nonatomic, copy) ProgressSocialBlock progress;

@property (nonatomic, assign) BOOL waitingToFinish;

@property (nonatomic, strong) NSString *stateParam;

@end

@implementation BBGitHubSignupViewController

#define GITHUB_AUTHORIZE_URL    @"https://github.com/login/oauth/authorize"
#define GITHUB_ACCESS_TOKEN_URL @"https://github.com/login/oauth/access_token"

- (id)init
{
    self = [super init];
    if (self) {
        self.scope = @"";
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
    [params setObject:self.clientId    forKey:@"client_id"];
    [params setObject:self.scope       forKey:@"scope"];
    [params setObject:self.stateParam  forKey:@"state"];
    [params setObject:self.callbackURL forKey:@"redirect_uri"];
    
    self.waitingToFinish = YES;
    if (self.progress) {
        self.progress(BBSocialSignupProgressLoadingAuthorizationPage);
    }

    NSString *urlString = [NSString stringWithFormat:@"%@?%@", GITHUB_AUTHORIZE_URL, [BBUtils queryString:params]];
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
    if ([request.URL.description hasPrefix:self.callbackURL]) {
        NSDictionary *values = [BBUtils parseQueryString:request.URL.query];
        NSString *code = [values stringForKey:@"code"];
        NSString *state = [values stringForKey:@"state"];
        
        if (!code || !state) {
            if (self.failure) {
                self.failure([BBError errorWithStatus:@"GitHubInvalidResponse" result:nil]);
            }
        } else if (![self.stateParam isEqualToString:state]) {
            if (self.failure) {
                self.failure([BBError errorWithStatus:@"GitHubInvalidState" result:nil]);
            }
        } else {
            NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
            [params setObject:code              forKey:@"code"];
            [params setObject:self.clientId     forKey:@"client_id"];
            [params setObject:self.clientSecret forKey:@"client_secret"];
            [params setObject:self.callbackURL  forKey:@"redirect_uri"];
            
            NSString *urlString = [NSString stringWithFormat:@"%@?%@", GITHUB_ACCESS_TOKEN_URL, [BBUtils queryString:params]];
            NSURLRequest *req = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
            
            if (self.progress) {
                self.progress(BBSocialSignupProgressAuthorizating);
            }
            
            AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:req];
            [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
                
                NSString *bodyString = operation.responseString;
                
                NSDictionary *values = [BBUtils parseQueryString:bodyString];
                NSString *accessToken = [values stringForKey:@"access_token"];
                if (!accessToken) {
                    if (self.failure) {
                        self.failure([BBError errorWithStatus:@"GitHubMissingAccessToken" result:nil]);
                    }
                    return;
                }
                
                if (self.progress) {
                    self.progress(BBSocialSignupProgressRedirecting);
                }

                [Backbeam gitHubSignupWithAccessToken:accessToken success:^(BBObject *user, BOOL isNew) {
                    if (self.success) {
                        self.success(user, @{ @"accesToken": accessToken }, isNew);
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
    
    if (request.URL.query && [request.URL.query rangeOfString:@"error_description="].location != NSNotFound) {
        NSDictionary *values = [BBUtils parseQueryString:request.URL.query];
        NSString *errorDescription = [values stringForKey:@"error_description"];
        
        if (self.failure) {
            self.failure([BBError errorWithStatus:errorDescription result:nil]);
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
