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
#import "JSONKit.h"
#import "BBError.h"

#if !__has_feature(objc_arc)
#error Backbeam must be built with ARC.
// If you want to turn ARC on only for Backbeam files, add -fobjc-arc to the build phase for each of its files.
#endif

@interface BackbeamSession ()

@property (nonatomic, strong) AFHTTPClient* client;

@property (nonatomic, strong) NSString* host;
@property (nonatomic, assign) NSInteger port;

@property (nonatomic, strong) NSString* project;
@property (nonatomic, strong) NSString* env;
@property (nonatomic, strong) NSString* sharedKey;
@property (nonatomic, strong) NSString* secretKey;
@property (nonatomic, strong) NSString* authCode;

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
@property (nonatomic, strong) SocketIO *socketio;
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
    }
    return self;
}

- (void)setHost:(NSString*)host port:(NSInteger)port {
    self.host = host;
    self.port = port;
}

- (void)setProject:(NSString*)project sharedKey:(NSString*)sharedKey secretKey:(NSString*)secretKey environment:(NSString*)env {
    self.project   = project;
    self.sharedKey = sharedKey;
    self.secretKey = secretKey;
    self.env = env;
    NSString* url = [@"http://" stringByAppendingFormat:@"api.%@.%@.%@:%d",
                     self.env, self.project, self.host, self.port];
    self.client = [[AFHTTPClient alloc] initWithBaseURL:[NSURL URLWithString:url]];
}

- (void)connect {
    for (id<BBRealTimeConnectionDelegate> delegate in self.realTimeDelegates) {
        [delegate realTimeConnecting];
    }
    self.socketio = [[SocketIO alloc] initWithDelegate:self];
    [self.socketio connectToHost:self.host onPort:self.port];
}

- (void)enableRealTime {
    if (self.socketio && !self.socketio.isConnected && !self.socketio.isConnecting) {
        self.socketio.delegate = nil;
        self.socketio = nil;
    }
    self.delay = 0;
    [self connect];
}

- (void)connectAfterDelay {
    if (self.socketio && (self.socketio.isConnecting || self.socketio.isConnected)) {
        return;
    }
    
    static NSInteger maxDelay = 10;
    
    self.delay++;
    if (self.delay >= maxDelay) {
        self.delay = maxDelay;
    }
    
    double delayInSeconds = self.delay;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
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
        [self sign:params];
        [self.socketio sendEvent:@"subscribe" withData:params];
    }
    return YES;
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
        [self sign:params];
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
        [params setObject:[message objectForKey:key] forKey:_key];
    }
    [self sign:params];
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
        [self sign:params];
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

- (void)setTwitterConsumerKey:(NSString *)twitterConsumerKey consumerSecret:(NSString*)twitterConsumerSecret {
    self.twitterConsumerKey = twitterConsumerKey;
    self.twitterConsumerSecret = twitterConsumerSecret;
}

- (BBTwitterLoginViewController*)twitterLoginViewController {
    BBTwitterLoginViewController* vc = [[BBTwitterLoginViewController alloc] initWith:self];
    vc.twitterConsumerKey = self.twitterConsumerKey;
    vc.twitterConsumerSecret = self.twitterConsumerSecret;
    return vc;
}

- (NSString*)sign:(NSMutableDictionary*)params {
    [params setObject:[BBUtils nonce] forKey:@"nonce"];
    [params setObject:self.sharedKey forKey:@"key"];
    [params setObject:[NSString stringWithFormat:@"%lld", (long long)([[NSDate date] timeIntervalSince1970]*1000)] forKey:@"time"];
    
    NSMutableString* parameterString = [[NSMutableString alloc] init];
    NSMutableString* cacheKeyString = [[NSMutableString alloc] init];
    NSArray* sortedKeys = [[params allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString* key in sortedKeys) {
        id value = [params objectForKey:key];
        if ([value isKindOfClass:[NSArray class]]) {
            NSArray* arr = [(NSArray*)value sortedArrayUsingSelector:@selector(compare:)];
            for (id val in arr) {
                [parameterString appendFormat:@"&%@=%@", key, val];
                [cacheKeyString appendFormat:@"&%@=%@", key, val];
            }
        } else {
            [parameterString appendFormat:@"&%@=%@", key, value];
            if (![key isEqualToString:@"time"] && ![key isEqualToString:@"nonce"]) {
                [cacheKeyString appendFormat:@"&%@=%@", key, value];
            }
        }
    }
    [parameterString deleteCharactersInRange:NSMakeRange(0, 1)];
    
    NSData* hmac = [BBUtils hmacSha1:[parameterString dataUsingEncoding:NSUTF8StringEncoding] withKey:[self.secretKey dataUsingEncoding:NSUTF8StringEncoding]];
    NSString* signature = [hmac base64EncodedString];
    [parameterString deleteCharactersInRange:NSMakeRange(0, 1)];
    [params setObject:signature forKey:@"signature"];
    
    return cacheKeyString;
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
    
    NSString *cacheKeyString = [self sign:params];
    [params removeObjectForKey:@"method"];
    [params removeObjectForKey:@"path"];
    
    NSString* cacheKey = nil;
    BOOL useCache    = fetchPolicy == BBFetchPolicyLocalOnly
                    || fetchPolicy == BBFetchPolicyLocalAndRemote
                    || fetchPolicy == BBFetchPolicyLocalOrRemote;
    if (useCache) {
        cacheKey = [BBUtils hexString:[BBUtils sha1:[cacheKeyString dataUsingEncoding:NSUTF8StringEncoding]]];
        NSData* data = [self.queryCache read:cacheKey];
        BOOL read = NO;
        if (data) {
            id result = [[[JSONDecoder alloc] init] objectWithData:data];
            if (result) {
                read = YES;
                success(result, YES);
                if (fetchPolicy == BBFetchPolicyLocalOrRemote) {
                    return;
                }
            }
        }
        if (fetchPolicy == BBFetchPolicyLocalOnly) {
            if (!read) {
                failure(nil, [BBError errorWithStatus:@"CachedDataNotFound" result:nil]);
            }
            return;
        }
    }
    
    NSMutableURLRequest* req = [self.client requestWithMethod:httpMethod path:path parameters:params];
    __block AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:req success:^(NSURLRequest* req, NSHTTPURLResponse* resp, id result) {
        success(result, NO);
        
        if (useCache) {
            [self.queryCache write:operation.responseData withKey:cacheKey];
        }
        
    } failure:^(NSURLRequest* req, NSHTTPURLResponse* resp, NSError* err, id result) {
        failure(result, err);
    }];
    [operation start];
}

- (void)upload:(NSString*)httpMethod
          data:(NSData*)data
      fileName:(NSString*)fileName
      mimeType:(NSString*)mimeType
          path:(NSString*)path
        params:(NSDictionary*)params
      progress:(ProgressDataBlock)progress
       success:(SuccessBlock)success
       failure:(FailureOperationBlock)failure {

    if (!mimeType) {
        mimeType = @"application/octet-stream";
    }
    
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
            mimeType = [self.knownMimeTypes stringForKey:extension];
            break;
        }
    }
    // NSLog(@"fileName %@ mimeType %@", fileName, mimeType);
    
    NSMutableURLRequest* req = [self.client multipartFormRequestWithMethod:httpMethod path:path parameters:params constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        [formData appendPartWithFileData:data name:@"file" fileName:fileName mimeType:mimeType];
    }];
    
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:req success:^(NSURLRequest* req, NSHTTPURLResponse* resp, id result) {
        [self processBasicResponse:result success:success failure:^(NSError* error) {
            failure(result, error);
        }];
    } failure:^(NSURLRequest* req, NSHTTPURLResponse* resp, NSError* err, id result) {
        [self processBasicFailure:result error:err failure:^(NSError* error) {
            failure(result, error);
        }];
    }];
    if (progress) {
        [operation setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
            progress(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
        }];
    }
    [operation start];
}

- (UIImage*)image:(NSString*)identifier
          version:(NSNumber*)version
         withSize:(CGSize)size
         progress:(ProgressDataBlock)progress
          success:(SuccessImageBlock)success
          failure:(FailureBlock)failure {
    
    CGFloat scale = [UIScreen mainScreen].scale;
    NSString* width  = [NSString stringWithFormat:@"%d", (int)(size.width *scale)];
    NSString* height = [NSString stringWithFormat:@"%d", (int)(size.height*scale)];
    
    NSString* path = [NSString stringWithFormat:@"/data/file/download/%@/%@", identifier, version];
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:width, @"width", height, @"height", nil];
    NSMutableURLRequest* req = [self.client requestWithMethod:@"GET" path:path parameters:params];
    
    NSString* url = [req.URL description];
    UIImage* img = [self.imageCache objectForKey:url];
    if (img) return img;
    
    [self download:req progress:progress success:^(NSData* data) {
        UIImage* img = [UIImage imageWithData:data scale:scale];
        // TODO: http://ioscodesnippet.tumblr.com/post/10924101444/force-decompressing-uiimage-in-background-to-achieve
        if (img) {
            [self.imageCache setObject:img forKey:url];
            success(img);
        } else {
            failure([BBError errorWithStatus:@"InvalidImage" result:nil]);
        }
    } failure:failure];
    return nil;
}

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
            success(data);
        } else {
            failure([BBError errorWithStatus:@"InvalidResponse" result:nil]);
        }
    } failure:^(AFHTTPRequestOperation* operation, NSError* error) {
        failure([BBError errorWithError:error]);
    }];
    [operation start];
}

- (void)persistDeviceToken:(NSData*)data {
    NSString* base64 = [data base64EncodedString];
    NSString* path = [self.basePath stringByAppendingPathComponent:kDeviceTokenPathComponent];
    // TODO: handle error
    [base64 writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (BOOL)subscribeToChannels:(NSArray*)channels success:(SuccessBlock)success failure:(FailureBlock)failure {
    if (!self.deviceToken) { return NO; }
    NSDictionary* body = [[NSDictionary alloc] initWithObjectsAndKeys:channels, @"channels", self.deviceToken, @"token", @"apn", @"gateway", nil];
    
    [self perform:@"POST" path:@"/push/subscribe" params:body fetchPolicy:BBFetchPolicyRemoteOnly success:^(id result, BOOL fromCache) {
        [self processBasicResponse:result success:^(id result) {
            success();
        } failure:failure];
    } failure:^(id result, NSError* err) {
        [self processBasicFailure:result error:err failure:failure];
    }];
    return YES;
}

- (BOOL)unsubscribeFromChannels:(NSArray*)channels success:(SuccessBlock)success failure:(FailureBlock)failure {
    if (!self.deviceToken) return NO;
    NSDictionary* body = [[NSDictionary alloc] initWithObjectsAndKeys:channels, @"channels", self.deviceToken, @"token", @"apn", @"gateway", nil];
    
    [self perform:@"POST" path:@"/push/unsubscribe" params:body fetchPolicy:BBFetchPolicyRemoteOnly success:^(id result, BOOL fromCache) {
        [self processBasicResponse:result success:^(id result) {
            success();
        } failure:failure];
    } failure:^(id result, NSError* err) {
        [self processBasicFailure:result error:err failure:failure];
    }];
    return YES;
}

- (void)processBasicResponse:(id)result success:(SuccessBlock)success failure:(FailureBlock)failure {
    if (![result isKindOfClass:[NSDictionary class]]) {
        failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
        return;
    }
    NSString* status = [result stringForKey:@"status"];
    if (!status) {
        failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
        return;
    }
    if (![status isEqualToString:@"Success"]) {
        failure([BBError errorWithStatus:status result:result]);
        return;
    }
    
    success(result);
}

- (void)processBasicFailure:(id)result error:(NSError*)error failure:(FailureBlock)failure {
    if (![result isKindOfClass:[NSDictionary class]]) {
        failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
        return;
    }
    
    NSString* status = [result stringForKey:@"status"];
    if (![status isEqualToString:@"Success"]) {
        failure([BBError errorWithStatus:status result:result]);
        return;
    }
    
    failure([BBError errorWithError:error]);
}

- (void)sendPushNotification:(BBPushNotification*)notification toChannel:(NSString*)channel success:(SuccessBlock)success failure:(FailureBlock)failure {
    NSMutableDictionary* body = [[NSMutableDictionary alloc] init];
    [body setObject:channel forKey:@"channel"];
    if (notification.badge) { [body setObject:[NSString stringWithFormat:@"%d", notification.badge.integerValue] forKey:@"apn_badge"]; }
    if (notification.text ) { [body setObject:notification.text  forKey:@"apn_alert"]; }
    if (notification.sound) { [body setObject:notification.sound forKey:@"apn_sound"]; }
    // TODO: apn_payload = notification.extra
    
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
        [data writeToFile:[self userPath] options:NSDataWritingAtomic|NSDataWritingFileProtectionComplete error:nil];
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
            failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            return;
        }
        
        NSString* status = [result stringForKey:@"status"];
        if (!status) {
            failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            return;
        }
        
        if (![status isEqualToString:@"Success"] && ![status isEqualToString:@"PendingValidation"]) {
            failure([BBError errorWithStatus:status result:result]);
            return;
        }
        
        BBObject *user = [self loginEmailWithResponse:result];
        success(user);
    } failure:^(id result, NSError* error) {
        failure([BBError errorWithResult:result error:error]);
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
            failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            return;
        }
        
        NSString* status = [result stringForKey:@"status"];
        if (!status) {
            failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            return;
        }
        
        if (![status isEqualToString:@"Success"]) {
            failure([BBError errorWithStatus:status result:result]);
            return;
        }
        success();
    } failure:^(id result, NSError* error) {
        failure([BBError errorWithResult:result error:error]);
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
            failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            return;
        }
        
        NSString* status = [result stringForKey:@"status"];
        if (!status) {
            failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            return;
        }
        
        if (![status isEqualToString:@"Success"] && ![status isEqualToString:@"PendingValidation"]) {
            failure([BBError errorWithStatus:status result:result]);
            return;
        }
        
        BBObject *user = [self loginEmailWithResponse:result];
        success(user);
    } failure:^(id result, NSError* error) {
        failure([BBError errorWithResult:result error:error]);
    }];
}

- (void)socialSignup:(NSString*)provider
              params:(NSDictionary*)params
             success:(SuccessSocialSignupBlock)success
             failure:(FailureSocialSignupBlock)failure {
    
    NSString* path = [NSString stringWithFormat:@"/user/%@/signup", provider];
    [self perform:@"POST" path:path params:params fetchPolicy:BBFetchPolicyRemoteOnly success:^(id result, BOOL fromCache) {
        
        if (![result isKindOfClass:[NSDictionary class]]) {
            failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            return;
        }
        
        NSDictionary* dict = (NSDictionary*)result;
        NSString* status = [result stringForKey:@"status"];
        BOOL isNew = [status isEqualToString:@"Success"];
        if (!isNew && ![status isEqualToString:@"UserAlreadyExists"]) {
            failure([BBError errorWithStatus:status result:result]);
            return;
        }
        
        NSDictionary* values = [dict dictionaryForKey:@"objects"];
        NSString* identifier = [dict stringForKey:@"id"];
        NSString* auth = [dict stringForKey:@"auth"];
        if (!values || !identifier || !auth) {
            failure([BBError errorWithStatus:@"InvalidResponse" result:result]);
            return;
        }
        
        NSDictionary* objects = [BBObject objectsWithSession:self values:values references:nil];
        BBObject* user = [objects objectForKey:identifier];
        [self setCurrentUser:user withAuthCode:auth];
        success(user, isNew);
    } failure:^(id result, NSError* error) {
        failure([BBError errorWithResult:result error:error]);
    }];
}

- (void)facebookSignupWithAccessToken:(NSString*)accessToken
                              success:(SuccessFacebookBlock)success
                              failure:(FailureFacebookBlock)failure {
    
    NSDictionary* postParams = [NSDictionary dictionaryWithObject:accessToken forKey:@"access_token"];
    [self socialSignup:@"facebook" params:postParams success:^(BBObject* user, BOOL isNew) {
        success(user, isNew);
    } failure:^(NSError* err) {
        failure(err);
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
        success(user, isNew);
    } failure:^(NSError* err) {
        failure(err);
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

+ (void)setProject:(NSString*)project sharedKey:(NSString*)sharedKey secretKey:(NSString*)secretKey environment:(NSString*)env {
    [[BackbeamSession instance] setProject:project sharedKey:sharedKey secretKey:secretKey environment:env];
}

+ (void)setTwitterConsumerKey:(NSString *)twitterConsumerKey consumerSecret:(NSString*)twitterConsumerSecret {
    [[BackbeamSession instance] setTwitterConsumerKey:twitterConsumerKey consumerSecret:twitterConsumerSecret];
}

+ (BBTwitterLoginViewController*)twitterLoginViewController {
    return [[BackbeamSession instance] twitterLoginViewController];
}

+ (void)persistDeviceToken:(NSData*)data {
    [[BackbeamSession instance] persistDeviceToken:data];
}

+ (BOOL)subscribeToChannels:(NSArray*)channels success:(SuccessBlock)success failure:(FailureBlock)failure {
    return [[BackbeamSession instance] subscribeToChannels:channels success:success failure:failure];
}

+ (BOOL)subscribeToChannels:(NSArray*)channels {
    return [[BackbeamSession instance] subscribeToChannels:channels success:^{} failure:^(NSError* err){}];
}

+ (BOOL)unsubscribeFromChannels:(NSArray*)channels success:(SuccessBlock)success failure:(FailureBlock)failure {
    return [[BackbeamSession instance] unsubscribeFromChannels:channels success:success failure:failure];
}

+ (BOOL)unsubscribeFromChannels:(NSArray*)channels {
    return [[BackbeamSession instance] unsubscribeFromChannels:channels success:^{} failure:^(NSError* err){}];
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

+ (void)enableRealTime {
    [[BackbeamSession instance] enableRealTime];
}

+ (BOOL)subscribeToRealTimeEvents:(NSString*)event delegate:(id<BBRealTimeEventDelegate>)delegate {
    return [[BackbeamSession instance] subscribeToRealTimeEvents:event delegate:delegate];
}

+ (BOOL)unsubscribeFromRealTimeEvents:(NSString*)event delegate:(id<BBRealTimeEventDelegate>)delegate {
    return [[BackbeamSession instance] unsubscribeFromRealTimeEvents:event delegate:delegate];
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

@end
