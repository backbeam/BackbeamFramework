//
//  BackbeamTest.m
//  Callezeta
//
//  Created by Alberto Gimeno Brieba on 08/11/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "BackbeamTest.h"
#import "BBTest.h"
#import "Backbeam.h"

@implementation BackbeamTest

- (void)doSomething {
    BBTest* test = [[BBTest alloc] init];
    
    [Backbeam setProject:@"callezeta" sharedKey:@"" secretKey:@"" environment:@"dev"];
    
    [test test:@"test" done:^(BBTest* test, DoneBlock done) {
        done();
    }];
    
    [test test:@"Test empty query" done:^(BBTest* test, DoneBlock done) {
        BBQuery* query = [BBQuery queryForEntity:@"place"];
        [query fetch:100 offset:0 success:^(NSArray* objects) {
            assertOk(test, objects.count == 0);
            done();
        } failure:^(NSError* error) {
            assertIfError(test, error);
        }];
    }];
    
    [test test:@"Insert, update, refresh an object" done:^(BBTest* test, DoneBlock done) {
        BBObject* object = [[BBObject alloc] initWithEntity:@"place"];
        [object setObject:@"A new place" forKey:@"name"];
        [object save:^(BBObject* object) {
            assertOk(test, object.identifier);
            assertOk(test, object.createdAt);
            assertOk(test, object.updatedAt);
            assertEqual(test, object.createdAt, object.updatedAt);
            
            [object setObject:@"New name" forKey:@"name"];
            [object setObject:@"Terraza" forKey:@"type"];
            [object save:^(BBObject* obj) {
                assertOk(test, obj.identifier);
                assertOk(test, obj.createdAt);
                assertOk(test, obj.updatedAt);
                assertNotEqual(test, obj.createdAt, obj.updatedAt);
                assertEqual(test, [obj stringForKey:@"name"], @"New name");
                
                BBObject* object = [[BBObject alloc] initWithEntity:@"place" andIdentifier:obj.identifier];
                [object refresh:^(BBObject* lastObject) {
                    assertEqual(test, [obj stringForKey:@"name"], [lastObject stringForKey:@"name"]);
                    assertEqual(test, [obj stringForKey:@"type"], [lastObject stringForKey:@"type"]);
                    assertEqual(test, obj.createdAt, lastObject.createdAt);
                    
                    [lastObject setObject:@"Final name" forKey:@"name"];
                    [lastObject save:^(BBObject* lastObject) {
                        // partial update
                        [obj setObject:@"Some description" forKey:@"description"];
                        [obj save:^(BBObject* obj) {
                            assertEqual(test, [obj stringForKey:@"type"], [lastObject stringForKey:@"type"]);
                            assertEqual(test, [obj stringForKey:@"name"], [lastObject stringForKey:@"name"]);
                            done();
                        } failure:^(BBObject* obj, NSError* error) {
                            assertIfError(test, error);
                        }];
                    } failure:^(BBObject* lastObject, NSError* error) {
                        assertIfError(test, error);
                    }];
                } failure:^(BBObject* lastObject, NSError* error) {
                    assertIfError(test, error);
                }];
            } failure:^(BBObject* object, NSError* error) {
                assertIfError(test, error);
            }];
        } failure:^(BBObject* object, NSError* error) {
            assertIfError(test, error);
        }];
    }];
    
    [test test:@"Query with BQL and params" done:^(BBTest* test, DoneBlock done) {
        BBQuery* query = [BBQuery queryForEntity:@"place"];
        [query setQuery:@"where type=?" withParams:[NSArray arrayWithObject:@"Terraza"]];
        [query fetch:100 offset:0 success:^(NSArray* objects) {
            assertOk(test, objects.count == 1);
            BBObject* object = [objects objectAtIndex:0];
            assertEqual(test, [object stringForKey:@"name"], @"Final name");
            assertEqual(test, [object stringForKey:@"description"], @"Some description");
            done();
        } failure:^(NSError* error) {
            assertIfError(test, error);
        }];
    }];

    [test run:^{
        NSLog(@"✔ Tests passed!");
    }];
}

@end
