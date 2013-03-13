//
//  BBTest.h
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 08/11/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "BBObject.h"
#define assertError(message) [self failed:message file:__FILE__ line:__LINE__]; return;
#define assertIfError(error) if(error != nil) { [self failed:[error localizedDescription] file:__FILE__ line:__LINE__]; return; }
#define assertOk(condition) if(!condition) { [self failed:@"assertOk" file:__FILE__ line:__LINE__]; return; }
#define assertNotOk(condition) if(condition) { [self failed:@"assertNotOk" file:__FILE__ line:__LINE__]; return; }
#define assertEqual(a, b) if(a != b && ![a isEqual:b]) { [self failed:[NSString stringWithFormat:@"%@ != %@", a, b] file:__FILE__ line:__LINE__]; return; }
#define assertNotEqual(a, b) if(a == b || [a isEqual:b]) { [self failed:[NSString stringWithFormat:@"%@ != %@", a, b] file:__FILE__ line:__LINE__]; return; }
#define assertStringEqual(a, b) if(![a isEqualToString:b]) { [self failed:[NSString stringWithFormat:@"%@ != %@", a, b] file:__FILE__ line:__LINE__]; return; }

@class BBTest;
typedef void(^DoneBlock)();
typedef void(^TestBlock)(DoneBlock done);

@interface BBTest : BBObject

- (void)before:(TestBlock)done;
- (void)after:(TestBlock)done;

- (void)beforeEach:(TestBlock)done;
- (void)afterEach:(TestBlock)done;

- (void)test:(NSString*)message done:(TestBlock)done;
- (void)run:(DoneBlock)done;

- (void)failed:(NSString*)message file:(char*)filename line:(int)line;

- (void)configure;

@end
