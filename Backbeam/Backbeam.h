//
//  Backbeam.h
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 16/08/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSDictionary+SanityChecks.h"
#import "Common.h"
#import "BBError.h"
#import "BBQuery.h"
#import "BBObject.h"
#import "BBLocation.h"
#import "BBJoinResult.h"
#import "BBPushNotification.h"
#import "BBTwitterLoginViewController.h"
#import "BBCollectionConstraint.h"
#import "BBFileUpload.h"

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
#import "SocketIO.h"

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000
#import <Accounts/Accounts.h>
#endif
#endif

@class BBQuery;
@class BBTwitterLoginViewController;

@protocol BBRealTimeConnectionDelegate <NSObject>

- (void)realTimeConnected;

- (void)realTimeConnecting;

- (void)realTimeDisconnected;

- (void)realTimeConnectionFailed:(NSError*)error;

@end

@protocol BBRealTimeEventDelegate <NSObject>

- (void)realTimeEventReceived:(NSString*)event message:(NSDictionary*)message;

@end

#if !defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
@protocol SocketIODelegate
@end
#endif

@interface BackbeamSession : NSObject<SocketIODelegate>

- (NSString*)mimeTypeForFile:(NSString*)fileName;

- (void)download:(NSMutableURLRequest*)request
        progress:(ProgressDataBlock)progress
         success:(SuccessDataBlock)success
         failure:(FailureBlock)failure;

- (void)downloadPath:(NSString*)path
            progress:(ProgressDataBlock)progress
             success:(SuccessDataBlock)success
             failure:(FailureBlock)failure;

- (void)upload:(NSString*)httpMethod
          data:(NSData*)data
      fileName:(NSString*)fileName
      mimeType:(NSString*)mimeType
          path:(NSString*)path
        params:(NSDictionary*)params
          sign:(BOOL)sign
      progress:(ProgressDataBlock)progress
       success:(SuccessBlock)success
       failure:(FailureOperationBlock)failure;

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
- (UIImage*)image:(NSString*)identifier
          version:(NSNumber*)version
         withSize:(CGSize)size
         progress:(ProgressDataBlock)progress
          success:(SuccessImageBlock)success
          failure:(FailureBlock)failure;
#endif

- (void)setCurrentUser:(BBObject*)user withAuthCode:(NSString*)code;

- (void)persistDeviceToken:(NSData*)data;

- (void)perform:(NSString*)httpMethod
           path:(NSString*)path
         params:(NSDictionary*)_params
    fetchPolicy:(BBFetchPolicy)fetchPolicy
        success:(SuccessOperationBlock)success
        failure:(FailureOperationBlock)failure;

- (void)socialSignup:(NSString*)provider
              params:(NSDictionary*)params
             success:(SuccessSocialSignupBlock)success
             failure:(FailureSocialSignupBlock)failure;

@end

@interface Backbeam : NSObject

+ (void)setHost:(NSString*)host
           port:(NSInteger)port;

+ (void)setProject:(NSString*)project
         sharedKey:(NSString*)sharedKey
         secretKey:(NSString*)secretKey
       environment:(NSString*)env;

+ (void)setProtocol:(NSString *)protocol;

+ (void)setTwitterConsumerKey:(NSString *)twitterConsumerKey
               consumerSecret:(NSString*)twitterConsumerSecret;

+ (BBTwitterLoginViewController*)twitterLoginViewController;

+ (void)twitterSignupWithOAuthToken:(NSString*)oauthToken
                   oauthTokenSecret:(NSString*)oauthTokenSecret
                            success:(SuccessSocialSignupBlock)success
                            failure:(FailureSocialSignupBlock)failure;

+ (void)twitterSignupWithOAuthToken:(NSString*)oauthToken
                   oauthTokenSecret:(NSString*)oauthTokenSecret
                               join:(NSString*)join
                             params:(NSArray*)params
                            success:(SuccessSocialSignupBlock)success
                            failure:(FailureSocialSignupBlock)failure;

+ (void)facebookSignupWithAccessToken:(NSString*)accessToken
                              success:(SuccessFacebookBlock)success
                              failure:(FailureFacebookBlock)failure;

+ (void)facebookSignupWithAccessToken:(NSString*)accessToken
                                 join:(NSString*)join
                               params:(NSArray*)params
                              success:(SuccessFacebookBlock)success
                              failure:(FailureFacebookBlock)failure;

+ (void)googlePlusSignupWithAccessToken:(NSString*)accessToken
                                success:(SuccessFacebookBlock)success
                                failure:(FailureFacebookBlock)failure;

+ (void)googlePlusSignupWithAccessToken:(NSString*)accessToken
                                   join:(NSString*)join
                                 params:(NSArray*)params
                                success:(SuccessFacebookBlock)success
                                failure:(FailureFacebookBlock)failure;

+ (BBQuery*)queryForEntity:(NSString*)entity;

+ (BBObject*)emptyObjectForEntity:(NSString*)entity;

+ (BBObject*)emptyObjectForEntity:(NSString*)entity
                   withIdentifier:(NSString*)identifier;

+ (BBObject*)readObject:(NSString*)entity
         withIdentifier:(NSString*)identifier
                   join:(NSString*)joins
                 params:(NSArray*)params
                success:(SuccessObjectBlock)success
                failure:(FailureObjectBlock)failure;

+ (BBObject*)readObject:(NSString*)entity
         withIdentifier:(NSString*)identifier
                success:(SuccessObjectBlock)success
                failure:(FailureObjectBlock)failure;

+ (void)subscribeToChannels:(NSArray*)channels
                    success:(SuccessBlock)success
                    failure:(FailureBlock)failure;

+ (void)subscribeToChannels:(NSArray*)channels;

+ (void)subscribedChannels:(SuccessArrayBlock)success
                   failure:(FailureBlock)failure;

+ (NSArray*)subscribedRealTimeEvents;

+ (void)unsubscribeAllRealTimeEventDelegates;

+ (void)unsubscribeAllRealTimeConnectionDelegates;

+ (BOOL)isRealTimeEnabled;

+ (BOOL)isRealTimeConnected;

+ (void)unsubscribeFromAllChannels:(SuccessBlock)success
                           failure:(FailureBlock)failure;

+ (void)unsubscribeFromChannels:(NSArray*)channels
                        success:(SuccessBlock)success
                        failure:(FailureBlock)failure;
+ (void)unsubscribeFromChannels:(NSArray*)channels;

+ (void)sendPushNotification:(BBPushNotification*)notification
                   toChannel:(NSString*)channel
                     success:(SuccessBlock)success
                     failure:(FailureBlock)failure;

+ (void)sendPushNotification:(BBPushNotification*)notification
                   toChannel:(NSString*)channel;

+ (BBObject*)currentUser;

+ (void)logout;

+ (void)persistDeviceToken:(NSData*)data;

+ (void)loginWithEmail:(NSString*)email
              password:(NSString*)password
               success:(SuccessObjectBlock)success
               failure:(FailureBlock)failure;

+ (void)loginWithEmail:(NSString*)email
              password:(NSString*)password
                  join:(NSString*)joins
                params:(NSArray*)params
               success:(SuccessObjectBlock)success
               failure:(FailureBlock)failure;

+ (void)requestPasswordResetWithEmail:(NSString*)email
                              success:(SuccessBlock)success
                              failure:(FailureBlock)failure;

+ (void)verifyCode:(NSString*)code
           success:(SuccessObjectBlock)success
           failure:(FailureBlock)failure;

+ (void)verifyCode:(NSString*)code
              join:(NSString*)joins
            params:(NSArray*)params
           success:(SuccessObjectBlock)success
           failure:(FailureBlock)failure;

+ (void)enableRealTime;

+ (void)disableRealTime;

+ (BOOL)subscribeToRealTimeEvents:(NSString*)event delegate:(id<BBRealTimeEventDelegate>)delegate;

+ (BOOL)unsubscribeFromRealTimeEvents:(NSString*)event delegate:(id<BBRealTimeEventDelegate>)delegate;

+ (void)subscribeToRealTimeConnectionEvents:(id<BBRealTimeConnectionDelegate>)delegate;

+ (void)unsubscribeFromRealTimeConnectionEvents:(id<BBRealTimeConnectionDelegate>)delegate;

+ (BOOL)sendRealTimeEvent:(NSString*)event message:(NSDictionary*)message;

+ (void)setWebVersion:(NSString*)webVersion;

+ (void)setHttpAuth:(NSString*)httpAuth;

+ (void)requestJSONFromController:(NSString*)path
                           method:(NSString*)method
                           params:(NSDictionary*)params
                      fetchPolicy:(BBFetchPolicy)fetchPolicy
                          success:(SuccessOperationBlock)success
                          failure:(FailureOperationBlock)failure;

+ (void)requestObjectsFromController:(NSString*)path
                              method:(NSString*)method
                              params:(NSDictionary*)params
                         fetchPolicy:(BBFetchPolicy)fetchPolicy
                             success:(SuccessNearQueryBlock)success
                             failure:(FailureQueryBlock)failure;

+ (void)requestJSONFromController:(NSString*)path
                           method:(NSString*)method
                           params:(NSDictionary*)params
                      fetchPolicy:(BBFetchPolicy)fetchPolicy
                         progress:(ProgressDataBlock)progress
                          success:(SuccessOperationBlock)success
                          failure:(FailureOperationBlock)failure;

+ (void)requestObjectsFromController:(NSString*)path
                              method:(NSString*)method
                              params:(NSDictionary*)params
                         fetchPolicy:(BBFetchPolicy)fetchPolicy
                            progress:(ProgressDataBlock)progress
                             success:(SuccessNearQueryBlock)success
                             failure:(FailureQueryBlock)failure;

+ (void)requestDataFromController:(NSString*)path
                           method:(NSString*)method
                           params:(NSDictionary*)params
                      fetchPolicy:(BBFetchPolicy)fetchPolicy
                   uploadProgress:(ProgressDataBlock)uploadProgress
                 downloadProgress:(ProgressDataBlock)downloadProgress
                          success:(SuccessDataBlock)success
                          failure:(FailureBlock)failure;

+ (NSString*)mimeTypeForFile:(NSString*)fileName;

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000

+ (void)twitterReverseOAuthWithAccount:(ACAccount*)account
                               success:(SuccessReverseOauthBlock)success
                               failure:(FailureReverseOauthBlock)failure;

#endif

@end
