//
//  BBLocation.h
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 12/11/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BBLocation : NSObject <NSCoding>

@property (nonatomic, assign) double latitude;
@property (nonatomic, assign) double longitude;
@property (nonatomic, assign) double altitude;
@property (nonatomic, strong) NSString* address;

- (id)initWithLatitude:(double)lat
             longitude:(double)lon
              altitude:(double)alt
               address:(NSString*)addr;

- (id)initWithLatitude:(double)lat
             longitude:(double)lon
              altitude:(double)alt;

- (id)initWithLatitude:(double)lat
             longitude:(double)lon
               address:(NSString*)addr;

- (id)initWithLatitude:(double)lat
             longitude:(double)lon;

- (id)initWithAddress:(NSString*)addr;

@end
