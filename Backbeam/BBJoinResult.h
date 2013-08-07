//
//  BBJoinResult.h
//  Callezeta
//
//  Created by Alberto Gimeno Brieba on 12/11/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BBJoinResult : NSObject <NSCoding>

@property (nonatomic, assign) NSInteger count;
@property (nonatomic, strong) NSArray* objects;

@end
