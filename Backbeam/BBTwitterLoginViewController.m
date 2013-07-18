//
//  BBTwitterLoginViewController.m
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 17/08/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

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

@property (nonatomic, strong) NSString* oauthToken;
@property (nonatomic, strong) NSString* oauthTokenSecret;
@property (nonatomic, copy) SuccessTwitterBlock success;
@property (nonatomic, copy) FailureTwitterBlock failure;
@property (nonatomic, strong) BackbeamSession* _session;

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

- (id)initWith:(BackbeamSession*)session
{
    self = [super init];
    if (self) {
        self._session = session;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.webview.scrollView setDelaysContentTouches:NO];
}

- (void)signup:(SuccessTwitterBlock)success failure:(FailureTwitterBlock)failure {
    self.success = success;
    self.failure = failure;
    
    if (!self.twitterConsumerKey) {
        if (self.failure) {
            [[NSOperationQueue currentQueue] addOperationWithBlock:^{
                self.failure([BBError errorWithStatus:@"MissingTwitterKeys" result:nil]);
            }];
        }
        return;
    }
    
    NSURLRequest* req = [self signedRequestWithMethod:@"POST" baseURL:TWITTER_REQUEST_TOKEN_URL params:nil body:nil callback:CALLBACK_URL];
    
    AFHTTPRequestOperation* operation = [[AFHTTPRequestOperation alloc] initWithRequest:req];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation* op, id response) {
        NSString* body = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
        NSDictionary* bodyParams = [BBUtils parseQueryString:body];
        self.oauthToken = [bodyParams objectForKey:@"oauth_token"];
        self.oauthTokenSecret = [bodyParams objectForKey:@"oauth_token_secret"];
        
        if (!self.oauthToken || !self.oauthTokenSecret) {
            if (self.failure) {
                self.failure([BBError errorWithStatus:@"UnexpectedTwitterResponse" result:response]);
            }
            return;
        }
        
        NSString* url = [NSString stringWithFormat:@"https://api.twitter.com/oauth/authenticate?oauth_token=%@", self.oauthToken];
        [webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
    } failure:^(AFHTTPRequestOperation* op, NSError* err) {
        if (self.failure) {
            self.failure(err);
        }
    }];
    [operation start];
}

- (NSURLRequest*)signedRequestWithMethod:(NSString*)method baseURL:(NSString*)baseUrl params:(NSDictionary*)params body:(NSDictionary*)body callback:(NSString*)callback {
    
    NSMutableDictionary* authorization = [[NSMutableDictionary alloc] initWithCapacity:8];
    [authorization setObject:self.twitterConsumerKey forKey:@"oauth_consumer_key"];
    [authorization setObject:[BBUtils nonce] forKey:@"oauth_nonce"];
    [authorization setObject:@"HMAC-SHA1" forKey:@"oauth_signature_method"];
    [authorization setObject:[self timestamp] forKey:@"oauth_timestamp"];
    [authorization setObject:@"1.0" forKey:@"oauth_version"];
    if (self.oauthToken) {
        [authorization setObject:self.oauthToken forKey:@"oauth_token"];
    }
    if (callback) {
        [authorization setObject:callback forKey:@"oauth_callback"];
    }
    
    NSMutableDictionary* signatureParams = [[NSMutableDictionary alloc] initWithCapacity:params.count+body.count+authorization.count];
    [signatureParams addEntriesFromDictionary:params];
    [signatureParams addEntriesFromDictionary:body];
    [signatureParams addEntriesFromDictionary:authorization];
    
    NSMutableString* parameterString = [[NSMutableString alloc] init];
    NSArray* sortedKeys = [[signatureParams allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString* key in sortedKeys) {
        NSString* value = [signatureParams objectForKey:key];
        [parameterString appendFormat:@"&%@=%@", [BBUtils urlEncode:key], [BBUtils urlEncode:value]];
    }
    [parameterString deleteCharactersInRange:NSMakeRange(0, 1)];
    
    NSString* signatureBaseString = [NSString stringWithFormat:@"%@&%@&%@", [method uppercaseString], [BBUtils urlEncode:baseUrl], [BBUtils urlEncode:parameterString]];
    NSString* signingKey = nil;
    if (self.oauthTokenSecret) {
        signingKey = [NSString stringWithFormat:@"%@&%@", [BBUtils urlEncode:self.twitterConsumerSecret], [BBUtils urlEncode:self.oauthTokenSecret]];
    } else {
        signingKey = [NSString stringWithFormat:@"%@&"  , [BBUtils urlEncode:self.twitterConsumerSecret]];
    }
    
    NSData* hmac = [BBUtils hmacSha1:[signatureBaseString dataUsingEncoding:NSUTF8StringEncoding] withKey:[signingKey dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSString* signature = [hmac base64EncodedString];
    [authorization setObject:signature forKey:@"oauth_signature"];
    
    NSMutableString* authorizationString = [[NSMutableString alloc] init];
    for (NSString* key in authorization.allKeys) {
        NSString* value = [authorization objectForKey:key];
        [authorizationString appendFormat:@", %@=\"%@\"", [BBUtils urlEncode:key], [BBUtils urlEncode:value]];
    }
    [authorizationString deleteCharactersInRange:NSMakeRange(0, 2)];
    [authorizationString insertString:@"OAuth " atIndex:0];
    
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] init];
    [request setHTTPMethod:method];
    [request setValue:authorizationString forHTTPHeaderField:@"Authorization"];
    if (body.count > 0) {
        [request setHTTPBody:[[BBUtils queryString:body] dataUsingEncoding:NSUTF8StringEncoding]];
    }

    NSString* url = nil;
    if (params.count > 0) {
        url = [NSString stringWithFormat:@"%@?%@", baseUrl, [BBUtils queryString:params]];
    } else {
        url = baseUrl;
    }
    [request setURL:[NSURL URLWithString:url]];
    return request;
}

- (NSString*)timestamp {
    NSTimeInterval time = [[NSDate date] timeIntervalSince1970];
    return [NSString stringWithFormat:@"%.0f", time];
}

- (void)viewDidUnload
{
    [self setWebview:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

// See https://dev.twitter.com/docs/auth/implementing-sign-twitter
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSString* str = [request.URL description];
    if ([str hasPrefix:CALLBACK_URL]) {
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
                NSURLRequest* req = [self signedRequestWithMethod:@"POST" baseURL:TWITTER_ACCESS_TOKEN_URL params:nil body:body callback:nil];
                AFHTTPRequestOperation* operation = [[AFHTTPRequestOperation alloc] initWithRequest:req];
                [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation* op, id response) {
                    NSString* body = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
                    NSDictionary* bodyParams = [BBUtils parseQueryString:body];
                    
                    NSString* oauthToken       = [bodyParams objectForKey:@"oauth_token"];
                    NSString* oauthTokenSecret = [bodyParams objectForKey:@"oauth_token_secret"];
                    NSString* screenName       = [bodyParams objectForKey:@"screen_name"];
                    NSString* userId           = [bodyParams objectForKey:@"user_id"];
                    
                    NSDictionary* postParams = [NSDictionary dictionaryWithObjectsAndKeys:oauthToken, @"oauth_token",
                                                oauthTokenSecret, @"oauth_token_secret", nil];
                    
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
    }
    return YES;
}

@end
