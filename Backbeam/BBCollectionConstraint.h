//
//  BBCollectionConstraint.h
//  Communities
//
//  Created by Alberto Gimeno Brieba on 02/08/13.
//  Copyright (c) 2013 Level Apps S.L. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BBObject.h"

@interface BBCollectionConstraint : NSObject

- (void)addObject:(BBObject*)object;

- (void)addObjects:(NSArray*)objects;

- (void)addIdentifier:(NSString*)identifier;

- (void)addIdentifiers:(NSArray*)identifiers;

- (void)addTwitterIdentifier:(NSString*)identifier;

- (void)addTwitterIdentifiers:(NSArray*)identifiers;

- (void)addFacebookIdentifier:(NSString*)identifier;

- (void)addFacebookIdentifiers:(NSArray*)identifiers;

- (void)addEmailAddress:(NSString*)address;

- (void)addEmailAddresses:(NSArray*)addresses;

@end
