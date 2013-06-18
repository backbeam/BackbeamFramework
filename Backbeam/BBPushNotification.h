//
//  BBPushNotification.h
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 22/10/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BBPushNotification : NSObject

@property (nonatomic, strong) NSString *iosAlert;
@property (nonatomic, strong) NSString *iosSound;
@property (nonatomic, strong) NSNumber *iosBadge;
@property (nonatomic, strong) NSDictionary *iosPayload;

@property (nonatomic, strong) NSString *androidCollapseKey;
@property (nonatomic, strong) NSNumber *androidDelayWhileIdle;
@property (nonatomic, strong) NSNumber *androidTimeToLive;
@property (nonatomic, strong) NSDictionary *androidData;

@end
