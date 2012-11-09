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
        [Backbeam setProject:@"callezeta" sharedKey:@"" secretKey:@"" environment:@"dev"];
        done();
    }];
    
    [self test:@"User already registered" done:^(DoneBlock done) {
        assertNotOk([[BackbeamSession alloc] init]);
        done();
    }];
    
    [self test:@"Test empty query" done:^(DoneBlock done) {
        BBQuery* query = [Backbeam queryForEntity:@"place"];
        [query fetch:100 offset:0 success:^(NSArray* objects) {
            assertOk(objects.count == 0);
            done();
        } failure:^(NSError* error) {
            assertIfError(error);
        }];
    }];
    
    [self test:@"Insert, update, refresh an object" done:^(DoneBlock done) {
        BBObject* object = [Backbeam emptyObjectForEntity:@"place"];
        [object setObject:@"A new place" forKey:@"name"];
        [object save:^(BBObject* object) {
            assertOk(object.identifier);
            assertOk(object.createdAt);
            assertOk(object.updatedAt);
            assertEqual(object.createdAt, object.updatedAt);
            
            [object setObject:@"New name" forKey:@"name"];
            [object setObject:@"Terraza" forKey:@"type"];
            [object save:^(BBObject* obj) {
                assertOk(obj.identifier);
                assertOk(obj.createdAt);
                assertOk(obj.updatedAt);
                assertNotEqual(obj.createdAt, obj.updatedAt);
                assertEqual([obj stringForKey:@"name"], @"New name");
                
                BBObject* object = [Backbeam emptyObjectForEntity:@"place" withIdentifier:obj.identifier];
                [object refresh:^(BBObject* lastObject) {
                    assertEqual([obj stringForKey:@"name"], [lastObject stringForKey:@"name"]);
                    assertEqual([obj stringForKey:@"type"], [lastObject stringForKey:@"type"]);
                    assertEqual(obj.createdAt, lastObject.createdAt);
                    
                    [lastObject setObject:@"Final name" forKey:@"name"];
                    [lastObject save:^(BBObject* lastObject) {
                        // partial update
                        [obj setObject:@"Some description" forKey:@"description"];
                        [obj save:^(BBObject* obj) {
                            assertEqual([obj stringForKey:@"type"], [lastObject stringForKey:@"type"]);
                            assertEqual([obj stringForKey:@"name"], [lastObject stringForKey:@"name"]);
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
        [query fetch:100 offset:0 success:^(NSArray* objects) {
            assertOk(objects.count == 1);
            BBObject* object = [objects objectAtIndex:0];
            assertEqual([object stringForKey:@"name"], @"Final name");
            assertEqual([object stringForKey:@"description"], @"Some description");
            done();
        } failure:^(NSError* error) {
            assertIfError(error);
        }];
    }];

#if TARGET_IPHONE_SIMULATOR
    
    [self test:@"Push notifications should not work if deviceToken is not set" done:^(DoneBlock done) {
        NSArray* arr = [NSArray arrayWithObjects:@"foo", @"bar", nil];
        assertNotOk([Backbeam subscribeToChannels:arr]);
        assertNotOk([Backbeam unsubscribeFromChannels:arr]);
        done();
    }];

#else
    
    [self test:@"Push notifications" done:^(DoneBlock done) {
        [Backbeam subscribeToChannels:[NSArray arrayWithObjects:@"foo", @"bar", nil] success:^{
            [Backbeam unsubscribeFromChannels:[NSArray arrayWithObjects:@"foo", nil] success:^{
                BBPushNotification* notification = [[BBPushNotification alloc] init];
                notification.text = @"Hello world!";
                notification.sound = @"default";
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
    
    [self test:@"Register, login" done:^(DoneBlock done) {
        BBObject* object = [Backbeam emptyObjectForEntity:@"user"];
        [object setObject:@"gimenete@gmail.com" forKey:@"email"];
        [object setObject:@"123456" forKey:@"password"];
        // TODO: set a name
        [object save:^(BBObject* object) {
            assertOk([Backbeam loggedUser]);
            assertEqual([Backbeam loggedUser].identifier, object.identifier);
            assertEqual([[Backbeam loggedUser] stringForKey:@"email"], [object stringForKey:@"email"]);
            assertNotOk([[Backbeam loggedUser] stringForKey:@"password"]);
            assertNotOk([object stringForKey:@"password"]);
            
            [Backbeam logout];
            assertNotOk([Backbeam loggedUser]);
            [Backbeam loginWithEmail:@"gimenete@gmail.com" password:@"123456" success:^(BBObject* object) {
                assertOk([Backbeam loggedUser]);
                assertEqual([Backbeam loggedUser].identifier, object.identifier);
                assertEqual([[Backbeam loggedUser] stringForKey:@"email"], [object stringForKey:@"email"]);
                assertNotOk([[Backbeam loggedUser] stringForKey:@"password"]);
                assertNotOk([object stringForKey:@"password"]);
                
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
        [object setObject:@"gimenete@gmail.com" forKey:@"email"];
        [object setObject:@"123456" forKey:@"password"];
        [object save:^(BBObject* object) {
            assertError(@"Registration should have failed");
        } failure:^(BBObject* object, NSError* error) {
            assertOk([error isMemberOfClass:[BBError class]]);
            done();
        }];
    }];
    
    [self test:@"Unsuccessfull login. User not found" done:^(DoneBlock done) {
        [Backbeam loginWithEmail:@"foo@example.com" password:@"xxxx" success:^(BBObject* user) {
            assertError(@"Login should have failed");
        } failure:^(NSError* error) {
            assertOk([error isMemberOfClass:[BBError class]]);
            done();
        }];
    }];
    
    [self test:@"Unsuccessfull login. Wrong password" done:^(DoneBlock done) {
        [Backbeam loginWithEmail:@"gimenete@gmail.com" password:@"xxxx" success:^(BBObject* user) {
            assertError(@"Login should have failed");
        } failure:^(NSError* error) {
            assertOk([error isMemberOfClass:[BBError class]]);
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
