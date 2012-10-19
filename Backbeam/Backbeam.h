//
//  Backbeam.h
//  Callezeta
//
//  Created by Alberto Gimeno Brieba on 16/08/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BBTwitterLoginViewController.h"
#import "BBObject.h"
#import "BBQuery.h"

typedef void(^SuccessOperationBlock)(id result);
typedef void(^FailureOperationBlock)(NSError* err);

typedef void(^SuccessImageBlock)(UIImage* img);

@interface Backbeam : NSObject

+ (void)setHost:(NSString*)host port:(NSInteger)port;
+ (void)setProject:(NSString*)project sharedKey:(NSString*)sharedKey secretKey:(NSString*)secretKey;
+ (void)setTwitterConsumerKey:(NSString *)twitterConsumerKey consumerSecret:(NSString*)twitterConsumerSecret;
+ (BBTwitterLoginViewController*)twitterLoginViewController;

+ (Backbeam*)instance;

- (void)perform:(NSString*)httpMethod path:(NSString*)path params:(NSDictionary*)params body:(NSDictionary*)body success:(SuccessOperationBlock)success failure:(FailureOperationBlock)failure;
- (UIImage*)image:(NSString*)identifier withSize:(CGSize)size success:(SuccessImageBlock)success;

@end
