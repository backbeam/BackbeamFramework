//
//  Backbeam.m
//  Callezeta
//
//  Created by Alberto Gimeno Brieba on 16/08/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "Backbeam.h"
#import "AFNetworking.h"
#import "BBTwitterLoginViewController.h"
#import "BBUtils.h"

#define API_ENDPOINT @"http://127.0.0.1:8080/api/"

@interface Backbeam ()

@property (nonatomic, strong) NSString* host;
@property (nonatomic, assign) NSInteger port;

@property (nonatomic, strong) NSString* project;
@property (nonatomic, strong) NSString* sharedKey;
@property (nonatomic, strong) NSString* secretKey;

@property (nonatomic, strong) NSString* twitterConsumerKey;
@property (nonatomic, strong) NSString* twitterConsumerSecret;

@property (nonatomic, strong) NSCache* cache;

@end

@implementation Backbeam

- (id)init
{
    self = [super init];
    if (self) {
        self.cache = [[NSCache alloc] init];
    }
    return self;
}

+ (Backbeam*)instance {
    static Backbeam *inst = nil;
    @synchronized(self){
        if (!inst) {
            inst = [[self alloc] init];
            inst.host = @"backbam.io";
            inst.port = 80;
        }
    }
    return inst;
}

- (void)setHost:(NSString*)host port:(NSInteger)port {
    self.host = host;
    self.port = port;
}

+ (void)setHost:(NSString*)host port:(NSInteger)port {
    [[Backbeam instance] setHost:host port:port];
}

- (void)setProject:(NSString*)project sharedKey:(NSString*)sharedKey secretKey:(NSString*)secretKey {
    self.project = project;
    self.sharedKey = sharedKey;
    self.secretKey = secretKey;
}

+ (void)setProject:(NSString*)project sharedKey:(NSString*)sharedKey secretKey:(NSString*)secretKey {
    [[Backbeam instance] setProject:project sharedKey:sharedKey secretKey:secretKey];
}

- (void)setTwitterConsumerKey:(NSString *)twitterConsumerKey consumerSecret:(NSString*)twitterConsumerSecret {
    self.twitterConsumerKey = twitterConsumerKey;
    self.twitterConsumerSecret = twitterConsumerSecret;
}

+ (void)setTwitterConsumerKey:(NSString *)twitterConsumerKey consumerSecret:(NSString*)twitterConsumerSecret {
    [[Backbeam instance] setTwitterConsumerKey:twitterConsumerKey consumerSecret:twitterConsumerSecret];
}

- (BBTwitterLoginViewController*)twitterLoginViewController {
    BBTwitterLoginViewController* vc = [[BBTwitterLoginViewController alloc] init];
    vc.twitterConsumerKey = self.twitterConsumerKey;
    vc.twitterConsumerSecret = self.twitterConsumerSecret;
    return vc;
}

+ (BBTwitterLoginViewController*)twitterLoginViewController {
    return [[Backbeam instance] twitterLoginViewController];
}

- (void)perform:(NSString*)httpMethod path:(NSString*)path params:(NSDictionary*)params body:(NSDictionary*)body success:(SuccessOperationBlock)success failure:(FailureOperationBlock)failure {

    NSString* url = [@"http://" stringByAppendingFormat:@"%@.%@:%d/api%@", self.project, self.host, self.port, path];
    if (params) {
        url = [url stringByAppendingFormat:@"?%@", [BBUtils queryString:params]];
    }
    NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [req setHTTPMethod:httpMethod];
    if (body) {
        NSString* bodyString = [BBUtils queryString:body];
        [req setHTTPBody:[bodyString dataUsingEncoding:NSUTF8StringEncoding]];
        [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    }
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:req success:^(NSURLRequest* req, NSHTTPURLResponse* resp, id JSON) {
        
        success(JSON);
    } failure:^(NSURLRequest* req, NSHTTPURLResponse* resp, NSError* err, id JSON) {
        NSLog(@"failure %@", [err localizedDescription]);
        
        failure(err);
    }];
    [operation start];
}

- (UIImage*)image:(NSString*)identifier withSize:(CGSize)size success:(SuccessImageBlock)success {
    
    CGFloat scale = [UIScreen mainScreen].scale;
    int width  = (int)(size.width *scale);
    int height = (int)(size.height*scale);
    
    NSString* url = [@"http://" stringByAppendingFormat:@"%@.%@:%d/file/%@?width=%d&height=%d",
                     self.project, self.host, self.port, identifier, width, height];
    
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
        NSLog(@"error %@", error);
    }];
    [operation start];
    
    return nil;
}


@end
