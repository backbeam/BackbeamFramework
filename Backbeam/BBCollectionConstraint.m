//
//  BBCollectionConstraint.m
//  Communities
//
//  Created by Alberto Gimeno Brieba on 02/08/13.
//  Copyright (c) 2013 Level Apps S.L. All rights reserved.
//

#import "BBCollectionConstraint.h"

@interface BBCollectionConstraint ()

@property (nonatomic, strong) NSMutableArray *ids;

@end

@implementation BBCollectionConstraint

- (id)init
{
    self = [super init];
    if (self) {
        self.ids = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)addObject:(BBObject*)object {
    if (object.identifier) {
        [self.ids addObject:object.identifier];
    }
}

- (void)addObjects:(NSArray*)objects {
    for (BBObject *obj in objects) {
        [self addObject:obj];
    }
}

- (void)addIdentifier:(NSString*)identifier {
    [self.ids addObject:identifier];
}

- (void)addIdentifiers:(NSArray*)identifiers {
    for (NSString *identifier in identifiers) {
        [self.ids addObject:identifier];
    }
}

- (void)addIdentifier:(NSString*)identifier withPrefix:(NSString*)prefix {
    [self.ids addObject:[prefix stringByAppendingString:identifier]];
}

- (void)addIdentifiers:(NSArray*)identifiers withPrefix:(NSString*)prefix {
    for (NSString *identifier in identifiers) {
        [self.ids addObject:[prefix stringByAppendingString:identifier]];
    }
}

- (void)addTwitterIdentifier:(NSString*)identifier {
    [self addIdentifier:identifier withPrefix:@"tw:"];
}

- (void)addTwitterIdentifiers:(NSArray*)identifiers {
    [self addIdentifiers:identifiers withPrefix:@"tw:"];
}

- (void)addFacebookIdentifier:(NSString*)identifier {
    [self addIdentifier:identifier withPrefix:@"fb:"];
}

- (void)addFacebookIdentifiers:(NSArray*)identifiers {
    [self addIdentifiers:identifiers withPrefix:@"fb:"];
}

- (void)addEmailAddress:(NSString*)address {
    [self addIdentifier:address withPrefix:@"email:"];
}

- (void)addEmailAddresses:(NSArray*)addresses {
    [self addIdentifiers:addresses withPrefix:@"email:"];
}

- (NSString *)description {
    return [self.ids componentsJoinedByString:@"\n"];
}

@end
