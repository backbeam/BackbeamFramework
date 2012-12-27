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

#define kFetchPolicyLocalOnly      1
#define kFetchPolicyRemoteOnly     2
#define kFetchPolicyLocalAndRemote 3
#define kFetchPolicyLocalOrRemote  4

// internal use
typedef void(^SuccessOperationBlock)(id result);
typedef void(^FailureOperationBlock)(id result, NSError* err);
typedef void(^SuccessOperationObjectBlock)(NSString* status, BBObject* object);
typedef void(^SuccessDataBlock)(NSData* data);
typedef void(^ProgressDataBlock)(NSInteger lastBytesSentCount, long long sentBytes, long long totalBytes);

// public use
typedef void(^SuccessBlock)();
typedef void(^FailureBlock)(NSError* err);

typedef void(^SuccessImageBlock)(UIImage* img);

typedef void(^SuccessQueryBlock)(NSArray* objects);
typedef void(^FailureQueryBlock)(NSError* err);

typedef void(^SuccessObjectBlock)(BBObject* object);
typedef void(^FailureObjectBlock)(BBObject* object, NSError* err);

typedef void(^SuccessUserBlock)(BBUser* user);
typedef void(^FailureUserBlock)(BBUser* user, NSError* err);

typedef void(^ProgressDataObjectBlock)(BBObject* object, NSInteger lastBytesSentCount, long long sentBytes, long long totalBytes);
typedef void(^SuccessDownloadBlock)(BBObject* object, NSData*);
