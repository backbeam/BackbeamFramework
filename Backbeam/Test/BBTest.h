//
//  BBTest.h
//  Callezeta
//
//  Created by Alberto Gimeno Brieba on 08/11/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "BBObject.h"
#define assertIfError(test, error) if(error != nil) { [test failed:[error localizedDescription] file:__FILE__ line:__LINE__]; return; }
#define assertOk(test, condition) if(!condition) { [test failed:@"assertOk" file:__FILE__ line:__LINE__]; return; }
#define assertEqual(test, a, b) if(a != b && ![a isEqual:b]) { [test failed:[NSString stringWithFormat:@"%@ != %@", a, b] file:__FILE__ line:__LINE__]; return; }
#define assertNotEqual(test, a, b) if(a == b || [a isEqual:b]) { [test failed:[NSString stringWithFormat:@"%@ != %@", a, b] file:__FILE__ line:__LINE__]; return; }

@class BBTest;
typedef void(^DoneBlock)();
typedef void(^TestBlock)(BBTest* test, DoneBlock done);

@interface BBTest : BBObject

- (void)before:(TestBlock)done;
- (void)after:(TestBlock)done;

- (void)beforeEach:(TestBlock)done;
- (void)afterEach:(TestBlock)done;

- (void)test:(NSString*)message done:(TestBlock)done;
- (void)run:(DoneBlock)done;

- (void)failed:(NSString*)message file:(char*)filename line:(int)line;

@end
