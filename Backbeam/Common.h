//
//  Common.h
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 22/10/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

@class BBObject;
@class BBUser;
@class BBError;

typedef enum {
    BBFetchPolicyRemoteOnly,
    BBFetchPolicyLocalOnly,
    BBFetchPolicyLocalAndRemote,
    BBFetchPolicyLocalOrRemote
} BBFetchPolicy;

typedef enum {
    BBTwitterProgressLoadingAuthorizationPage,
    BBTwitterProgressLoadedAuthorizationPage,
    BBTwitterProgressAuthorizating,
    BBTwitterProgressRedirecting
} BBTwitterProgress;

// internal use
typedef void(^SuccessOperationBlock)(id result, BOOL fromCache);
typedef void(^FailureOperationBlock)(id result, NSError *err);
typedef void(^SuccessOperationObjectBlock)(NSString *status, BBObject *object, NSString *authCode);
typedef void(^SuccessDataBlock)(NSData *data);
typedef void(^ProgressDataBlock)(NSInteger lastBytesSentCount, long long sentBytes, long long totalBytes);
typedef void(^SuccessControllerBlock)(NSData *result, BOOL fromCache, NSHTTPURLResponse *response);
typedef void(^FailureControllerBlock)(NSData *result, NSError* err);

// public use
typedef void(^SuccessBlock)();
typedef void(^FailureBlock)(NSError *err);


#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
typedef void(^SuccessImageBlock)(UIImage *img);
#endif

typedef void(^SuccessArrayBlock)(NSArray *array);

typedef void(^SuccessQueryBlock)(NSArray* objects, NSInteger totalCount, BOOL fromCache);
typedef void(^FailureQueryBlock)(NSError* err);
typedef void(^SuccessNearQueryBlock)(NSArray *objects, NSInteger totalCount, NSArray *distances, BOOL fromCache);

typedef void(^SuccessRemoveBlock)(NSInteger removed);
typedef void(^FailureRemoveBlock)(NSError* err);

typedef void(^SuccessObjectBlock)(BBObject* object);
typedef void(^FailureObjectBlock)(BBObject* object, NSError* err);

typedef void(^SuccessUserBlock)(BBUser* user);
typedef void(^FailureUserBlock)(BBUser* user, NSError* err);

typedef void(^ProgressDataObjectBlock)(BBObject* object, NSInteger lastBytesSentCount, long long sentBytes, long long totalBytes);
typedef void(^SuccessDownloadBlock)(BBObject* object, NSData*);

typedef void(^SuccessReverseOauthBlock)(NSDictionary *params);
typedef void(^FailureReverseOauthBlock)(NSError *err);

typedef void(^SuccessSocialSignupBlock)(BBObject* user, BOOL isNew);
typedef void(^FailureSocialSignupBlock)(NSError* err);

typedef void(^SuccessFacebookBlock)(BBObject* user, BOOL isNew);
typedef void(^FailureFacebookBlock)(NSError* err);

typedef void(^SuccessTwitterBlock)(BBObject* user, NSDictionary* extraInfo, BOOL isNew);
typedef void(^FailureTwitterBlock)(NSError* err);
typedef void(^ProgressTwitterBlock)(BBTwitterProgress progress);

