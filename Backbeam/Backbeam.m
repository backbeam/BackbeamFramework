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

@interface BackbeamSession ()

@property (nonatomic, strong) AFHTTPClient* client;

@property (nonatomic, strong) NSString* host;
@property (nonatomic, assign) NSInteger port;

@property (nonatomic, strong) NSString* project;
@property (nonatomic, strong) NSString* env;
@property (nonatomic, strong) NSString* sharedKey;
@property (nonatomic, strong) NSString* secretKey;

@property (nonatomic, strong) NSString* twitterConsumerKey;
@property (nonatomic, strong) NSString* twitterConsumerSecret;

@property (nonatomic, strong) NSString* deviceToken;
@property (nonatomic, strong) NSString* basePath;

@property (nonatomic, strong) NSCache* cache;
@property (nonatomic, strong) BBObject* _loggedUser;

@property (nonatomic, strong) NSDictionary* knownMimeTypes;

@end

@interface Backbeam ()

@end

@implementation BackbeamSession

#define kDeviceTokenPathComponent @"deviceToken"

- (id)init {
    return nil;
}

- (id)initInstance
{
    self = [super init];
    if (self) {
        self.cache = [[NSCache alloc] init];
        NSString* path = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        path = [path stringByAppendingPathComponent:@"Private Documents"];
        path = [path stringByAppendingPathComponent:@"Backbeam"];
        // TODO: handle error
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        self.basePath = path;
        path = [self.basePath stringByAppendingPathComponent:kDeviceTokenPathComponent];
        // TODO: handle error
        self.deviceToken = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        self._loggedUser = [[BBObject alloc] initWith:self entity:@"user" file:[self userPath]];
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

- (void)perform:(NSString*)httpMethod
           path:(NSString*)path
         params:(NSDictionary*)params
        success:(SuccessOperationBlock)success
        failure:(FailureOperationBlock)failure {
    
    NSMutableURLRequest* req = [self.client requestWithMethod:httpMethod path:path parameters:params];
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:req success:^(NSURLRequest* req, NSHTTPURLResponse* resp, id result) {
        success(result);
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
       success:(SuccessOperationBlock)success
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
    NSLog(@"fileName %@ mimeType %@", fileName, mimeType);
    
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
        [operation setUploadProgressBlock:^(NSInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
            progress(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
        }];
    }
    [operation start];
}

- (UIImage*)image:(NSString*)identifier
         withSize:(CGSize)size
         progress:(ProgressDataBlock)progress
          success:(SuccessImageBlock)success
          failure:(FailureBlock)failure {
    
    CGFloat scale = [UIScreen mainScreen].scale;
    NSString* width  = [NSString stringWithFormat:@"%d", (int)(size.width *scale)];
    NSString* height = [NSString stringWithFormat:@"%d", (int)(size.height*scale)];
    
    NSString* path = [@"/data/file/download/" stringByAppendingString:identifier];
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:width, @"width", height, @"height", nil];
    NSMutableURLRequest* req = [self.client requestWithMethod:@"GET" path:path parameters:params];
    
    NSString* url = [req.URL description];
    UIImage* img = [self.cache objectForKey:url];
    if (img) return img;
    
    [self download:req progress:progress success:^(NSData* data) {
        UIImage* img = [UIImage imageWithData:data scale:scale];
        // TODO: http://ioscodesnippet.tumblr.com/post/10924101444/force-decompressing-uiimage-in-background-to-achieve
        if (img) {
            [self.cache setObject:img forKey:url];
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
        [operation setDownloadProgressBlock:^(NSInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
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
    
    [self perform:@"POST" path:@"/push/subscribe" params:body success:^(id result) {
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
    
    [self perform:@"POST" path:@"/push/unsubscribe" params:body success:^(id result) {
        [self processBasicResponse:result success:^(id result) {
            success();
        } failure:failure];
    } failure:^(id result, NSError* err) {
        [self processBasicFailure:result error:err failure:failure];
    }];
    return YES;
}

- (void)processBasicResponse:(id)result success:(SuccessOperationBlock)success failure:(FailureBlock)failure {
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
    
    [self perform:@"POST" path:@"/push/send" params:body success:^(id result) {
        [self processBasicResponse:result success:success failure:failure];
    } failure:^(id result, NSError* err) {
        [self processBasicFailure:result error:err failure:failure];
    }];
}

- (void)setLoggedUser:(BBObject*)user {
    self._loggedUser = user;
    if (user == nil) {
        [[NSFileManager defaultManager] removeItemAtPath:[self userPath] error:nil]; // TODO: handle error
    } else {
        [user saveToFile:[self userPath]];
    }
}

- (void)logout {
    [self setLoggedUser:nil];
}

- (NSString*)userPath {
    return [self.basePath stringByAppendingPathComponent:@"user"];
}

- (void)loginWithEmail:(NSString*)email password:(NSString*)password success:(SuccessObjectBlock)success failure:(FailureBlock)failure {
    NSMutableDictionary* body = [[NSMutableDictionary alloc] init];
    [body setObject:email forKey:@"email"];
    [body setObject:password forKey:@"password"];
    
    [self perform:@"POST" path:@"/user/email/login" params:body success:^(id result) {
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
        
        BBObject* user = nil;
        NSDictionary* object = [result dictionaryForKey:@"object"];
        if (object) {
            user = [[BBObject alloc] initWith:self entity:@"user" dictionary:object references:nil identifier:nil];
            [self setLoggedUser:user];
        }
        success(user);
    } failure:^(id result, NSError* error) {
        failure([BBError errorWithResult:result error:error]);
    }];
}

- (void)requestPasswordResetWithEmail:(NSString*)email success:(SuccessBlock)success failure:(FailureBlock)failure {
    NSDictionary* body = [NSDictionary dictionaryWithObject:email forKey:@"email"];
    [self perform:@"POST" path:@"/user/email/lostpassword" params:body success:^(id result) {
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

- (BBQuery*)queryForEntity:(NSString*)entity {
    return [[BBQuery alloc] initWith:self entity:entity];
}

- (BBObject*)emptyObjectForEntity:(NSString*)entity {
    return [[BBObject alloc] initWith:self entity:entity];
}

- (BBObject*)emptyObjectForEntity:(NSString*)entity withIdentifier:(NSString*)identifier {
    return [[BBObject alloc] initWith:self entity:entity identifier:identifier];
}

+ (BackbeamSession*)instance {
    static BackbeamSession *inst = nil;
    @synchronized(self){
        if (!inst) {
            inst = [[self alloc] initInstance];
            inst.host = @"backbam.io";
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

+ (BBObject*)loggedUser {
    return [BackbeamSession instance]._loggedUser;
}

+ (void)logout {
    [[BackbeamSession instance] logout];
}

+ (void)loginWithEmail:(NSString*)email password:(NSString*)password success:(SuccessObjectBlock)success failure:(FailureBlock)failure {
    [[BackbeamSession instance] loginWithEmail:email password:password success:success failure:failure];
}

+ (BBQuery*)queryForEntity:(NSString*)entity {
    return [[BackbeamSession instance] queryForEntity:entity];
}

+ (void)requestPasswordResetWithEmail:(NSString*)email success:(SuccessBlock)success failure:(FailureBlock)failure {
    return [[BackbeamSession instance] requestPasswordResetWithEmail:email success:success failure:failure];
}

+ (BBObject*)emptyObjectForEntity:(NSString*)entity {
    return [[BackbeamSession instance] emptyObjectForEntity:entity];
}

+ (BBObject*)emptyObjectForEntity:(NSString*)entity withIdentifier:(NSString*)identifier {
    return [[BackbeamSession instance] emptyObjectForEntity:entity withIdentifier:identifier];
}

@end
