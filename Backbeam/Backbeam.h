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
#import "BBPushNotification.h"
#import "Common.h"
#import "NSDictionary+SanityChecks.h"
#import "BBError.h"

@class BBQuery;
@class BBTwitterLoginViewController;

@interface BackbeamSession : NSObject

- (UIImage*)image:(NSString*)identifier withSize:(CGSize)size success:(SuccessImageBlock)success;

- (void)setLoggedUser:(BBObject*)user;

- (void)persistDeviceToken:(NSData*)data;

- (void)perform:(NSString*)httpMethod
           path:(NSString*)path
         params:(NSDictionary*)params
           body:(NSDictionary*)body
        success:(SuccessOperationBlock)success
        failure:(FailureOperationBlock)failure;

@end

@interface Backbeam : NSObject

+ (void)setHost:(NSString*)host
           port:(NSInteger)port;

+ (void)setProject:(NSString*)project
         sharedKey:(NSString*)sharedKey
         secretKey:(NSString*)secretKey
       environment:(NSString*)env;

+ (void)setTwitterConsumerKey:(NSString *)twitterConsumerKey
               consumerSecret:(NSString*)twitterConsumerSecret;

+ (BBTwitterLoginViewController*)twitterLoginViewController;

+ (BBQuery*)queryForEntity:(NSString*)entity;

+ (BBObject*)emptyObjectForEntity:(NSString*)entity;

+ (BBObject*)emptyObjectForEntity:(NSString*)entity
                   withIdentifier:(NSString*)identifier;

+ (BOOL)subscribeToChannels:(NSArray*)channels
                    success:(SuccessBlock)success
                    failure:(FailureBlock)failure;

+ (BOOL)subscribeToChannels:(NSArray*)channels;

+ (BOOL)unsubscribeFromChannels:(NSArray*)channels
                        success:(SuccessBlock)success
                        failure:(FailureBlock)failure;
+ (BOOL)unsubscribeFromChannels:(NSArray*)channels;

+ (void)sendPushNotification:(BBPushNotification*)notification
                   toChannel:(NSString*)channel
                     success:(SuccessBlock)success
                     failure:(FailureBlock)failure;

+ (void)sendPushNotification:(BBPushNotification*)notification
                   toChannel:(NSString*)channel;

+ (BBObject*)loggedUser;

+ (void)logout;

+ (void)persistDeviceToken:(NSData*)data;

+ (void)loginWithEmail:(NSString*)email
              password:(NSString*)password
               success:(SuccessObjectBlock)success
               failure:(FailureBlock)failure;

+ (void)requestPasswordResetWithEmail:(NSString*)email
                              success:(SuccessBlock)success
                              failure:(FailureBlock)failure;

@end
