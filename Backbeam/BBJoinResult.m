//
//  BBJoinResult.m
//  Callezeta
//
//  Created by Alberto Gimeno Brieba on 12/11/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "BBJoinResult.h"

@implementation BBJoinResult

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        _count = [aDecoder decodeIntegerForKey:@"count"];
        _objects = [aDecoder decodeObjectForKey:@"objects"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInteger:self.count forKey:@"count"];
    [aCoder encodeObject:self.objects forKey:@"objects"];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"count=%d, results=%@",
            self.count,
            self.objects];
}

@end
