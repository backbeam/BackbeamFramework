//
//  BackbeamTest.m
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 08/11/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "BackbeamTest.h"
#import "BBTest.h"
#import "Backbeam.h"

@implementation BackbeamTest

- (void)configure {
    
    [self before:^(DoneBlock done) {
        [Backbeam setHost:@"backbeamapps.dev" port:8079];
        [Backbeam setProject:@"callezeta" sharedKey:@"5bd82df918d542f181f9308008f229c335812ba4" secretKey:@"c7b7726df5a0e96304cd6e1d44e86036038191826b52bc11dff6e2a626ea1c46b0344dcc069a14dd" environment:@"dev"];
        [Backbeam logout];
        done();
    }];
    
    [self test:@"Cannot create BackbeamSession directly" done:^(DoneBlock done) {
        assertNotOk([[BackbeamSession alloc] init]);
        done();
    }];
    
    [self test:@"Test empty query" done:^(DoneBlock done) {
        BBQuery* query = [Backbeam queryForEntity:@"place"];
        [query fetch:100 offset:0 success:^(NSArray* objects, NSInteger totalCount, BOOL fromCache) {
            assertOk(objects.count == 0);
            done();
        } failure:^(NSError* error) {
            assertIfError(error);
        }];
    }];
    
    [self test:@"Insert, update, refresh an object" done:^(DoneBlock done) {
        BBLocation* location = [[BBLocation alloc] initWithLatitude:41.640964
                                                          longitude:-0.8952422
                                                            address:@"San Francisco Square, Zaragoza City"];
        
        BBObject* object = [Backbeam emptyObjectForEntity:@"place"];
        [object setString:@"A new place" forField:@"name"];
        [object setLocation:location forField:@"location"];
        [object save:^(BBObject* object) {
            assertOk(object.identifier);
            assertOk(object.createdAt);
            assertOk(object.updatedAt);
            assertEqual(object.createdAt, object.updatedAt);
            
            [object setString:@"New name" forField:@"name"];
            [object setString:@"Terraza" forField:@"type"];
            [object save:^(BBObject* obj) {
                assertOk(obj.identifier);
                assertOk(obj.createdAt);
                assertOk(obj.updatedAt);
                assertNotEqual(obj.createdAt, obj.updatedAt);
                assertStringEqual([obj stringForField:@"name"], @"New name");
                
                BBObject* object = [Backbeam emptyObjectForEntity:@"place" withIdentifier:obj.identifier];
                [object refresh:^(BBObject* lastObject) {
                    assertEqual([obj stringForField:@"name"], [lastObject stringForField:@"name"]);
                    assertEqual([obj stringForField:@"type"], [lastObject stringForField:@"type"]);
                    BBLocation* location = [lastObject locationForField:@"location"];
                    assertOk(location);
                    assertStringEqual(location.address, @"San Francisco Square, Zaragoza City");
                    assertOk(location.latitude  == 41.640964);
                    assertOk(location.longitude == -0.8952422);
                    assertEqual(obj.createdAt, lastObject.createdAt);
                    
                    [lastObject setString:@"Final name" forField:@"name"];
                    [lastObject save:^(BBObject* lastObject) {
                        // partial update
                        [obj setString:@"Some description" forField:@"description"];
                        [obj save:^(BBObject* obj) {
                            assertEqual([obj stringForField:@"type"], [lastObject stringForField:@"type"]);
                            assertEqual([obj stringForField:@"name"], [lastObject stringForField:@"name"]);
                            done();
                        } failure:^(BBObject* obj, NSError* error) {
                            assertIfError(error);
                        }];
                    } failure:^(BBObject* lastObject, NSError* error) {
                        assertIfError(error);
                    }];
                } failure:^(BBObject* lastObject, NSError* error) {
                    assertIfError(error);
                }];
            } failure:^(BBObject* object, NSError* error) {
                assertIfError(error);
            }];
        } failure:^(BBObject* object, NSError* error) {
            assertIfError(error);
        }];
    }];
    
    [self test:@"Query with BQL and params" done:^(DoneBlock done) {
        BBQuery* query = [Backbeam queryForEntity:@"place"];
        [query setQuery:@"where type=?" withParams:[NSArray arrayWithObject:@"Terraza"]];
        [query fetch:100 offset:0 success:^(NSArray* objects, NSInteger totalCount, BOOL fromCache) {
            assertOk(objects.count == 1);
            BBObject* object = [objects objectAtIndex:0];
            assertStringEqual([object stringForField:@"name"], @"Final name");
            assertStringEqual([object stringForField:@"description"], @"Some description");
            done();
        } failure:^(NSError* error) {
            assertIfError(error);
        }];
    }];

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)

#if TARGET_IPHONE_SIMULATOR
    
//    [self test:@"Push notifications should not work if deviceToken is not set" done:^(DoneBlock done) {
//        NSArray* arr = [NSArray arrayWithObjects:@"foo", @"bar", nil];
//        assertNotOk([Backbeam subscribeToChannels:arr]);
//        assertNotOk([Backbeam unsubscribeFromChannels:arr]);
//        done();
//    }];

#else
    
    [self test:@"Push notifications" done:^(DoneBlock done) {
        [Backbeam subscribeToChannels:[NSArray arrayWithObjects:@"foo", @"bar", nil] success:^{
            [Backbeam unsubscribeFromChannels:[NSArray arrayWithObjects:@"foo", nil] success:^{
                BBPushNotification* notification = [[BBPushNotification alloc] init];
                notification.iosAlert = @"Hello world!";
                notification.iosSound = @"default";
                [Backbeam sendPushNotification:notification toChannel:@"bar" success:^{
                    done();
                } failure:^(NSError* error) {
                    assertIfError(error);
                }];
            } failure:^(NSError* error) {
                assertIfError(error);
            }];
        } failure:^(NSError* error) {
            assertIfError(error);
        }];
    }];
    
#endif
#endif
    
    [self test:@"Register, login" done:^(DoneBlock done) {
        BBObject* object = [Backbeam emptyObjectForEntity:@"user"];
        [object setString:@"gimenete@gmail.com" forField:@"email"];
        [object setString:@"123456" forField:@"password"];
        // TODO: set a name
        [object save:^(BBObject* object) {
            assertOk([Backbeam currentUser]);
            assertEqual([Backbeam currentUser].identifier, object.identifier);
            assertEqual([[Backbeam currentUser] stringForField:@"email"], [object stringForField:@"email"]);
            assertNotOk([[Backbeam currentUser] stringForField:@"password"]);
            assertNotOk([object stringForField:@"password"]);
            
            [Backbeam logout];
            assertNotOk([Backbeam currentUser]);
            [Backbeam loginWithEmail:@"gimenete@gmail.com" password:@"123456" success:^(BBObject* object) {
                assertOk([Backbeam currentUser]);
                assertEqual([Backbeam currentUser].identifier, object.identifier);
                assertEqual([[Backbeam currentUser] stringForField:@"email"], [object stringForField:@"email"]);
                assertNotOk([[Backbeam currentUser] stringForField:@"password"]);
                assertNotOk([object stringForField:@"password"]);
                
                done();
            } failure:^(NSError* error) {
                assertIfError(error);
            }];
        } failure:^(BBObject* object, NSError* error) {
            assertIfError(error);
        }];
    }];

    [self test:@"User already registered" done:^(DoneBlock done) {
        BBObject* object = [Backbeam emptyObjectForEntity:@"user"];
        [object setString:@"gimenete@gmail.com" forField:@"email"];
        [object setString:@"123456" forField:@"password"];
        [object save:^(BBObject* object) {
            assertError(@"Registration should have failed");
        } failure:^(BBObject* object, NSError* error) {
            assertOk([error isMemberOfClass:[BBError class]]);
            // TODO: check error message
            done();
        }];
    }];
    
    [self test:@"Unsuccessfull login. User not found" done:^(DoneBlock done) {
        [Backbeam loginWithEmail:@"foo@example.com" password:@"xxxx" success:^(BBObject* user) {
            assertError(@"Login should have failed");
        } failure:^(NSError* error) {
            assertOk([error isMemberOfClass:[BBError class]]);
            // TODO: check error message
            done();
        }];
    }];
    
    [self test:@"Unsuccessfull login. Wrong password" done:^(DoneBlock done) {
        [Backbeam loginWithEmail:@"gimenete@gmail.com" password:@"xxxx" success:^(BBObject* user) {
            assertError(@"Login should have failed");
        } failure:^(NSError* error) {
            assertOk([error isMemberOfClass:[BBError class]]);
            // TODO: check error message
            done();
        }];
    }];
    
    [self test:@"Request password reset" done:^(DoneBlock done) {
        [Backbeam requestPasswordResetWithEmail:@"gimenete@gmail.com" success:^ {
            done();
        } failure:^(NSError* error) {
            assertIfError(error);
        }];
    }];

}

@end
