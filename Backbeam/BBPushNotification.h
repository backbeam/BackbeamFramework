//
//  BBPushNotification.h
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 22/10/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BBPushNotification : NSObject

@property (nonatomic, strong) NSString* text;
@property (nonatomic, strong) NSString* sound;
@property (nonatomic, strong) NSNumber* badge;
@property (nonatomic, strong) id extra;

@end
