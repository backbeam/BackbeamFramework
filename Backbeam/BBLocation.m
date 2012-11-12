//
//  BBLocation.m
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 12/11/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "BBLocation.h"

@implementation BBLocation

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    self.latitude  = [decoder decodeDoubleForKey:@"lat"];
    self.longitude = [decoder decodeDoubleForKey:@"lon"];
    self.altitude  = [decoder decodeDoubleForKey:@"alt"];
    self.address   = [decoder decodeObjectForKey:@"addr"];
    return self;
}

- (id)initWithLatitude:(double)lat longitude:(double)lon altitude:(double)alt address:(NSString*)addr
{
    self = [super init];
    if (self) {
        self.latitude  = lat;
        self.longitude = lon;
        self.altitude  = alt;
        self.address   = addr;
    }
    return self;
}

- (id)initWithLatitude:(double)lat longitude:(double)lon altitude:(double)alt
{
    self = [super init];
    if (self) {
        self.latitude  = lat;
        self.longitude = lon;
        self.altitude  = alt;
    }
    return self;
}

- (id)initWithLatitude:(double)lat longitude:(double)lon
{
    self = [super init];
    if (self) {
        self.latitude  = lat;
        self.longitude = lon;
    }
    return self;
}

- (id)initWithAddress:(NSString*)addr
{
    self = [super init];
    if (self) {
        self.address = addr;
    }
    return self;
}

- (id)initWithLatitude:(double)lat longitude:(double)lon address:(NSString*)addr
{
    self = [super init];
    if (self) {
        self.latitude  = lat;
        self.longitude = lon;
        self.address   = addr;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeDouble:self.latitude  forKey:@"lat"];
    [coder encodeDouble:self.longitude forKey:@"lon"];
    [coder encodeDouble:self.altitude  forKey:@"alt"];
    [coder encodeObject:self.address   forKey:@"addr"];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"lat=%f, lon=%f, alt=%f, addr=%@",
            self.latitude, self.longitude, self.altitude, self.address];
}

@end
