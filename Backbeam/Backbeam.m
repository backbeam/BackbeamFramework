//
//  Backbeam.m
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 16/08/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "Backbeam.h"
#import "AFNetworking.h"
#import "BBTwitterLoginViewController.h"
#import "BBUtils.h"
#import "NSData+Base64.h"
#import "BBPushNotification.h"
#import "BBError.h"
#import "BBQuery.h"
#import "BBCache.h"
#import "BBError.h"
#import "BBOAuth1a.h"

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
#import "SocketIOPacket.h"

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000
#import <Social/Social.h>
#endif
#endif

#if !__has_feature(objc_arc)
#error Backbeam must be built with ARC.
// If you want to turn ARC on only for Backbeam files, add -fobjc-arc to the build phase for each of its files.
#endif

@interface BackbeamSession ()

@property (nonatomic, strong) AFHTTPClient* client;

@property (nonatomic, strong) NSString* host;
@property (nonatomic, assign) NSInteger port;
@property (nonatomic, strong) NSString* _protocol;

@property (nonatomic, strong) NSString* project;
@property (nonatomic, strong) NSString* env;
@property (nonatomic, strong) NSString* sharedKey;
@property (nonatomic, strong) NSString* secretKey;
@property (nonatomic, strong) NSString* authCode;
@property (nonatomic, strong) NSString* _webVersion;
@property (nonatomic, strong) NSString* _httpAuth;

@property (nonatomic, strong) NSString* twitterConsumerKey;
@property (nonatomic, strong) NSString* twitterConsumerSecret;

@property (nonatomic, strong) NSString* deviceToken;
@property (nonatomic, strong) NSString* basePath;

@property (nonatomic, strong) NSCache* imageCache;
@property (nonatomic, strong) BBCache* queryCache;
@property (nonatomic, strong) NSString* cacheDirectory;
@property (nonatomic, strong) BBObject* _currentUser;

@property (nonatomic, strong) NSDictionary* knownMimeTypes;

@property (nonatomic, strong) NSMutableDictionary *roomDelegates;
@property (nonatomic, strong) NSMutableArray *realTimeDelegates;

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
@property (nonatomic, strong) SocketIO *socketio;
#endif
@property (nonatomic, assign) NSInteger delay;

@end

@interface Backbeam ()

@end

@implementation BackbeamSession

#define kDeviceTokenPathComponent @"deviceToken"

- (id)init {
    self.delay = 0;
    return nil;
}

- (id)initInstance
{
    self = [super init];
    if (self) {
        self.imageCache = [[NSCache alloc] init];
        NSString* path = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        path = [path stringByAppendingPathComponent:@"Private Documents"];
        path = [path stringByAppendingPathComponent:@"Backbeam"];
        // TODO: handle error
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        self.basePath = path;
        path = [self.basePath stringByAppendingPathComponent:kDeviceTokenPathComponent];
        // TODO: handle error
        self.deviceToken = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        
        NSDictionary* dict = [NSKeyedUnarchiver unarchiveObjectWithFile:[self userPath]];
        if (dict) {
            self.authCode = [dict stringForKey:@"auth"];
            self._currentUser = [dict objectForKey:@"user"];
            [self._currentUser setSession:self];
        }
        
        path = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        path = [path stringByAppendingPathComponent:@"Caches"];
        self.cacheDirectory = path;
        
        NSString* cachePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        cachePath = [cachePath stringByAppendingPathComponent:@"Caches"];
        self.queryCache = [[BBCache alloc] initWithDirectory:path maxSize:1024*1024*10];

        self.roomDelegates = [[NSMutableDictionary alloc] init];
        self.realTimeDelegates = [[NSMutableArray alloc] init];
        self._protocol = @"http";
    }
    return self;
}

- (void)setHost:(NSString*)host port:(NSInteger)port {
    self.host = host;
    self.port = port;
}

- (void)setWebVersion:(NSString*)webVersion {
    self._webVersion = webVersion;
}

- (void)setHttpAuth:(NSString*)httpAuth {
    self._httpAuth = httpAuth;
}

- (void)setProtocol:(NSString *)protocol {
    self._protocol = [protocol lowercaseString];
    if ([self._protocol isEqualToString:@"https"]) {
        self.port = 443;
    } else {
        self.port = 80;
    }
}

- (void)setProject:(NSString*)project sharedKey:(NSString*)sharedKey secretKey:(NSString*)secretKey environment:(NSString*)env {
    self.project   = project;
    self.sharedKey = sharedKey;
    self.secretKey = secretKey;
    self.env       = env;
    NSString* url = [NSString stringWithFormat:@"%@://api-%@-%@.%@:%d",
                     self._protocol, self.env, self.project, self.host, self.port];
    self.client = [[AFHTTPClient alloc] initWithBaseURL:[NSURL URLWithString:url]];
}

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
- (void)connect {
    for (id<BBRealTimeConnectionDelegate> delegate in self.realTimeDelegates) {
        [delegate realTimeConnecting];
    }
    self.socketio = [[SocketIO alloc] initWithDelegate:self];
    if ([self._protocol isEqualToString:@"https"]) {
        [self.socketio setUseSecure:YES];
    }
    [self.socketio connectToHost:self.host onPort:self.port];
}

- (void)enableRealTime {
    [self disableRealTime];
    [self connect];
}

- (void)disableRealTime {
    if (self.socketio) {
        self.socketio.delegate = nil;
        [self.socketio disconnect];
        self.socketio = nil;
    }
    self.delay = 0;
}

- (void)connectAfterDelay {
    static NSInteger maxDelay = 10;
    
    self.delay++;
    if (self.delay >= maxDelay) {
        self.delay = maxDelay;
    }
    
    double delayInSeconds = self.delay;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (!self.socketio || self.socketio.isConnecting || self.socketio.isConnected) {
            return;
        }
        [self connect];
    });
}

- (BOOL)subscribeToRealTimeEvents:(NSString*)event delegate:(id<BBRealTimeEventDelegate>)delegate {
    NSString* room = [self roomName:event];
    NSMutableArray* delegates = (NSMutableArray*)[self.roomDelegates arrayForKey:room];
    if (!delegates) {
        delegates = [[NSMutableArray alloc] init];
        [self.roomDelegates setObject:delegates forKey:room];
    }
    [delegates addObject:delegate];
    if (!self.socketio) return NO;
    
    if (self.socketio.isConnected) {
        NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:room, @"room", nil];
        [self.socketio sendEvent:@"subscribe" withData:params];
    }
    return YES;
}

- (NSArray*)subscribedRealTimeEvents {
    NSArray *keys = [self.roomDelegates allKeys];
    NSMutableArray *arr = [[NSMutableArray alloc] initWithCapacity:keys.count];
    for (NSString *room in keys) {
        NSArray *components = [room componentsSeparatedByString:@"/"];
        [arr addObject:[components lastObject]];
    }
    return arr;
}

- (void)unsubscribeAllRealTimeEventDelegates {
    [self.roomDelegates removeAllObjects];
    if (self.socketio && self.socketio.isConnected) {
        NSDictionary *params = [NSDictionary dictionary];
        [self.socketio sendEvent:@"unsubsribe-all" withData:params];
    }
}

- (void)unsubscribeAllRealTimeConnectionDelegates {
    [self.realTimeDelegates removeAllObjects];
}

- (BOOL)isRealTimeEnabled {
    return self.socketio != nil;
}

- (BOOL)isRealTimeConnected {
    return self.socketio != nil && [self.socketio isConnected];
}

- (BOOL)unsubscribeFromRealTimeEvents:(NSString*)event delegate:(id<BBRealTimeEventDelegate>)delegate {
    NSString* room = [self roomName:event];
    NSMutableArray* delegates = (NSMutableArray*)[self.roomDelegates arrayForKey:room];
    if (!delegates) return NO;
    [delegates removeObject:delegate];
    if (delegates.count == 0) {
        [self.roomDelegates removeObjectForKey:room];
    }
    if (self.socketio.isConnected && delegates.count == 0) {
        NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:room, @"room", nil];
        [self.socketio sendEvent:@"unsubscribe" withData:params];
    }
    return YES;
}

- (BOOL)sendRealTimeEvent:(NSString*)event message:(NSDictionary*)message {
    if (!self.socketio) return NO;
    NSString* room = [self roomName:event];
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:room, @"room", nil];
    for (id key in message.allKeys) {
        NSString *_key = [NSString stringWithFormat:@"_%@", key];
        NSString *value = [message stringForKey:key];
        if (value) {
            [params setObject:value forKey:_key];
        }
    }
    [self.socketio sendEvent:@"publish" withData:params];
    return YES;
}

- (NSString*)roomName:(NSString*)room {
    return [NSString stringWithFormat:@"%@/%@/%@", self.project, self.env, room];
}

- (void)socketIODidConnect:(SocketIO *)socket {
    self.delay = 0;
    for (NSString *room in self.roomDelegates) {
        NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:room, @"room", nil];
        [self.socketio sendEvent:@"subscribe" withData:params];
    }
    for (id<BBRealTimeConnectionDelegate> delegate in self.realTimeDelegates) {
        [delegate realTimeConnected];
    }
}

- (void)socketIODidDisconnect:(SocketIO *)socket {
    for (id<BBRealTimeConnectionDelegate> delegate in self.realTimeDelegates) {
        [delegate realTimeDisconnected];
    }
    self.delay = 0;
    [self connectAfterDelay];
}

- (void)socketIO:(SocketIO *)socket didReceiveMessage:(SocketIOPacket *)packet {
}

- (void)socketIO:(SocketIO *)socket didReceiveJSON:(SocketIOPacket *)packet {
}

- (void)socketIO:(SocketIO *)socket didReceiveEvent:(SocketIOPacket *)packet {
    id result = packet.dataAsJSON;
    if ([result isKindOfClass:[NSDictionary class]]) {
        NSDictionary* dict = (NSDictionary*)result;
        NSArray* args = [dict arrayForKey:@"args"];
        if (args.count > 0) {
            dict = [args objectAtIndex:0];
        }
        if ([dict isKindOfClass:[NSDictionary class]]) {
            NSString* room = [dict stringForKey:@"room"];
            if (room) {
                NSString* prefix = [self roomName:@""];
                if ([room hasPrefix:prefix]) {
                    NSMutableDictionary *data = [[NSMutableDictionary alloc] initWithCapacity:dict.count];
                    for (id key in dict) {
                        if ([key hasPrefix:@"_"]) {
                            [data setObject:[dict objectForKey:key] forKey:[key substringFromIndex:1]];
                        }
                    }
                    NSString* event = [room substringFromIndex:prefix.length];
                    NSArray* delegates = [self.roomDelegates arrayForKey:room];
                    for (id<BBRealTimeEventDelegate> delegate in delegates) {
                        [delegate realTimeEventReceived:event message:data];
                    }
                }
            }
        }
    }
}

- (void)socketIO:(SocketIO *)socket didSendMessage:(SocketIOPacket *)packet {
}

- (void)socketIOHandshakeFailed:(SocketIO *)socket {
    for (id<BBRealTimeConnectionDelegate> delegate in self.realTimeDelegates) {
        [delegate realTimeConnectionFailed:[BBError errorWithStatus:@"HandshakeFailed" result:nil]];
    }
    [self connectAfterDelay];
}

- (void)socketIO:(SocketIO *)socket failedToConnectWithError:(NSError *)error {
    for (id<BBRealTimeConnectionDelegate> delegate in self.realTimeDelegates) {
        [delegate realTimeConnectionFailed:error];
    }
    [self connectAfterDelay];
}

- (void)subscribeToRealTimeConnectionEvents:(id<BBRealTimeConnectionDelegate>)delegate {
    [self.realTimeDelegates addObject:delegate];
}

- (void)unsubscribeFromRealTimeConnectionEvents:(id<BBRealTimeConnectionDelegate>)delegate {
    [self.realTimeDelegates removeObject:delegate];
}

- (BBTwitterLoginViewController*)twitterLoginViewController {
    BBOAuth1a *oauthClient = [[BBOAuth1a alloc] init];
    oauthClient.consumerKey = self.twitterConsumerKey;
    oauthClient.consumerSecret = self.twitterConsumerSecret;
    BBTwitterLoginViewController* vc = [[BBTwitterLoginViewController alloc] initWith:self oauthClient:oauthClient];
    return vc;
}

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000
// based on https://dev.twitter.com/docs/ios/using-reverse-auth
- (void)twitterReverseOAuthWithAccount:(ACAccount*)account success:(SuccessReverseOauthBlock)success failure:(FailureReverseOauthBlock)failure {
    
    if (!self.twitterConsumerKey || !self.twitterConsumerSecret) {
        if (failure) {
            [[NSOperationQueue currentQueue] addOperationWithBlock:^{
                failure([BBError errorWithStatus:@"MissingTwitterKeys" result:nil]);
            }];
        }
        return;
    }
    
    BBOAuth1a *oauthClient = [[BBOAuth1a alloc] init];
    oauthClient.consumerKey    = self.twitterConsumerKey;
    oauthClient.consumerSecret = self.twitterConsumerSecret;

    NSDictionary *params = [NSDictionary dictionaryWithObject:@"reverse_auth" forKey:@"x_auth_mode"];
    NSURLRequest *request = [oauthClient signedRequestWithMethod:@"POST"
                                                         baseURL:@"https://api.twitter.com/oauth/request_token"
                                                          params:params body:nil callback:nil];
    
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation* op, id res) {
        
        NSDictionary *step2Params = [[NSMutableDictionary alloc] init];
        [step2Params setValue:self.twitterConsumerKey forKey:@"x_reverse_auth_target"];
        [step2Params setValue:op.responseString forKey:@"x_reverse_auth_parameters"];
        
        NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/oauth/access_token"];
        SLRequest *stepTwoRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter
                                                       requestMethod:SLRequestMethodPOST
                                                                 URL:url
                                                          parameters:step2Params];
        
        [stepTwoRequest setAccount:account];
        [stepTwoRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
            NSString *responseStr = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            
            if (error) {
                if (failure) {
                    failure(error);
                }
                return;
            }
            
            NSDictionary* bodyParams = [BBUtils parseQueryString:responseStr];
            
//            NSString* oauthToken       = [bodyParams objectForKey:@"oauth_token"];
//            NSString* oauthTokenSecret = [bodyParams objectForKey:@"oauth_token_secret"];
//            NSString* screenName       = [bodyParams objectForKey:@"screen_name"];
//            NSString* userId           = [bodyParams objectForKey:@"user_id"];
            
            if (success) {
                success(bodyParams);
            }
         }];
    } failure:^(AFHTTPRequestOperation* op, NSError* error) {
        if (failure) {
            failure(error);
        }
    }];
    [operation start];
    
    
}
#endif
#endif

- (void)setTwitterConsumerKey:(NSString *)twitterConsumerKey consumerSecret:(NSString*)twitterConsumerSecret {
    self.twitterConsumerKey = twitterConsumerKey;
    self.twitterConsumerSecret = twitterConsumerSecret;
}

- (NSString*)signature:(NSDictionary*)params {
    NSMutableString* parameterString = [[NSMutableString alloc] init];
    NSArray* sortedKeys = [[params allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString* key in sortedKeys) {
        id value = [params objectForKey:key];
        if ([value isKindOfClass:[NSArray class]]) {
            NSArray* arr = [(NSArray*)value sortedArrayUsingSelector:@selector(compare:)];
            for (id val in arr) {
                [parameterString appendFormat:@"&%@=%@", key, val];
            }
        } else {
            [parameterString appendFormat:@"&%@=%@", key, value];
        }
    }
    [parameterString deleteCharactersInRange:NSMakeRange(0, 1)];
    
    NSData* hmac = [BBUtils hmacSha1:[parameterString dataUsingEncoding:NSUTF8StringEncoding] withKey:[self.secretKey dataUsingEncoding:NSUTF8StringEncoding]];
    return [hmac base64EncodedString];
}

- (NSString*)cacheString:(NSMutableDictionary*)cacheParams {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:cacheParams];
    [params setObject:self.project forKey:@"project"];
    [params setObject:self.env     forKey:@"env"];
    [params setObject:self.host    forKey:@"host"];
    
    NSMutableString* cacheKeyString = [[NSMutableString alloc] init];
    NSArray* sortedKeys = [[params allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString* key in sortedKeys) {
        id value = [params objectForKey:key];
        if ([value isKindOfClass:[NSArray class]]) {
            NSArray* arr = [(NSArray*)value sortedArrayUsingSelector:@selector(compare:)];
            for (id val in arr) {
                [cacheKeyString appendFormat:@"&%@=%@", key, val];
            }
        } else {
            [cacheKeyString appendFormat:@"&%@=%@", key, value];
        }
    }
    return [BBUtils hexString:[BBUtils sha1:[cacheKeyString dataUsingEncoding:NSUTF8StringEncoding]]];
}

- (void)perform:(NSString*)httpMethod
           path:(NSString*)path
         params:(NSDictionary*)_params
    fetchPolicy:(BBFetchPolicy)fetchPolicy
        success:(SuccessOperationBlock)success
        failure:(FailureOperationBlock)failure {
    
    NSMutableDictionary* params = [NSMutableDictionary dictionaryWithDictionary:_params];
    [params setObject:httpMethod forKey:@"method"];
    [params setObject:path forKey:@"path"];
    if (self.authCode) {
        [params setObject:self.authCode forKey:@"auth"];
    }
    
    [params setObject:self.sharedKey forKey:@"key"];
    
    NSString* cacheKey = nil;
    BOOL useCache    = fetchPolicy == BBFetchPolicyLocalOnly
                    || fetchPolicy == BBFetchPolicyLocalAndRemote
                    || fetchPolicy == BBFetchPolicyLocalOrRemote;
    if (useCache) {
        cacheKey = [self cacheString:params];
        NSData* data = [self.queryCache read:cacheKey];
        BOOL read = NO;
        if (data) {
            id result = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
            if (result) {
                read = YES;
                if (success) {
                    [[NSOperationQueue currentQueue] addOperationWithBlock:^{
                        success(result, YES);
                    }];
                }
                if (fetchPolicy == BBFetchPolicyLocalOrRemote) {
                    return;
                }
            }
        }
        if (fetchPolicy == BBFetchPolicyLocalOnly) {
            if (!read && failure) {
                failure(nil, [BBError errorWithStatus:@"CachedDataNotFound" result:nil]);
            }
            return;
        }
    }
    
    [params setObject:[BBUtils nonce] forKey:@"nonce"];
    [params setObject:[NSString stringWithFormat:@"%lld", (long long)([[NSDate date] timeIntervalSince1970]*1000)] forKey:@"time"];
    [params setObject:[self signature:params] forKey:@"signature"];
    [params removeObjectForKey:@"method"];
    [params removeObjectForKey:@"path"];
    
    NSMutableURLRequest* req = [self.client requestWithMethod:httpMethod path:path parameters:params];
    __block AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:req success:^(NSURLRequest* req, NSHTTPURLResponse* resp, id result) {
        if (success) {
            success(result, NO);
        }
        
        if (useCache) {
            [self.queryCache write:operation.responseData withKey:cacheKey];
        }
        
    } failure:^(NSURLRequest* req, NSHTTPURLResponse* resp, NSError* err, id result) {
        
        [self checkInvalidAuthCode:result];
        
        if (failure) {
            failure(result, err);
        }
    }];
    
    [operation start];
}

- (void)checkInvalidAuthCode:(id)result {
    if ([result isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary*)result;
        NSString *status = [dict stringForKey:@"status"];
        if ([@"InvalidAuthCode" isEqualToString:status]) {
            [self logout];
        }
    }
}

- (void)requestDataFromController:(NSString*)path
                           method:(NSString*)method
                           params:(NSDictionary*)params
                      fetchPolicy:(BBFetchPolicy)fetchPolicy
                   uploadProgress:(ProgressDataBlock)uploadProgress
                 downloadProgress:(ProgressDataBlock)downloadProgress
                          success:(SuccessControllerBlock)success
                          failure:(FailureControllerBlock)failure {
    
    NSString *urlString = nil;
    if (self._webVersion) {
        urlString = [[NSString alloc] initWithFormat:@"%@://web-%@-%@-%@.%@:%d", self._protocol, self._webVersion, self.env, self.project, self.host, self.port];
    } else {
        urlString = [[NSString alloc] initWithFormat:@"%@://web-%@-%@.%@:%d", self._protocol, self.env, self.project, self.host, self.port];
    }
    AFHTTPClient *client = [[AFHTTPClient alloc] initWithBaseURL:[NSURL URLWithString:urlString]];
    if (self._httpAuth) {
        [client setAuthorizationHeaderWithUsername:self.project password:self._httpAuth];
    }
    
    NSMutableDictionary *fileParams = [[NSMutableDictionary alloc] initWithCapacity:params.count];
    NSMutableDictionary *otherParams = [[NSMutableDictionary alloc] initWithCapacity:params.count];
    
    for (NSString *key in [params allKeys]) {
        id obj = [params objectForKey:key];
        if ([obj isKindOfClass:[BBFileUpload class]]) {
            [fileParams setObject:obj forKey:key];
        } else {
            [otherParams setObject:obj forKey:key];
        }
    }
    
    NSMutableURLRequest* req = nil;
    if (fileParams.count > 0) {
        req = [client multipartFormRequestWithMethod:method
                                                path:path
                                          parameters:otherParams
                           constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
                               
                               for (NSString *key in fileParams) {
                                   
                                   BBFileUpload *fileUpload = (BBFileUpload*)[fileParams objectForKey:key];
                                   
                                   [formData appendPartWithFileData:fileUpload.data
                                                               name:key
                                                           fileName:fileUpload.fileName
                                                           mimeType:fileUpload.mimeType];
                               }
        }];
    } else {
        req = [client requestWithMethod:method path:path parameters:otherParams];
    }
    
    
    if (self.authCode) {
        [req setValue:self.authCode forHTTPHeaderField:@"x-backbeam-auth"];
    }
    [req setValue:@"ios" forHTTPHeaderField:@"x-backbeam-sdk"];
    
    NSMutableDictionary *prms = [NSMutableDictionary dictionaryWithDictionary:params];
    [prms setObject:method forKey:@"method"];
    [prms setObject:path   forKey:@"path"];
    if (self.authCode) {
        [prms setObject:self.authCode forKey:@"auth"];
    }
    if (self._webVersion) {
        [prms setObject:self._webVersion forKey:@"version"];
    }
    
    NSString* cacheKey = nil;
    BOOL useCache = fetchPolicy == BBFetchPolicyLocalOnly
                 || fetchPolicy == BBFetchPolicyLocalAndRemote
                 || fetchPolicy == BBFetchPolicyLocalOrRemote;
    if (useCache) {
        NSString *cacheKeyString = [self cacheString:prms];
        cacheKey = [BBUtils hexString:[BBUtils sha1:[cacheKeyString dataUsingEncoding:NSUTF8StringEncoding]]];
        NSData* data = [self.queryCache read:cacheKey];
        BOOL read = NO;
        if (data) {
            if (data) {
                read = YES;
                if (success) {
                    [[NSOperationQueue currentQueue] addOperationWithBlock:^{
                        success(data, YES, nil);
                    }];
                }
                if (fetchPolicy == BBFetchPolicyLocalOrRemote) {
                    return;
                }
            }
        }
        if (fetchPolicy == BBFetchPolicyLocalOnly) {
            if (!read && failure) {
                failure(nil, [BBError errorWithStatus:@"CachedDataNotFound" result:nil]);
            }
            return;
        }
    }
    
    AFHTTPRequestOperation* operation = [[AFHTTPRequestOperation alloc] initWithRequest:req];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *op, id responseObject) {
        if (success) {
            success(op.responseData, NO, op.response);
        }
        if (useCache) {
            [self.queryCache write:op.responseData withKey:cacheKey];
        }
    } failure:^(AFHTTPRequestOperation *op, NSError *err) {
        if (failure) {
            failure(op.responseData, err);
        }
    }];
    
    if (downloadProgress) {
        [operation setDownloadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
            downloadProgress(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
        }];
    }
    
    if (uploadProgress) {
        [operation setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
            uploadProgress(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
        }];
    }
    
    [operation start];
}

- (void)requestJSONFromController:(NSString*)path
                           method:(NSString*)method
                           params:(NSDictionary*)params
                      fetchPolicy:(BBFetchPolicy)fetchPolicy
                         progress:(ProgressDataBlock)progress
                          success:(SuccessOperationBlock)success
                          failure:(FailureOperationBlock)failure {
    
    [self requestDataFromController:path method:method params:params fetchPolicy:fetchPolicy uploadProgress:progress downloadProgress:nil success:^(NSData *data, BOOL fromCache, NSHTTPURLResponse *response) {
        
        id result = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
        
        NSString* auth   = [[response allHeaderFields] stringForKey:@"x-backbeam-auth"];
        NSString* userid = [[response allHeaderFields] stringForKey:@"x-backbeam-user"];
        
        if (auth) {
            if (auth.length == 0) {
                [self logout];
            } else {
                BBObject *user = [[BBObject alloc] initWith:self entity:@"user" identifier:userid];
                [self setCurrentUser:user withAuthCode:auth];
            }
        }
        if (success) {
            success(result, fromCache);
        }
    } failure:^(NSData *data, NSError *error) {
        id result = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
        
        if (failure) {
            failure(result, error);
        }
    }];
    
}

- (void)requestObjectsFromController:(NSString*)path
                              method:(NSString*)method
                              params:(NSDictionary*)params
                         fetchPolicy:(BBFetchPolicy)fetchPolicy
                            progress:(ProgressDataBlock)progress
                             success:(SuccessNearQueryBlock)success
                             failure:(FailureQueryBlock)failure {
    
    [self requestDataFromController:path method:method params:params fetchPolicy:fetchPolicy uploadProgress:progress downloadProgress:nil success:^(NSData *data, BOOL fromCache, NSHTTPURLResponse *response) {
        
        id result = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
        
        if (![result isKindOfClass:[NSDictionary class]]) {
            if (failure) {
                failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            }
            return;
        }
        NSDictionary* objects = [result dictionaryForKey:@"objects"];
        if (!objects) {
            if (failure) {
                failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            }
            return;
        }
        NSMutableDictionary* refs = [BBObject objectsWithSession:self values:objects references:nil];
        NSArray* ids = [result arrayForKey:@"ids"];
        if (!ids) {
            if (failure) {
                failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            }
            return;
        }
        NSMutableArray* arr = [[NSMutableArray alloc] initWithCapacity:ids.count];
        for (NSString* identifier in ids) {
            BBObject* obj = [refs objectForKey:identifier];
            if (obj) { // should always exist
                [arr addObject:obj];
            }
        }
        NSNumber *totalCount = [result numberForKey:@"count"];
        NSArray  *distances  = [result arrayForKey:@"distances"];
        
        NSString* auth   = [[response allHeaderFields] stringForKey:@"x-backbeam-auth"];
        NSString* userid = [[response allHeaderFields] stringForKey:@"x-backbeam-user"];
        
        if (auth) {
            if (auth.length == 0) {
                [self logout];
            } else {
                BBObject *user = [refs objectForKey:userid];
                if (!user) {
                    user = [[BBObject alloc] initWith:self entity:@"user" identifier:userid];
                }
                [self setCurrentUser:user withAuthCode:auth];
            }
        }
        
        if (success) {
            success(arr, totalCount.integerValue, distances, fromCache);
        }
    } failure:^(NSData *data, NSError *error) {
        
        id result = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
        
        if (result) {
            if (![result isKindOfClass:[NSDictionary class]]) {
                if (failure) {
                    failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
                }
                return;
            }
            NSString* status = [result stringForKey:@"status"];
            if (![status isEqualToString:@"Success"]) {
                if (failure) {
                    failure([BBError errorWithStatus:status result:result]);
                }
                return;
            }
        } else if (failure) {
            failure(error);
        }
    }];
    
}

- (NSString*)mimeTypeForFile:(NSString*)fileName {
    if (!self.knownMimeTypes) {
        self.knownMimeTypes = [NSDictionary dictionaryWithObjectsAndKeys:
                               @"image/jpeg", @".jpg",
                               @"image/jpeg", @".jpeg",
                               @"image/png", @".png",
                               @"image/gif", @".gif",
                               @"video/quicktime", @".mov",
                               @"audio/mpeg3", @".mp3",
                               @"audio/wav", @".wav",
                               @"audio/aiff", @".aif",
                               @"audio/aiff", @".aiff",
                               @"video/mpeg", @".mpeg",
                               @"video/mp4", @".mp4",
                               @"application/pdf", @".pdf",
                               nil];
    }
    
    for (NSString* extension in self.knownMimeTypes.allKeys) {
        if ([fileName hasSuffix:extension]) {
            return [self.knownMimeTypes stringForKey:extension];
        }
    }
    
    return @"application/octet-stream";
}

- (void)upload:(NSString*)httpMethod
          data:(NSData*)data
      fileName:(NSString*)fileName
      mimeType:(NSString*)mimeType
          path:(NSString*)path
        params:(NSDictionary*)params
          sign:(BOOL)sign
      progress:(ProgressDataBlock)progress
       success:(SuccessBlock)success
       failure:(FailureOperationBlock)failure {

    if (!mimeType) {
        mimeType = [self mimeTypeForFile:fileName];
    }
    
    NSMutableDictionary *allParams = [[NSMutableDictionary alloc] initWithDictionary:params];
    if (sign) {
        [allParams setObject:path forKey:@"path"];
        [allParams setObject:httpMethod forKey:@"method"];
        [allParams setObject:self.sharedKey forKey:@"key"];
        [allParams setObject:[BBUtils nonce] forKey:@"nonce"];
        [allParams setObject:[NSString stringWithFormat:@"%lld", (long long)([[NSDate date] timeIntervalSince1970]*1000)] forKey:@"time"];
        NSString *signature = [self signature:allParams];
        
        [allParams setObject:signature forKey:@"signature"];
        [allParams removeObjectForKey:@"path"];
        [allParams removeObjectForKey:@"method"];
    }
    
    NSMutableURLRequest* req = [self.client multipartFormRequestWithMethod:httpMethod path:path parameters:allParams constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        [formData appendPartWithFileData:data name:@"file" fileName:fileName mimeType:mimeType];
    }];
    
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:req success:^(NSURLRequest* req, NSHTTPURLResponse* resp, id result) {
        [self processBasicResponse:result success:success failure:^(NSError* error) {
            if (failure) {
                failure(result, error);
            }
        }];
    } failure:^(NSURLRequest* req, NSHTTPURLResponse* resp, NSError* err, id result) {
        [self processBasicFailure:result error:err failure:^(NSError* error) {
            if (failure) {
                failure(result, error);
            }
        }];
    }];
    if (progress) {
        [operation setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
            progress(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
        }];
    }
    [operation start];
}

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
- (UIImage*)image:(NSString*)identifier
          version:(NSNumber*)version
         withSize:(CGSize)size
         progress:(ProgressDataBlock)progress
          success:(SuccessImageBlock)success
          failure:(FailureBlock)failure {
    
    CGFloat scale = [UIScreen mainScreen].scale;
    NSString* width  = [NSString stringWithFormat:@"%d", (int)(size.width *scale)];
    NSString* height = [NSString stringWithFormat:@"%d", (int)(size.height*scale)];
    
    NSString* path = nil;
    if (version) {
        path = [NSString stringWithFormat:@"/data/file/download/%@/%@", identifier, version];
    } else {
        path = [NSString stringWithFormat:@"/data/file/download/%@", identifier];
    }
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:width, @"width", height, @"height", nil];
    NSMutableDictionary *cacheParams = [NSMutableDictionary dictionaryWithDictionary:params];
    
    [cacheParams setObject:@"GET" forKey:@"method"];
    [cacheParams setObject:path   forKey:@"path"];
    NSString *cacheKey = [self cacheString:cacheParams];
    NSMutableURLRequest* req = [self.client requestWithMethod:@"GET" path:path parameters:params];
    
    UIImage* img = [self.imageCache objectForKey:cacheKey];
    if (img) return img;
    
    [self download:req progress:progress success:^(NSData* data) {
        UIImage* img = [UIImage imageWithData:data scale:scale];
        // TODO: http://ioscodesnippet.tumblr.com/post/10924101444/force-decompressing-uiimage-in-background-to-achieve
        if (img) {
            [self.imageCache setObject:img forKey:cacheKey];
            if (success) {
                success(img);
            }
        } else if (failure) {
            failure([BBError errorWithStatus:@"InvalidImage" result:nil]);
        }
    } failure:failure];
    return nil;
}
#endif

- (void)downloadPath:(NSString*)path progress:(ProgressDataBlock)progress success:(SuccessDataBlock)success failure:(FailureBlock)failure {
    NSMutableURLRequest* req = [self.client requestWithMethod:@"GET" path:path parameters:nil];
    [self download:req progress:progress success:success failure:failure];
}

- (void)download:(NSMutableURLRequest*)req progress:(ProgressDataBlock)progress success:(SuccessDataBlock)success failure:(FailureBlock)failure {
    AFHTTPRequestOperation* operation = [[AFHTTPRequestOperation alloc] initWithRequest:req];
    if (progress) {
        [operation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
            progress(bytesRead, totalBytesRead, totalBytesExpectedToRead);
        }];
    }
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation* operation, id response) {
        if (response) { // TODO: isKindOfClass:[NSData data] but was __NSCFData
            NSData* data = (NSData*)response;
            if (success) {
                success(data);
            }
        } else if (failure) {
            failure([BBError errorWithStatus:@"InvalidResponse" result:nil]);
        }
    } failure:^(AFHTTPRequestOperation* operation, NSError* error) {
        if (failure) {
            failure([BBError errorWithError:error]);
        }
    }];
    [operation start];
}

- (void)persistDeviceToken:(NSData*)data {
    NSString* base64 = [data base64EncodedString];
    NSString* path = [self.basePath stringByAppendingPathComponent:kDeviceTokenPathComponent];
    [base64 writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]; // TODO: handle error
    self.deviceToken = base64;
}

- (void)subscribeToChannels:(NSArray*)channels success:(SuccessBlock)success failure:(FailureBlock)failure {
    if (!self.deviceToken) {
        if (failure) {
            [[NSOperationQueue currentQueue] addOperationWithBlock:^{
                failure([BBError errorWithStatus:@"UnknownDeviceToken" result:nil]);
            }];
        }
    }
    
    NSDictionary* body = [[NSDictionary alloc] initWithObjectsAndKeys:channels, @"channels", self.deviceToken, @"token", @"apn", @"gateway", nil];
    
    [self perform:@"POST" path:@"/push/subscribe" params:body fetchPolicy:BBFetchPolicyRemoteOnly success:^(id result, BOOL fromCache) {
        [self processBasicResponse:result success:^(id result) {
            if (success) {
                success();
            }
        } failure:failure];
    } failure:^(id result, NSError* err) {
        [self processBasicFailure:result error:err failure:failure];
    }];
}

- (void)subscribedChannels:(SuccessArrayBlock)success failure:(FailureBlock)failure {
    if (!self.deviceToken) {
        if (failure) {
            [[NSOperationQueue currentQueue] addOperationWithBlock:^{
                failure([BBError errorWithStatus:@"UnknownDeviceToken" result:nil]);
            }];
        }
    }
    
    NSDictionary* body = [[NSDictionary alloc] initWithObjectsAndKeys:self.deviceToken, @"token", @"apn", @"gateway", nil];
    
    [self perform:@"GET" path:@"/push/subscribed-channels" params:body fetchPolicy:BBFetchPolicyRemoteOnly success:^(id result, BOOL fromCache) {
        [self processBasicResponse:result success:^(id result) {
            NSArray *channels = [result arrayForKey:@"channels"];
            if (success) {
                success(channels);
            }
        } failure:failure];
    } failure:^(id result, NSError* err) {
        [self processBasicFailure:result error:err failure:failure];
    }];
}

- (void)unsubscribeFromChannels:(NSArray*)channels success:(SuccessBlock)success failure:(FailureBlock)failure {
    if (!self.deviceToken) {
        if (failure) {
            [[NSOperationQueue currentQueue] addOperationWithBlock:^{
                failure([BBError errorWithStatus:@"UnknownDeviceToken" result:nil]);
            }];
        }
    }
    NSDictionary* body = [[NSDictionary alloc] initWithObjectsAndKeys:channels, @"channels", self.deviceToken, @"token", @"apn", @"gateway", nil];
    
    [self perform:@"POST" path:@"/push/unsubscribe" params:body fetchPolicy:BBFetchPolicyRemoteOnly success:^(id result, BOOL fromCache) {
        [self processBasicResponse:result success:^(id result) {
            if (success) {
                success();
            }
        } failure:failure];
    } failure:^(id result, NSError* err) {
        [self processBasicFailure:result error:err failure:failure];
    }];
}

- (void)unsubscribeFromAllChannels:(SuccessBlock)success failure:(FailureBlock)failure {
    if (!self.deviceToken) {
        if (failure) {
            [[NSOperationQueue currentQueue] addOperationWithBlock:^{
                failure([BBError errorWithStatus:@"UnknownDeviceToken" result:nil]);
            }];
        }
    }
    NSDictionary* body = [[NSDictionary alloc] initWithObjectsAndKeys:self.deviceToken, @"token", @"apn", @"gateway", nil];
    
    [self perform:@"POST" path:@"/push/unsubscribe-all" params:body fetchPolicy:BBFetchPolicyRemoteOnly success:^(id result, BOOL fromCache) {
        [self processBasicResponse:result success:^(id result) {
            if (success) {
                success();
            }
        } failure:failure];
    } failure:^(id result, NSError* err) {
        [self processBasicFailure:result error:err failure:failure];
    }];
}

- (void)processBasicResponse:(id)result success:(SuccessBlock)success failure:(FailureBlock)failure {
    if (![result isKindOfClass:[NSDictionary class]]) {
        if (failure) {
            failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
        }
        return;
    }
    NSString* status = [result stringForKey:@"status"];
    if (!status) {
        if (failure) {
            failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
        }
        return;
    }
    if (![status isEqualToString:@"Success"]) {
        if (failure) {
            failure([BBError errorWithStatus:status result:result]);
        }
        return;
    }
    
    if (success) {
        success(result);
    }
}

- (void)processBasicFailure:(id)result error:(NSError*)error failure:(FailureBlock)failure {
    if (![result isKindOfClass:[NSDictionary class]]) {
        if (failure) {
            failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
        }
        return;
    }
    
    NSString* status = [result stringForKey:@"status"];
    if (![status isEqualToString:@"Success"]) {
        if (failure) {
            failure([BBError errorWithStatus:status result:result]);
        }
        return;
    }
    
    if (failure) {
        failure([BBError errorWithError:error]);
    }
}

- (void)sendPushNotification:(BBPushNotification*)notification toChannel:(NSString*)channel success:(SuccessBlock)success failure:(FailureBlock)failure {
    NSMutableDictionary* body = [[NSMutableDictionary alloc] init];
    [body setObject:channel forKey:@"channel"];
    
    if (notification.iosBadge) {
        [body setObject:[NSString stringWithFormat:@"%d", notification.iosBadge.integerValue] forKey:@"apn_badge"];
    }
    if (notification.iosAlert) {
        [body setObject:notification.iosAlert  forKey:@"apn_alert"];
    }
    if (notification.iosSound) {
        [body setObject:notification.iosSound forKey:@"apn_sound"];
    }
    if (notification.iosPayload) {
        for (id key in notification.iosPayload.allKeys) {
            [body setObject:[[notification.iosPayload objectForKey:key] description] forKey:[NSString stringWithFormat:@"apn_payload_%@", key]];
        }
    }
    
    if (notification.androidCollapseKey) {
        [body setObject:notification.androidCollapseKey forKey:@"gcm_collapse_key"];
    }
    if (notification.androidTimeToLive ) {
        [body setObject:[NSString stringWithFormat:@"%ld", notification.androidTimeToLive.longValue] forKey:@"gcm_time_to_live"];
    }
    if (notification.androidDelayWhileIdle) {
        [body setObject:(notification.androidDelayWhileIdle.boolValue ? @"true" : @"false") forKey:@"gcm_delay_while_idle"];
    }
    if (notification.androidData) {
        for (id key in notification.androidData.allKeys) {
            [body setObject:[[notification.androidData objectForKey:key] description] forKey:[NSString stringWithFormat:@"gcm_data_%@", key]];
        }
    }
    
    [self perform:@"POST" path:@"/push/send" params:body fetchPolicy:BBFetchPolicyRemoteOnly success:^(id result, BOOL fromCache) {
        [self processBasicResponse:result success:success failure:failure];
    } failure:^(id result, NSError* err) {
        [self processBasicFailure:result error:err failure:failure];
    }];
}

- (void)setCurrentUser:(BBObject*)user withAuthCode:(NSString*)authCode {
    self._currentUser = user;
    self.authCode = authCode;
    if (user == nil) {
        [[NSFileManager defaultManager] removeItemAtPath:[self userPath] error:nil]; // TODO: handle error
    } else {
        NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:authCode, @"auth", user, @"user", nil];
        NSData* data = [NSKeyedArchiver archivedDataWithRootObject:dict];
#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
        [data writeToFile:[self userPath] options:NSDataWritingAtomic|NSDataWritingFileProtectionComplete error:nil];
#else
        [data writeToFile:[self userPath] options:NSDataWritingAtomic error:nil];
#endif
    }
}

- (void)logout {
    [self setCurrentUser:nil withAuthCode:nil];
}

- (NSString*)userPath {
    return [self.basePath stringByAppendingPathComponent:@"user"];
}

- (void)loginWithEmail:(NSString*)email password:(NSString*)password join:(NSString*)joins params:(NSArray*)params success:(SuccessObjectBlock)success failure:(FailureBlock)failure {
    NSMutableDictionary* body = [[NSMutableDictionary alloc] init];
    [body setObject:email forKey:@"email"];
    [body setObject:password forKey:@"password"];
    if (joins) {
        [body setObject:joins forKey:@"joins"];
        if (params) {
            [body setObject:[BBUtils stringsFromParams:params] forKey:@"params"];
        }
    }
    
    [self perform:@"POST" path:@"/user/email/login" params:body fetchPolicy:BBFetchPolicyRemoteOnly success:^(id result, BOOL fromCache) {
        if (![result isKindOfClass:[NSDictionary class]]) {
            if (failure) {
                failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            }
            return;
        }
        
        NSString* status = [result stringForKey:@"status"];
        if (!status) {
            if (failure) {
                failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            }
            return;
        }
        
        if (![status isEqualToString:@"Success"] && ![status isEqualToString:@"PendingValidation"]) {
            if (failure) {
                failure([BBError errorWithStatus:status result:result]);
            }
            return;
        }
        
        BBObject *user = [self loginEmailWithResponse:result];
        if (success) {
            success(user);
        }
    } failure:^(id result, NSError* error) {
        if (failure) {
            failure([BBError errorWithResult:result error:error]);
        }
    }];
}

- (BBObject*)loginEmailWithResponse:(NSDictionary*)result {
    BBObject* user = nil;
    NSDictionary* values = [result dictionaryForKey:@"objects"];
    NSString* identifier = [result stringForKey:@"id"];
    NSString* auth = [result stringForKey:@"auth"];
    if (values && identifier && auth) {
        NSMutableDictionary* refs = [BBObject objectsWithSession:self values:values references:nil];
        user = [refs objectForKey:identifier];
        [self setCurrentUser:user withAuthCode:auth];
    }
    return user;
}

- (void)requestPasswordResetWithEmail:(NSString*)email success:(SuccessBlock)success failure:(FailureBlock)failure {
    NSDictionary* body = [NSDictionary dictionaryWithObject:email forKey:@"email"];
    [self perform:@"POST" path:@"/user/email/lostpassword" params:body fetchPolicy:BBFetchPolicyRemoteOnly success:^(id result, BOOL fromCache) {
        if (![result isKindOfClass:[NSDictionary class]]) {
            if (failure) {
                failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            }
            return;
        }
        
        NSString* status = [result stringForKey:@"status"];
        if (!status) {
            if (failure) {
                failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            }
            return;
        }
        
        if (![status isEqualToString:@"Success"]) {
            if (failure) {
                failure([BBError errorWithStatus:status result:result]);
            }
            return;
        }
        if (success) {
            success();
        }
    } failure:^(id result, NSError* error) {
        if (failure) {
            failure([BBError errorWithResult:result error:error]);
        }
    }];
}

- (void)verifyCode:(NSString*)code join:(NSString*)joins params:(NSArray*)params success:(SuccessObjectBlock)success failure:(FailureBlock)failure {
    NSMutableDictionary* body = [NSMutableDictionary dictionaryWithObject:code forKey:@"code"];
    if (joins) {
        [body setObject:joins forKey:@"joins"];
        if (params) {
            [body setObject:[BBUtils stringsFromParams:params] forKey:@"params"];
        }
    }
    [self perform:@"POST" path:@"/user/email/verify" params:body fetchPolicy:BBFetchPolicyRemoteOnly success:^(id result, BOOL fromCache) {
        if (![result isKindOfClass:[NSDictionary class]]) {
            if (failure) {
                failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            }
            return;
        }
        
        NSString* status = [result stringForKey:@"status"];
        if (!status) {
            if (failure) {
                failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            }
            return;
        }
        
        if (![status isEqualToString:@"Success"] && ![status isEqualToString:@"PendingValidation"]) {
            if (failure) {
                failure([BBError errorWithStatus:status result:result]);
            }
            return;
        }
        
        BBObject *user = [self loginEmailWithResponse:result];
        if (success) {
            success(user);
        }
    } failure:^(id result, NSError* error) {
        if (failure) {
            failure([BBError errorWithResult:result error:error]);
        }
    }];
}

- (void)socialSignup:(NSString*)provider
              params:(NSDictionary*)params
             success:(SuccessSocialSignupBlock)success
             failure:(FailureSocialSignupBlock)failure {
    
    NSString* path = [NSString stringWithFormat:@"/user/%@/signup", provider];
    [self perform:@"POST" path:path params:params fetchPolicy:BBFetchPolicyRemoteOnly success:^(id result, BOOL fromCache) {
        
        if (![result isKindOfClass:[NSDictionary class]]) {
            if (failure) {
                failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            }
            return;
        }
        
        NSDictionary* dict = (NSDictionary*)result;
        NSString* status = [result stringForKey:@"status"];
        BOOL isNew = [status isEqualToString:@"Success"];
        if (!isNew && ![status isEqualToString:@"UserAlreadyExists"]) {
            if (failure) {
                failure([BBError errorWithStatus:status result:result]);
            }
            return;
        }
        
        NSDictionary* values = [dict dictionaryForKey:@"objects"];
        NSString* identifier = [dict stringForKey:@"id"];
        NSString* auth = [dict stringForKey:@"auth"];
        if (!values || !identifier || !auth) {
            if (failure) {
                failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            }
            return;
        }
        
        NSDictionary* objects = [BBObject objectsWithSession:self values:values references:nil];
        BBObject* user = [objects objectForKey:identifier];
        [self setCurrentUser:user withAuthCode:auth];
        if (success) {
            success(user, isNew);
        }
    } failure:^(id result, NSError* error) {
        if (failure) {
            failure([BBError errorWithResult:result error:error]);
        }
    }];
}

- (void)twitterSignupWithOAuthToken:(NSString*)oauthToken
                   oauthTokenSecret:(NSString*)oauthTokenSecret
                            success:(SuccessSocialSignupBlock)success
                            failure:(FailureSocialSignupBlock)failure {
    
    NSMutableDictionary* postParams = [NSMutableDictionary dictionaryWithObjectsAndKeys:oauthToken, @"oauth_token",
                                       oauthTokenSecret, @"oauth_token_secret", nil];
    
    [self socialSignup:@"twitter" params:postParams success:^(BBObject* user, BOOL isNew) {
        if (success) {
            success(user, isNew);
        }
    } failure:^(NSError* err) {
        if (failure) {
            failure(err);
        }
    }];
    
}

- (void)twitterSignupWithOAuthToken:(NSString*)oauthToken
                   oauthTokenSecret:(NSString*)oauthTokenSecret
                               join:(NSString*)join
                             params:(NSArray*)params
                            success:(SuccessSocialSignupBlock)success
                            failure:(FailureSocialSignupBlock)failure {
    
    NSMutableDictionary* postParams = [NSMutableDictionary dictionaryWithObjectsAndKeys:oauthToken, @"oauth_token",
                                       oauthTokenSecret, @"oauth_token_secret", nil];
    if (join) {
        [postParams setObject:join forKey:@"joins"];
        if (params) {
            [postParams setObject:params forKey:@"params"];
        }
    }
    [self socialSignup:@"twitter" params:postParams success:^(BBObject* user, BOOL isNew) {
        if (success) {
            success(user, isNew);
        }
    } failure:^(NSError* err) {
        if (failure) {
            failure(err);
        }
    }];
    
}

- (void)facebookSignupWithAccessToken:(NSString*)accessToken
                              success:(SuccessFacebookBlock)success
                              failure:(FailureFacebookBlock)failure {
    
    NSDictionary* postParams = [NSDictionary dictionaryWithObject:accessToken forKey:@"access_token"];
    [self socialSignup:@"facebook" params:postParams success:^(BBObject* user, BOOL isNew) {
        if (success) {
            success(user, isNew);
        }
    } failure:^(NSError* err) {
        if (failure) {
            failure(err);
        }
    }];

}

- (void)facebookSignupWithAccessToken:(NSString*)accessToken
                                 join:(NSString*)join
                               params:(NSArray*)params
                              success:(SuccessFacebookBlock)success
                              failure:(FailureFacebookBlock)failure {
    
    NSMutableDictionary* postParams = [NSMutableDictionary dictionaryWithObject:accessToken forKey:@"access_token"];
    if (join) {
        [postParams setObject:join forKey:@"joins"];
        if (params) {
            [postParams setObject:params forKey:@"params"];
        }
    }
    [self socialSignup:@"facebook" params:postParams success:^(BBObject* user, BOOL isNew) {
        if (success) {
            success(user, isNew);
        }
    } failure:^(NSError* err) {
        if (failure) {
            failure(err);
        }
    }];
    
}

- (void)googlePlusSignupWithAccessToken:(NSString*)accessToken
                                success:(SuccessFacebookBlock)success
                                failure:(FailureFacebookBlock)failure {
    
    NSDictionary* postParams = [NSDictionary dictionaryWithObject:accessToken forKey:@"access_token"];
    [self socialSignup:@"googleplus" params:postParams success:^(BBObject* user, BOOL isNew) {
        if (success) {
            success(user, isNew);
        }
    } failure:^(NSError* err) {
        if (failure) {
            failure(err);
        }
    }];
    
}

- (void)googlePlusSignupWithAccessToken:(NSString*)accessToken
                                   join:(NSString*)join
                                 params:(NSArray*)params
                                success:(SuccessFacebookBlock)success
                                failure:(FailureFacebookBlock)failure {
    
    NSMutableDictionary* postParams = [NSMutableDictionary dictionaryWithObject:accessToken forKey:@"access_token"];
    if (join) {
        [postParams setObject:join forKey:@"joins"];
        if (params) {
            [postParams setObject:params forKey:@"params"];
        }
    }
    [self socialSignup:@"googleplus" params:postParams success:^(BBObject* user, BOOL isNew) {
        if (success) {
            success(user, isNew);
        }
    } failure:^(NSError* err) {
        if (failure) {
            failure(err);
        }
    }];
    
}

- (BBQuery*)queryForEntity:(NSString*)entity {
    return [[BBQuery alloc] initWith:self entity:entity];
}

- (BBObject*)emptyObjectForEntity:(NSString*)entity {
    return [[BBObject alloc] initWith:self entity:entity];
}

- (BBObject*)emptyObjectForEntity:(NSString*)entity withIdentifier:(NSString*)identifier {
    return [[BBObject alloc] initWith:self entity:entity identifier:identifier];
}

- (BBObject*)readObject:(NSString*)entity
         withIdentifier:(NSString*)identifier
                   join:(NSString*)joins
                 params:(NSArray*)params
                success:(SuccessObjectBlock)success
                failure:(FailureObjectBlock)failure {
    
    BBObject *object = [self emptyObjectForEntity:entity withIdentifier:identifier];
    [object refresh:joins params:params success:success failure:failure];
    return object;
}

+ (BackbeamSession*)instance {
    static BackbeamSession *inst = nil;
    @synchronized(self) {
        if (!inst) {
            inst = [[self alloc] initInstance];
            inst.host = @"backbeamapps.com";
            inst.port = 80;
            inst.env  = @"dev";
        }
    }
    return inst;
}

@end

@implementation Backbeam

+ (void)setHost:(NSString*)host port:(NSInteger)port {
    [[BackbeamSession instance] setHost:host port:port];
}

+ (void)setWebVersion:(NSString*)webVersion {
    [[BackbeamSession instance] setWebVersion:webVersion];
}

+ (void)setHttpAuth:(NSString*)httpAuth {
    [[BackbeamSession instance] setHttpAuth:httpAuth];
}

+ (void)setProject:(NSString*)project sharedKey:(NSString*)sharedKey secretKey:(NSString*)secretKey environment:(NSString*)env {
    [[BackbeamSession instance] setProject:project sharedKey:sharedKey secretKey:secretKey environment:env];
}

+ (void)setTwitterConsumerKey:(NSString *)twitterConsumerKey consumerSecret:(NSString*)twitterConsumerSecret {
    [[BackbeamSession instance] setTwitterConsumerKey:twitterConsumerKey consumerSecret:twitterConsumerSecret];
}

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
+ (BBTwitterLoginViewController*)twitterLoginViewController {
    return [[BackbeamSession instance] twitterLoginViewController];
}

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000
+ (void)twitterReverseOAuthWithAccount:(ACAccount*)account success:(SuccessReverseOauthBlock)success failure:(FailureReverseOauthBlock)failure {
    [[BackbeamSession instance] twitterReverseOAuthWithAccount:account success:success failure:failure];
}
#endif
#endif

+ (void)persistDeviceToken:(NSData*)data {
    [[BackbeamSession instance] persistDeviceToken:data];
}

+ (void)subscribeToChannels:(NSArray*)channels success:(SuccessBlock)success failure:(FailureBlock)failure {
    [[BackbeamSession instance] subscribeToChannels:channels success:success failure:failure];
}

+ (void)subscribeToChannels:(NSArray*)channels {
    [[BackbeamSession instance] subscribeToChannels:channels success:nil failure:^(NSError* err){}];
}

+ (void)subscribedChannels:(SuccessArrayBlock)success
                   failure:(FailureBlock)failure {
    
    [[BackbeamSession instance] subscribedChannels:success failure:failure];
    
}

+ (void)unsubscribeFromAllChannels:(SuccessBlock)success
                           failure:(FailureBlock)failure {
    
    [[BackbeamSession instance] unsubscribeFromAllChannels:success failure:failure];
    
}

+ (void)unsubscribeFromChannels:(NSArray*)channels success:(SuccessBlock)success failure:(FailureBlock)failure {
    [[BackbeamSession instance] unsubscribeFromChannels:channels success:success failure:failure];
}

+ (void)unsubscribeFromChannels:(NSArray*)channels {
    [[BackbeamSession instance] unsubscribeFromChannels:channels success:nil failure:^(NSError* err){}];
}

+ (void)sendPushNotification:(BBPushNotification*)notification toChannel:(NSString*)channel success:(SuccessBlock)success failure:(FailureBlock)failure {
    [[BackbeamSession instance] sendPushNotification:notification toChannel:channel success:success failure:failure];
}

+ (void)sendPushNotification:(BBPushNotification*)notification toChannel:(NSString*)channel {
    [[BackbeamSession instance] sendPushNotification:notification toChannel:channel success:^{} failure:^(NSError* err){}];
}

+ (BBObject*)currentUser {
    return [BackbeamSession instance]._currentUser;
}

+ (void)logout {
    [[BackbeamSession instance] logout];
}

+ (void)loginWithEmail:(NSString*)email password:(NSString*)password join:(NSString*)joins params:(NSArray*)params success:(SuccessObjectBlock)success failure:(FailureBlock)failure {
    [[BackbeamSession instance] loginWithEmail:email password:password join:joins params:(NSArray*)params success:success failure:failure];
}

+ (void)loginWithEmail:(NSString*)email password:(NSString*)password success:(SuccessObjectBlock)success failure:(FailureBlock)failure {
    [[BackbeamSession instance] loginWithEmail:email password:password join:nil params:nil success:success failure:failure];
}

+ (void)twitterSignupWithOAuthToken:(NSString*)oauthToken
                   oauthTokenSecret:(NSString*)oauthTokenSecret
                            success:(SuccessSocialSignupBlock)success
                            failure:(FailureSocialSignupBlock)failure {
    [[BackbeamSession instance] twitterSignupWithOAuthToken:oauthToken oauthTokenSecret:oauthTokenSecret success:success failure:failure];
}

+ (void)twitterSignupWithOAuthToken:(NSString*)oauthToken
                   oauthTokenSecret:(NSString*)oauthTokenSecret
                               join:(NSString*)join
                             params:(NSArray*)params
                            success:(SuccessSocialSignupBlock)success
                            failure:(FailureSocialSignupBlock)failure {
    [[BackbeamSession instance] twitterSignupWithOAuthToken:oauthToken oauthTokenSecret:oauthTokenSecret join:join params:params success:success failure:failure];
}

+ (void)facebookSignupWithAccessToken:(NSString*)accessToken
                              success:(SuccessFacebookBlock)success
                              failure:(FailureFacebookBlock)failure {
    [[BackbeamSession instance] facebookSignupWithAccessToken:accessToken success:success failure:failure];
}


+ (void)facebookSignupWithAccessToken:(NSString*)accessToken
                                 join:(NSString*)join
                               params:(NSArray*)params
                              success:(SuccessFacebookBlock)success
                              failure:(FailureFacebookBlock)failure {
    [[BackbeamSession instance] facebookSignupWithAccessToken:accessToken join:join params:params success:success failure:failure];
}

+ (void)googlePlusSignupWithAccessToken:(NSString*)accessToken
                                success:(SuccessFacebookBlock)success
                                failure:(FailureFacebookBlock)failure {
    [[BackbeamSession instance] googlePlusSignupWithAccessToken:accessToken success:success failure:failure];
}


+ (void)googlePlusSignupWithAccessToken:(NSString*)accessToken
                                   join:(NSString*)join
                                 params:(NSArray*)params
                                success:(SuccessFacebookBlock)success
                                failure:(FailureFacebookBlock)failure {
    [[BackbeamSession instance] googlePlusSignupWithAccessToken:accessToken join:join params:params success:success failure:failure];
}

+ (BBQuery*)queryForEntity:(NSString*)entity {
    return [[BackbeamSession instance] queryForEntity:entity];
}

+ (void)requestPasswordResetWithEmail:(NSString*)email success:(SuccessBlock)success failure:(FailureBlock)failure {
    return [[BackbeamSession instance] requestPasswordResetWithEmail:email success:success failure:failure];
}

+ (void)verifyCode:(NSString*)code success:(SuccessObjectBlock)success failure:(FailureBlock)failure {
    return [[BackbeamSession instance] verifyCode:code join:nil params:nil success:success failure:failure];
}

+ (void)verifyCode:(NSString*)code join:(NSString*)joins params:(NSArray*)params success:(SuccessObjectBlock)success failure:(FailureBlock)failure {
    return [[BackbeamSession instance] verifyCode:code join:joins params:nil success:success failure:failure];
}

+ (BBObject*)emptyObjectForEntity:(NSString*)entity {
    return [[BackbeamSession instance] emptyObjectForEntity:entity];
}

+ (BBObject*)emptyObjectForEntity:(NSString*)entity withIdentifier:(NSString*)identifier {
    return [[BackbeamSession instance] emptyObjectForEntity:entity withIdentifier:identifier];
}

+ (BBObject*)readObject:(NSString*)entity
         withIdentifier:(NSString*)identifier
                   join:(NSString*)joins
                 params:(NSArray*)params
                success:(SuccessObjectBlock)success
                failure:(FailureObjectBlock)failure {
    return [[BackbeamSession instance] readObject:entity withIdentifier:identifier join:joins params:params success:success failure:failure];
}

+ (BBObject*)readObject:(NSString*)entity
         withIdentifier:(NSString*)identifier
                success:(SuccessObjectBlock)success
                failure:(FailureObjectBlock)failure {
    return [[BackbeamSession instance] readObject:entity withIdentifier:identifier join:nil params:nil success:success failure:failure];
}

+ (void)requestJSONFromController:(NSString*)path
                           method:(NSString*)method
                           params:(NSDictionary*)params
                      fetchPolicy:(BBFetchPolicy)fetchPolicy
                          success:(SuccessOperationBlock)success
                          failure:(FailureOperationBlock)failure {
    [[BackbeamSession instance] requestJSONFromController:path method:method params:params fetchPolicy:fetchPolicy progress:nil success:success failure:failure];
}

+ (void)requestObjectsFromController:(NSString*)path
                              method:(NSString*)method
                              params:(NSDictionary*)params
                         fetchPolicy:(BBFetchPolicy)fetchPolicy
                             success:(SuccessNearQueryBlock)success
                             failure:(FailureQueryBlock)failure {
    [[BackbeamSession instance] requestObjectsFromController:path method:method params:params fetchPolicy:fetchPolicy progress:nil success:success failure:failure];
}

+ (void)requestJSONFromController:(NSString*)path
                           method:(NSString*)method
                           params:(NSDictionary*)params
                      fetchPolicy:(BBFetchPolicy)fetchPolicy
                         progress:(ProgressDataBlock)progress
                          success:(SuccessOperationBlock)success
                          failure:(FailureOperationBlock)failure {
    
    [[BackbeamSession instance] requestJSONFromController:path
                                                   method:method
                                                   params:params
                                              fetchPolicy:fetchPolicy
                                                 progress:progress
                                                  success:success
                                                  failure:failure];
}

+ (void)requestObjectsFromController:(NSString*)path
                              method:(NSString*)method
                              params:(NSDictionary*)params
                         fetchPolicy:(BBFetchPolicy)fetchPolicy
                            progress:(ProgressDataBlock)progress
                             success:(SuccessNearQueryBlock)success
                             failure:(FailureQueryBlock)failure {
    
    [[BackbeamSession instance] requestObjectsFromController:path
                                                      method:method
                                                      params:params
                                                 fetchPolicy:fetchPolicy
                                                    progress:progress
                                                     success:success
                                                     failure:failure];
}

+ (void)requestDataFromController:(NSString*)path
                           method:(NSString*)method
                           params:(NSDictionary*)params
                      fetchPolicy:(BBFetchPolicy)fetchPolicy
                   uploadProgress:(ProgressDataBlock)uploadProgress
                 downloadProgress:(ProgressDataBlock)downloadProgress
                          success:(SuccessDataBlock)success
                          failure:(FailureBlock)failure {
    
    [[BackbeamSession instance] requestDataFromController:path
                                                   method:method
                                                   params:params
                                              fetchPolicy:fetchPolicy
                                           uploadProgress:uploadProgress
                                         downloadProgress:downloadProgress
                                                  success:^(NSData *result, BOOL fromCache, NSHTTPURLResponse *response) {
                                                      success(result);
                                                  }
                                                  failure:^(NSData *result, NSError *error) {
                                                      failure(error);
                                                  }];
}

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
+ (void)enableRealTime {
    [[BackbeamSession instance] enableRealTime];
}

+ (void)disableRealTime {
    [[BackbeamSession instance] disableRealTime];
}

+ (BOOL)subscribeToRealTimeEvents:(NSString*)event delegate:(id<BBRealTimeEventDelegate>)delegate {
    return [[BackbeamSession instance] subscribeToRealTimeEvents:event delegate:delegate];
}

+ (BOOL)unsubscribeFromRealTimeEvents:(NSString*)event delegate:(id<BBRealTimeEventDelegate>)delegate {
    return [[BackbeamSession instance] unsubscribeFromRealTimeEvents:event delegate:delegate];
}

+ (NSArray*)subscribedRealTimeEvents {
    return [[BackbeamSession instance] subscribedRealTimeEvents];
}

+ (void)unsubscribeAllRealTimeEventDelegates {
    [[BackbeamSession instance] unsubscribeAllRealTimeEventDelegates];
}

+ (void)unsubscribeAllRealTimeConnectionDelegates {
    [[BackbeamSession instance] unsubscribeAllRealTimeConnectionDelegates];
}

+ (BOOL)isRealTimeEnabled {
    return [[BackbeamSession instance] isRealTimeEnabled];
}

+ (BOOL)isRealTimeConnected {
    return [[BackbeamSession instance] isRealTimeConnected];
}

+ (void)subscribeToRealTimeConnectionEvents:(id<BBRealTimeConnectionDelegate>)delegate {
    [[BackbeamSession instance] subscribeToRealTimeConnectionEvents:delegate];
}

+ (void)unsubscribeFromRealTimeConnectionEvents:(id<BBRealTimeConnectionDelegate>)delegate {
    [[BackbeamSession instance] unsubscribeFromRealTimeConnectionEvents:delegate];
}

+ (BOOL)sendRealTimeEvent:(NSString*)event message:(NSDictionary*)message {
    return [[BackbeamSession instance] sendRealTimeEvent:event message:message];
}
#endif

+ (void)setProtocol:(NSString *)protocol {
    [[BackbeamSession instance] setProtocol:protocol];
}

+ (NSString*)mimeTypeForFile:(NSString*)fileName {
    return [[BackbeamSession instance] mimeTypeForFile:fileName];
}

@end
