BackbeamFramework
=================

iOS SDK for [backbeam.io](http://backbeam.io). At this moment this iOS libary depends on [AFNetworking](https://github.com/AFNetworking/AFNetworking).

For Facebook integration the Facebook SDK 3.x is needed.

Configure your application
--------------------------

    #import "Backbeam.h"
    
    ...
    
    - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
    {
        [Backbeam setProject:@"your_project" sharedKey:@"" secretKey:@""];
        [Backbeam setTwitterConsumerKey:@"…" consumerSecret:@"…"]; // optional
    }
    
Make queries
------------

    BBQuery* query = [BBQuery queryForEntity:@"event"];
    [query fetch:100 offset:0 success:^(NSArray* objects, NSDictionary* references) {
        // do something
    } failure:^(NSError* error) {
        // something bad happened
    }];


BBObjects
---------

The returned objects of a query have the following methods:

    - (NSString*)identifier;
    - (NSString*)entity;
    - (NSDate*)createdAt;
    - (NSDate*)updatedAt;

    - (NSString*)stringForKey:(NSString*)key;
    - (NSDate*)dateForKey:(NSString*)key;
    - (NSNumber*)numberForKey:(NSString*)key;
    - (BBObject*)referenceForKey:(NSString*)key;
    - (id)objectForKey:(NSString*)key;

