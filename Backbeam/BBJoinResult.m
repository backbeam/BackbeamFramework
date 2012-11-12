//
//  BBJoinResult.m
//  Callezeta
//
//  Created by Alberto Gimeno Brieba on 12/11/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "BBJoinResult.h"

@implementation BBJoinResult

- (NSString *)description {
    return [NSString stringWithFormat:@"count=%d, results=%@",
            self.count,
            self.objects];
}

@end
