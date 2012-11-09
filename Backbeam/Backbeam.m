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
    }
    return self;
}

- (void)setHost:(NSString*)host port:(NSInteger)port {
    self.host = host;
    self.port = port;
}

- (void)setProject:(NSString*)project sharedKey:(NSString*)sharedKey secretKey:(NSString*)secretKey environment:(NSString*)env {
    self.project = project;
    self.sharedKey = sharedKey;
    self.secretKey = secretKey;
    self.env = env;
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

- (void)perform:(NSString*)httpMethod path:(NSString*)path params:(NSDictionary*)params body:(NSDictionary*)body success:(SuccessOperationBlock)success failure:(FailureOperationBlock)failure {
    
    NSString* url = [@"http://" stringByAppendingFormat:@"api.%@.%@.%@:%d%@", self.env, self.project, self.host, self.port, path];
    if (params) {
        url = [url stringByAppendingFormat:@"?%@", [BBUtils queryString:params]];
    }
    // NSLog(@"%@ %@", httpMethod, url);
    NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [req setHTTPMethod:httpMethod];
    if (body) {
        NSString* bodyString = [BBUtils queryString:body];
        [req setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
        [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    }
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:req success:^(NSURLRequest* req, NSHTTPURLResponse* resp, id result) {
        success(result);
    } failure:^(NSURLRequest* req, NSHTTPURLResponse* resp, NSError* err, id result) {
        failure(result, err);
    }];
    [operation start];
}

- (UIImage*)image:(NSString*)identifier withSize:(CGSize)size success:(SuccessImageBlock)success {
    
    CGFloat scale = [UIScreen mainScreen].scale;
    int width  = (int)(size.width *scale);
    int height = (int)(size.height*scale);
    
    NSString* url = [@"http://" stringByAppendingFormat:@"%@.%@:%d/file/%@/%@?width=%d&height=%d",
                     self.project, self.host, self.port, self.env, identifier, width, height];
    
    UIImage* img = [self.cache objectForKey:url];
    if (img) return img;
    
    NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    
    AFHTTPRequestOperation* operation = [[AFHTTPRequestOperation alloc] initWithRequest:req];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation* operation, id response) {
        if (response) { // TODO: isKindOfClass:[NSData data] but was __NSCFData
            NSData* data = (NSData*)response;
            UIImage* img = [UIImage imageWithData:data scale:scale];
            // TODO: http://ioscodesnippet.tumblr.com/post/10924101444/force-decompressing-uiimage-in-background-to-achieve
            [self.cache setObject:img forKey:url];
            success(img);
        } else {
            // TODO error with unexpected response
        }
    } failure:^(AFHTTPRequestOperation* operation, NSError* error) {
        // TODO
        NSLog(@"error %@", error);
    }];
    [operation start];
    
    return nil;
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
    
    [self perform:@"POST" path:@"/push/subscribe" params:nil body:body success:^(id result) {
        [self processBasicResponse:result success:success failure:failure];
    } failure:^(id result, NSError* err) {
        [self processBasicFailure:result error:err failure:failure];
    }];
    return YES;
}

- (BOOL)unsubscribeFromChannels:(NSArray*)channels success:(SuccessBlock)success failure:(FailureBlock)failure {
    if (!self.deviceToken) return NO;
    NSDictionary* body = [[NSDictionary alloc] initWithObjectsAndKeys:channels, @"channels", self.deviceToken, @"token", @"apn", @"gateway", nil];
    
    [self perform:@"POST" path:@"/push/unsubscribe" params:nil body:body success:^(id result) {
        [self processBasicResponse:result success:success failure:failure];
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
    if (status) {
        failure([BBError errorWithStatus:status result:result]);
        return;
    }
    
    success();
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
    
    [self perform:@"POST" path:@"/push/send" params:nil body:body success:^(id result) {
        [self processBasicResponse:result success:success failure:failure];
    } failure:^(id result, NSError* err) {
        [self processBasicFailure:result error:err failure:failure];
    }];
}

- (void)setLoggedUser:(BBObject*)user {
    self._loggedUser = user;
    NSString* path = [self.basePath stringByAppendingPathComponent:@"user"];
    if (user == nil) {
        // TODO: logout
    } else {
        // TODO: persist information
    }
    NSLog(@"user %@", path);
}

- (void)logout {
    [self setLoggedUser:nil];
}

- (void)loadLoggedUser {
    // NSString* path = [self.basePath stringByAppendingPathComponent:@"user"];
}

- (void)loginWithEmail:(NSString*)email password:(NSString*)password success:(SuccessObjectBlock)success failure:(FailureBlock)failure {
    NSMutableDictionary* body = [[NSMutableDictionary alloc] init];
    [body setObject:email forKey:@"email"];
    [body setObject:password forKey:@"password"];
    
    [self perform:@"POST" path:@"/user/email/login" params:nil body:body success:^(id result) {
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
    [self perform:@"POST" path:@"/user/email/lostpassword" params:nil body:body success:^(id result) {
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
    return [[BBObject alloc] initWith:self entity:entity andIdentifier:identifier];
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
