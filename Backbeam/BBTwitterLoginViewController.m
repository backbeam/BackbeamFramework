//
//  BBTwitterLoginViewController.m
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 17/08/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)

#import "BBTwitterLoginViewController.h"
#import "AFNetworking.h"
#import "BBUtils.h"
#import "NSData+Base64.h"
#import "Backbeam.h"

#define TWITTER_REQUEST_TOKEN_URL @"https://api.twitter.com/oauth/request_token"
#define TWITTER_AUTHORIZE_URL     @"https://api.twitter.com/oauth/authorize"
#define TWITTER_ACCESS_TOKEN_URL  @"https://api.twitter.com/oauth/access_token"
#define CALLBACK_URL              @"bb://localhost/sign-in-with-twitter/"

@interface BBTwitterLoginViewController ()

@property (nonatomic, copy) SuccessTwitterBlock success;
@property (nonatomic, copy) FailureTwitterBlock failure;
@property (nonatomic, copy) ProgressTwitterBlock progress;

@property (nonatomic, strong) BackbeamSession* _session;

@property (nonatomic, assign) BOOL waitingToFinish;

@end

@implementation BBTwitterLoginViewController

@synthesize webview;

- (id)init
{
    self = [super init];
    if (self) {
        [NSException raise:@"Use [Backbeam twitterLoginViewController] to create a BBTwitterLoginViewController" format:nil];
    }
    return self;
}

- (id)initWith:(BackbeamSession*)session oauthClient:(BBOAuth1a*)oauthClient
{
    self = [super init];
    if (self) {
        self._session = session;
        self.oauthClient = oauthClient;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.webview.scrollView setDelaysContentTouches:NO];
}

- (void)signup:(SuccessTwitterBlock)success failure:(FailureTwitterBlock)failure {
    [self signup:success failure:failure progress:nil];
}

- (void)signup:(SuccessTwitterBlock)success failure:(FailureTwitterBlock)failure progress:(ProgressTwitterBlock)progress {
    self.success = success;
    self.failure = failure;
    self.progress = progress;
    
    self.waitingToFinish = NO;
    
    if (!self.oauthClient) {
        if (self.failure) {
            [[NSOperationQueue currentQueue] addOperationWithBlock:^{
                self.failure([BBError errorWithStatus:@"MissingTwitterKeys" result:nil]);
            }];
        }
        return;
    }
    
    if (self.progress) {
        self.progress(BBTwitterProgressLoadingAuthorizationPage);
    }
    
    NSURLRequest* req = [self.oauthClient signedRequestWithMethod:@"POST"
                                                          baseURL:TWITTER_REQUEST_TOKEN_URL
                                                           params:nil
                                                             body:nil
                                                         callback:CALLBACK_URL];
    
    AFHTTPRequestOperation* operation = [[AFHTTPRequestOperation alloc] initWithRequest:req];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation* op, id response) {
        NSString* body = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
        NSDictionary* bodyParams = [BBUtils parseQueryString:body];
        self.oauthClient.oauthToken       = [bodyParams objectForKey:@"oauth_token"];
        self.oauthClient.oauthTokenSecret = [bodyParams objectForKey:@"oauth_token_secret"];
        
        if (!self.oauthClient.oauthToken || !self.oauthClient.oauthTokenSecret) {
            if (self.failure) {
                self.failure([BBError errorWithStatus:@"UnexpectedTwitterResponse" result:response]);
            }
            return;
        }
        
        self.waitingToFinish = YES;
        NSString* url = [NSString stringWithFormat:@"https://api.twitter.com/oauth/authenticate?oauth_token=%@", self.oauthClient.oauthToken];
        [webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
    } failure:^(AFHTTPRequestOperation* op, NSError* err) {
        if (self.failure) {
            self.failure(err);
        }
    }];
    [operation start];
}

- (void)viewDidUnload
{
    [self setWebview:nil];
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

// See https://dev.twitter.com/docs/auth/implementing-sign-twitter
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSString* str = [request.URL description];
    if ([str hasPrefix:CALLBACK_URL]) {
        if (self.progress) {
            self.progress(BBTwitterProgressRedirecting);
        }
        NSRange r = [str rangeOfString:@"?"];
        if (r.location != NSNotFound) {
            NSString* query = [str substringFromIndex:r.location+r.length];
            NSDictionary* dict = [BBUtils parseQueryString:query];
            if ([dict objectForKey:@"denied"]) {
                NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:@"UserCancelled", @"reason", nil];
                self.failure([[NSError alloc] initWithDomain:@"Backbeam" code:400 userInfo:dict]);
            } else {
                NSString* oauthVerifier = [dict objectForKey:@"oauth_verifier"];
                NSDictionary* body = [NSDictionary dictionaryWithObjectsAndKeys:oauthVerifier, @"oauth_verifier", nil];
                NSURLRequest* req = [self.oauthClient signedRequestWithMethod:@"POST" baseURL:TWITTER_ACCESS_TOKEN_URL params:nil body:body callback:nil];
                AFHTTPRequestOperation* operation = [[AFHTTPRequestOperation alloc] initWithRequest:req];
                [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation* op, id response) {
                    NSString* body = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
                    NSDictionary* bodyParams = [BBUtils parseQueryString:body];
                    
                    NSString* oauthToken       = [bodyParams objectForKey:@"oauth_token"];
                    NSString* oauthTokenSecret = [bodyParams objectForKey:@"oauth_token_secret"];
                    NSString* screenName       = [bodyParams objectForKey:@"screen_name"];
                    NSString* userId           = [bodyParams objectForKey:@"user_id"];
                    
                    NSMutableDictionary* postParams = [NSMutableDictionary dictionaryWithObjectsAndKeys:oauthToken, @"oauth_token",
                                                       oauthTokenSecret, @"oauth_token_secret", nil];
                    
                    if (self.join) {
                        [postParams setObject:self.join forKey:@"joins"];
                        if (self.params) {
                            [postParams setObject:self.params forKey:@"params"];
                        }
                    }
                    
                    [self._session socialSignup:@"twitter" params:postParams success:^(BBObject* user, BOOL isNew) {
                        NSDictionary* extraInfo = [NSDictionary dictionaryWithObjectsAndKeys:userId, @"twitter_user_id",
                                                   screenName, @"twitter_screen_name",
                                                   oauthToken, @"oauth_token",
                                                   oauthTokenSecret, @"oauth_token_secret", nil];
                        
                        if (self.success) {
                            self.success(user, extraInfo, isNew);
                        }
                    } failure:^(NSError* err) {
                        if (self.failure) {
                            self.failure(err);
                        }
                    }];
                } failure:^(AFHTTPRequestOperation* op, NSError* err) {
                    if (self.failure) {
                        self.failure(err);
                    }
                }];
                [operation start];
            }

        } else {
            // parameters missing. should never happen
            if (self.failure) {
                self.failure([BBError errorWithStatus:@"OAuthParametersMissing" result:nil]);
            }
        }
        return NO;
    } else if ([str hasPrefix:TWITTER_AUTHORIZE_URL] && navigationType == UIWebViewNavigationTypeFormSubmitted) {
        if (self.progress) {
            self.progress(BBTwitterProgressAuthorizating);
        }
    }
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if (self.progress && self.waitingToFinish) {
        self.waitingToFinish = NO;
        self.progress(BBTwitterProgressLoadedAuthorizationPage);
    }
}

@end

#endif
