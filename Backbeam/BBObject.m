//
//  BBObject.m
//  Backbeam
//
//  Created by Alberto Gimeno Brieba on 16/08/12.
//  Copyright (c) 2012 Level Apps S.L. All rights reserved.
//

#import "BBObject.h"
#import "BBError.h"
#import "BBUtils.h"

@interface BBObject ()

@property (nonatomic, strong) NSString* _identifier;
@property (nonatomic, strong) NSString* _entity;
@property (nonatomic, strong) NSMutableDictionary* _fields;
@property (nonatomic, strong) NSMutableDictionary* _commands;
@property (nonatomic, strong) NSMutableDictionary* _loginData;
@property (nonatomic, strong) NSDate* _createdAt;
@property (nonatomic, strong) NSDate* _updatedAt;
@property (nonatomic, strong) BackbeamSession* _session;

@end

@implementation BBObject

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    if (self) {
        self._entity = [decoder decodeObjectForKey:@"entity"];
        self._identifier = [decoder decodeObjectForKey:@"id"];
        self._fields = [decoder decodeObjectForKey:@"fields"];
        self._loginData = [decoder decodeObjectForKey:@"login"];
        self._commands = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (id)initWith:(BackbeamSession*)session entity:(NSString*)entity
{
    self = [super init];
    if (self) {
        self._entity = entity;
        self._fields = [[NSMutableDictionary alloc] init];
        self._commands = [[NSMutableDictionary alloc] init];
        self._session = session;
    }
    return self;
}

- (id)initWith:(BackbeamSession*)session entity:(NSString*)entity identifier:(NSString*)identifier
{
    self = [super init];
    if (self) {
        self._entity = entity;
        self._identifier = identifier;
        self._fields = [[NSMutableDictionary alloc] init];
        self._commands = [[NSMutableDictionary alloc] init];
        self._session = session;
    }
    return self;
}

+ (NSMutableDictionary*)objectsWithSession:(BackbeamSession*)session
                                    values:(NSDictionary*)values
                                references:(NSMutableDictionary*)objects {
    
    if (!objects) {
        objects = [[NSMutableDictionary alloc] initWithCapacity:values.count];
    }
    for (NSString* identifier in values.allKeys) {
        BBObject* obj = [objects objectForKey:identifier];
        if (obj) continue;
        NSDictionary* object = [values dictionaryForKey:identifier];
        NSString* type = [object stringForKey:@"type"];
        obj = [[BBObject alloc] initWith:session entity:type identifier:identifier];
        [objects setObject:obj forKey:identifier];
    }
    
    for (NSString* identifier in values) {
        BBObject* obj = [objects objectForKey:identifier];
        NSDictionary* dict = [values dictionaryForKey:identifier];
        [obj fillWithValues:dict references:objects];
    }
    return objects;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self._entity forKey:@"entity"];
    [coder encodeObject:self._identifier forKey:@"id"];
    [coder encodeObject:self._fields forKey:@"fields"];
    if (self._loginData) {
        [coder encodeObject:self._loginData forKey:@"login"];
    }
}

- (void)setSession:(BackbeamSession*)session {
    self._session = session;
    for (NSString* key in self._fields) {
        id value = [self._fields objectForKey:key];
        if ([value isKindOfClass:[BBObject class]]) {
            BBObject* obj = (BBObject*)value;
            [obj setSession:session];
        }
        // TODO: JoinResults?
    }
}

- (void)fillWithValues:(NSDictionary*)dict references:(NSMutableDictionary*)references {
    [self._commands removeAllObjects];
    for (NSString* key in dict.allKeys) {
        NSObject* value = [dict objectForKey:key];
        if ([key isEqualToString:@"created_at"]) {
            self._createdAt = [BBObject dateFromValue:value];
        } else if ([key isEqualToString:@"updated_at"]) {
            self._updatedAt = [BBObject dateFromValue:value];
        } else if ([key isEqualToString:@"type"]) {
            self._entity = [value description];
        } else if ([key hasPrefix:@"login_"]) {
            NSString* _key = [key substringFromIndex:@"login_".length];
            if (!self._loginData) {
                self._loginData = [[NSMutableDictionary alloc] init];
            }
            [self._loginData setObject:value forKey:_key];
        } else {
            NSRange range = [key rangeOfString:@"#"];
            if (range.location != NSNotFound) {
                NSString* _key = [key substringToIndex:range.location];
                NSString* type = [key substringFromIndex:range.location+1];
                if ([type isEqualToString:@"d"] && [value isKindOfClass:[NSNumber class]]) {
                    NSNumber* n = (NSNumber*)value;
                    value = [NSDate dateWithTimeIntervalSince1970:n.doubleValue/1000];
                } else if ([type isEqualToString:@"r"] && [value isKindOfClass:[NSDictionary class]]) {
                    NSDictionary* dict = (NSDictionary*)value;
                    NSString* _id = [dict stringForKey:@"id"];
                    NSString* _type = [dict stringForKey:@"type"];
                    if (_id && _type) {
                        value = [references objectForKey:value];
                        if (!value) {
                            BBObject* obj = [Backbeam emptyObjectForEntity:_type withIdentifier:_id];
                            value = obj;
                        }
                    } else {
                        BBJoinResult* result = [[BBJoinResult alloc] init];
                        result.count = [dict numberForKey:@"count"].integerValue;
                        NSArray* arr = [dict arrayForKey:@"result"];
                        NSMutableArray* refs = [[NSMutableArray alloc] initWithCapacity:arr.count];
                        for (NSString* identifier in arr) {
                            NSDictionary* obj = [references objectForKey:identifier];
                            if (obj) { // sanity check
                                [refs addObject:obj];
                            }
                        }
                        result.objects = refs;
                        value = result;
                    }
                } else if ([type isEqualToString:@"r"] && [value isKindOfClass:[NSString class]]) {
                    value = [references objectForKey:value];
                } else if ([type isEqualToString:@"l"] && [value isKindOfClass:[NSDictionary class]]) {
                    NSDictionary* dict = (NSDictionary*)value;
                    BBLocation* location = [[BBLocation alloc] init];
                    location.latitude  = [dict numberForKey:@"lat"].doubleValue;
                    location.longitude = [dict numberForKey:@"lon"].doubleValue;
                    location.altitude  = [dict numberForKey:@"alt"].doubleValue;
                    location.address   = [dict stringForKey:@"addr"];
                    value = location;
                } else if ([type isEqualToString:@"j"]) {
                    // pass
                } else if ([type isEqualToString:@"c"] && [value isKindOfClass:[NSString class]]) {
                    NSString *str = (NSString*)value;
                    NSArray *components = [str componentsSeparatedByString:@"-"];
                    if (components.count == 3) {
                        NSString *year  = [components objectAtIndex:0];
                        NSString *month = [components objectAtIndex:1];
                        NSString *day   = [components objectAtIndex:2];
                        
                        NSDateComponents *d = [[NSDateComponents alloc] init];
                        [d setYear :  year.integerValue];
                        [d setMonth: month.integerValue];
                        [d setDay  :   day.integerValue];
                        value = d;
                    }
                } else if ([type isEqualToString:@"b"] && [value isKindOfClass:[NSNumber class]]) {
                    // pass
                }
                if (value) { // sanity check
                    [self._fields setObject:value forKey:_key];
                }
            }
        }
    }
}

+ (NSDate*)dateFromValue:(id)value {
    NSTimeInterval time = [(NSNumber*)value doubleValue]/1000;
    return [NSDate dateWithTimeIntervalSince1970:time];
}

- (NSArray*)fieldNames {
    return self._fields.allKeys;
}

- (NSString*)loginData:(NSString*)_key forProvider:(NSString*)provider {
    if (!self._loginData) {
        return nil;
    }
    NSString* key = [provider stringByAppendingFormat:@"_%@", _key];
    return [self._loginData stringForKey:key];
}

- (NSString*)facebookData:(NSString*)key {
    return [self loginData:key forProvider:@"fb"];
}

- (NSString*)twitterData:(NSString*)key {
    return [self loginData:key forProvider:@"tw"];
}

- (NSString*)googlePlusData:(NSString*)key {
    return [self loginData:key forProvider:@"gp"];
}

- (NSString*)identifier {
    return self._identifier;
}

- (NSString*)entity {
    return self._entity;
}

- (NSDate*)createdAt {
    return self._createdAt;
}

- (NSDate*)updatedAt {
    return self._updatedAt;
}

- (NSString*)stringForField:(NSString*)key {
    return [self._fields stringForKey:key];
}

- (NSDate*)dateForField:(NSString*)key {
    return [self._fields dateForKey:key];
}

- (NSNumber*)numberForField:(NSString*)key {
    return [self._fields numberForKey:key];
}

- (NSNumber*)booleanForField:(NSString*)key {
    return [self._fields numberForKey:key];
}

- (NSDateComponents*)dayForField:(NSString*)key {
    id obj = [self._fields objectForKey:key];
    if ([obj isKindOfClass:[NSDateComponents class]]) {
        return obj;
    }
    return nil;
}

- (id)JSONForField:(NSString*)key {
    return [self._fields objectForKey:key];
}

- (id)rawValueForField:(NSString*)key {
    return [self._fields objectForKey:key];
}

- (BBObject*)objectForField:(NSString*)key {
    id obj = [self._fields objectForKey:key];
    if ([obj isKindOfClass:[BBObject class]]) {
        return (BBObject*)obj;
    }
    return nil;
}

- (BBLocation*)locationForField:(NSString*)key {
    id obj = [self._fields objectForKey:key];
    if ([obj isKindOfClass:[BBLocation class]]) {
        return (BBLocation*)obj;
    }
    return nil;
}

- (BBJoinResult*)joinResultForField:(NSString*)key {
    id obj = [self._fields objectForKey:key];
    if ([obj isKindOfClass:[BBJoinResult class]]) {
        return (BBJoinResult*)obj;
    }
    return nil;
}

- (BOOL)setString:(NSString*)obj forField:(NSString*)key {
    return [self setRawValue:obj forField:key];
}

- (BOOL)setNumber:(NSNumber*)obj forField:(NSString*)key {
    return [self setRawValue:obj forField:key];
}

- (BOOL)setLocation:(BBLocation*)obj forField:(NSString*)key {
    return [self setRawValue:obj forField:key];
}

- (BOOL)setObject:(BBObject*)obj forField:(NSString*)key {
    return [self setRawValue:obj forField:key];
}

- (BOOL)setDate:(NSDate*)obj forField:(NSString*)key {
    return [self setRawValue:obj forField:key];
}

- (BOOL)setBoolean:(NSNumber*)obj forField:(NSString*)key {
    return [self setRawValue:[NSNumber numberWithBool:obj.boolValue] forField:key]; // always 1 or 0
}

- (BOOL)setDay:(NSDateComponents*)obj forField:(NSString*)key {
    return [self setRawValue:obj forField:key];
}

- (BOOL)setDayFromDate:(NSDate*)date forField:(NSString*)key {
    NSDateComponents *obj = [[NSCalendar currentCalendar] components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit fromDate:date];
    return [self setRawValue:obj forField:key];
}

- (BOOL)setJSON:(id)obj forField:(NSString*)key {
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:obj options:kNilOptions error:&error];
    if (error || !data) return NO;
    
    NSString* command = [NSString stringWithFormat:@"set-%@", key];
    [self._fields setObject:obj forKey:key];
    [self._commands setObject:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] forKey:command];
    return YES;
}

- (BOOL)setRawValue:(id)obj forField:(NSString*)key {
    NSString* commandValue = [BBUtils stringFromObject:obj addEntity:NO];
    if (!commandValue) return NO;
    
    NSString* command = [NSString stringWithFormat:@"set-%@", key];
    [self._fields setObject:obj forKey:key];
    [self._commands setObject:commandValue forKey:command];
    return YES;
}

- (BOOL)addObject:(BBObject*)object forField:(NSString*)key {
    if (!object.identifier) return NO;
    
    NSString* command = [NSString stringWithFormat:@"add-%@", key];
    NSMutableArray* arr = [self._commands objectForKey:command];
    if (!arr) {
        arr = [NSMutableArray array];
        [self._commands setObject:arr forKey:command];
    }
    [arr addObject:object.identifier];
    return YES;
}

- (BOOL)removeObject:(BBObject*)object forField:(NSString*)key {
    if (!object.identifier) return NO;
    
    NSString* command = [NSString stringWithFormat:@"rem-%@", key];
    NSMutableArray* arr = [self._commands objectForKey:command];
    if (!arr) {
        arr = [NSMutableArray array];
        [self._commands setObject:arr forKey:command];
    }
    [arr addObject:object.identifier];
    return YES;
}

- (void)removeField:(NSString*)key {
    NSString* command = [NSString stringWithFormat:@"del-%@", key];
    [self._fields removeObjectForKey:key];
    [self._commands setObject:@"-" forKey:command]; // TODO, not tested. REST API could change
}

// TODO: support many increments without overriding previous command
- (void)incrementField:(NSString*)key by:(NSInteger)value {
    NSNumber* n = [self numberForField:key];
    if (n) {
        n = [NSNumber numberWithInteger:n.integerValue+value];
    } else {
        n = [NSNumber numberWithInteger:value];
    }
    [self._fields setObject:n forKey:key];
    NSString* command = [NSString stringWithFormat:@"incr-%@", key];
    [self._commands setObject:[NSString stringWithFormat:@"%d", value] forKey:command];
}

- (void)processResponse:(id)result success:(SuccessOperationObjectBlock)success failure:(FailureObjectBlock)failure {
    if (![result isKindOfClass:[NSDictionary class]]) {
        if (failure) {
            failure(self, [BBError errorWithStatus:@"InvalidResponse" result:result]);
        }
        return;
    }
    
    NSString* status      = [result stringForKey:@"status"];
    NSString* authCode    = [result stringForKey:@"auth"];
    NSDictionary* objects = [result dictionaryForKey:@"objects"];
    NSString* identifier  = [result stringForKey:@"id"];
    
    if (!status || !identifier || !objects) {
        if (failure) {
            failure(self, [BBError errorWithStatus:@"InvalidResponse" result:result]);
        }
        return;
    }
    
    self._identifier = identifier;
    
    if (![status isEqualToString:@"Success"] && ![status isEqualToString:@"PendingValidation"]) {
        if (failure) {
            failure(self, [BBError errorWithStatus:status result:result]);
        }
        return;
    }
    NSMutableDictionary* selfDict = [NSMutableDictionary dictionaryWithObject:self forKey:self._identifier];
    [BBObject objectsWithSession:self._session values:objects references:selfDict];
    if (success) {
        success(status, self, authCode);
    }
}

- (void)processResponse:(id)result error:(NSError*)err failure:(FailureObjectBlock)failure {
    if (![result isKindOfClass:[NSDictionary class]]) {
        if (failure) {
            failure(self, [BBError errorWithStatus:@"InvalidResponse" result:result]);
        }
        return;
    }
    
    NSString* status = [result stringForKey:@"status"];
    if (status) {
        if (failure) {
            failure(self, [BBError errorWithStatus:status result:result]);
        }
        return;
    }
    
    if (failure) {
        failure(self, [BBError errorWithError:err]);
    }
}

- (void)save:(SuccessObjectBlock)success failure:(FailureObjectBlock)failure {
    if (!self._entity) {
        if (failure) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                failure(self, [BBError errorWithStatus:@"UnknownEntity" result:nil]);
            }];
        }
    }
    
    NSString* path = nil;
    NSString* method = nil;
    if (self._identifier) {
        method = @"PUT";
        path = [NSString stringWithFormat:@"/data/%@/%@", self._entity, self._identifier];
    } else {
        method = @"POST";
        path = [NSString stringWithFormat:@"/data/%@", self._entity];
    }
    
    [self._session perform:method path:path params:self._commands fetchPolicy:BBFetchPolicyRemoteOnly success:^(id result, BOOL fromCache) {
        [self._commands removeAllObjects];
        
        [self processResponse:result success:^(NSString* status, BBObject* object, NSString* authCode) {
            if ([self.entity isEqualToString:@"user"]) {
                [self._fields removeObjectForKey:@"password"];
            }
            if ([self.entity isEqualToString:@"user"] && [method isEqualToString:@"POST"]) {
                [Backbeam logout]; // logout previous user
                if ([status isEqualToString:@"Success"]) { // not PendingValidation
                    [self._session setCurrentUser:self withAuthCode:authCode];
                }
            }
            if (success) {
                success(object);
            }
        } failure:failure];
    } failure:^(id result, NSError* err) {
        [self processResponse:result error:err failure:failure];
    }];
}

- (void)remove:(SuccessObjectBlock)success failure:(FailureObjectBlock)failure {
    if (!self._entity || !self._identifier) {
        if (failure) {
            [[NSOperationQueue currentQueue] addOperationWithBlock:^{
                failure(self, [BBError errorWithStatus:@"UnknownEntityOrIdentifier" result:nil]);
            }];
        }
    }
    NSString* path = [NSString stringWithFormat:@"/data/%@/%@", self._entity, self._identifier];
    
    [self._session perform:@"DELETE" path:path params:nil fetchPolicy:BBFetchPolicyRemoteOnly success:^(id result, BOOL fromCache) {
        [self processResponse:result success:^(NSString* status, BBObject* object, NSString* authCode) {
            // TODO: if (is current user) logout; return;
            if (success) {
                success(self);
            }
        } failure:failure];
    } failure:^(id result, NSError* err) {
        [self processResponse:result error:err failure:failure];
    }];
}

- (void)refresh:(SuccessObjectBlock)success failure:(FailureObjectBlock)failure {
    [self refresh:nil params:nil success:success failure:failure];
}

- (void)refresh:(NSString*)joins params:(NSArray*)params success:(SuccessObjectBlock)success failure:(FailureObjectBlock)failure {
    if (!self._entity || !self._identifier) {
        if (failure) {
            [[NSOperationQueue currentQueue] addOperationWithBlock:^{
                failure(self, [BBError errorWithStatus:@"UnknownEntityOrIdentifier" result:nil]);
            }];
        }
    }
    
    NSString *path = [NSString stringWithFormat:@"/data/%@/%@", self._entity, self._identifier];
    NSMutableDictionary *prms = nil;
    if (joins) {
        prms = [[NSMutableDictionary alloc] initWithCapacity:2];
        [prms setObject:joins forKey:@"joins"];
        if (params) {
            [prms setObject:[BBUtils stringsFromParams:params] forKey:@"params"];
        }
    }
    [self._session perform:@"GET" path:path params:prms fetchPolicy:BBFetchPolicyRemoteOnly success:^(id result, BOOL fromCache) {
        [self processResponse:result success:^(NSString* status, BBObject* object, NSString* authCode) {
            if (success) {
                success(object);
            }
        } failure:failure];
    } failure:^(id result, NSError* err) {
        [self processResponse:result error:err failure:failure];
    }];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"entity=%@ identifier=%@ fields=%@", self.entity, self.identifier, self._fields];
}

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
- (UIImage*)imageWithSize:(CGSize)size
                  success:(SuccessImageBlock)success {
    
    NSNumber* version = [self numberForField:@"version"];
    return [self._session image:self._identifier version:version withSize:size progress:nil success:success failure:^(NSError* error) {
        // ignore
        NSLog(@"error %@", error);
    }];
}

- (UIImage*)imageWithSize:(CGSize)size
                  success:(SuccessImageBlock)success
                  failure:(FailureObjectBlock)failure {
    
    NSNumber* version = [self numberForField:@"version"];
    return [self._session image:self._identifier version:version withSize:size progress:nil success:success failure:^(NSError* error) {
        if (failure) {
            failure(self, error);
        }
    }];
}


- (UIImage*)imageWithSize:(CGSize)size
                 progress:(ProgressDataBlock)progress
                  success:(SuccessImageBlock)success
                  failure:(FailureObjectBlock)failure {
    
    NSNumber* version = [self numberForField:@"version"];
    return [self._session image:self._identifier version:version withSize:size progress:progress success:success failure:^(NSError* error) {
        if (failure) {
            failure(self, error);
        }
    }];
}

#endif

// upload data

- (BOOL)uploadDataWithProgress:(NSData*)data
                      fileName:fileName
                      mimeType:mimeType
                      progress:(ProgressDataBlock)progress
                       success:(SuccessObjectBlock)success
                       failure:(FailureObjectBlock)failure {
    
    NSString* path = nil;
    NSString* httpMethod = nil;
    if (self._identifier) {
        httpMethod = @"PUT";
        path = [@"/data/file/upload/" stringByAppendingString:self._identifier];
    } else {
        httpMethod = @"POST";
        path = @"/data/file/upload";
    }
    
    [self._session upload:httpMethod
                     data:data
                 fileName:fileName
                 mimeType:mimeType
                     path:path
                   params:self._commands
                     sign:YES
                 progress:progress success:^(id result) {
                     if (![result isKindOfClass:[NSDictionary class]]) {
                         if (failure) {
                             failure(self, [BBError errorWithStatus:@"InvalidResponse" result:result]);
                         }
                         return;
                     }
                     NSDictionary* objects = [result dictionaryForKey:@"objects"];
                     NSString *identifier = [result stringForKey:@"id"];
                     if (!objects || !identifier) {
                         if (failure) {
                             failure(self, [BBError errorWithStatus:@"InvalidResponse" result:result]);
                         }
                         return;
                     }
                     
                     NSString *status = [result stringForKey:@"status"];
                     if (![status isEqualToString:@"Success"]) {
                         if (failure) {
                             failure(self, [BBError errorWithStatus:status result:result]);
                         }
                         return;
                     }
                     
                     self._identifier = identifier;
                     
                     NSMutableDictionary* selfDict = [NSMutableDictionary dictionaryWithObject:self forKey:self._identifier];
                     [BBObject objectsWithSession:self._session values:objects references:selfDict];
                     
                     if (success) {
                         success(self);
                     }
    } failure:^(id result, NSError* error) {
        // TODO: response message?
        if (failure) {
            failure(self, error);
        }
    }];
    
    return NO;
}

- (BOOL)uploadDataWithProgress:(NSData*)data
                      progress:(ProgressDataBlock)progress
                       success:(SuccessObjectBlock)success
                       failure:(FailureObjectBlock)failure {
    
    NSString* fileName = @"noname.dat";
    NSString* mimeType = @"application/octet-stream";
    
    return [self uploadDataWithProgress:data fileName:fileName mimeType:mimeType progress:progress success:success failure:failure];
}

- (BOOL)uploadFileWithProgress:(NSString*)path
                      progress:(ProgressDataBlock)progress
                       success:(SuccessObjectBlock)success
                       failure:(FailureObjectBlock)failure {
    
    NSData* data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        if (failure) {
            failure(self, [BBError errorWithStatus:@"CannotReadFile" result:nil]);
        }
        return NO;
    }
    NSString* fileName = [path lastPathComponent];
    return [self uploadDataWithProgress:data fileName:fileName mimeType:nil progress:progress success:success failure:failure];
}

- (BOOL)uploadData:(NSData*)data
           success:(SuccessObjectBlock)success
           failure:(FailureObjectBlock)failure {
    
    NSString* fileName = @"noname.dat";
    NSString* mimeType = @"application/octet-stream";
    
    return [self uploadDataWithProgress:data fileName:fileName mimeType:mimeType progress:nil success:success failure:failure];
}

- (BOOL)uploadFile:(NSString*)path
           success:(SuccessObjectBlock)success
           failure:(FailureObjectBlock)failure {
    
    return [self uploadFileWithProgress:path progress:nil success:success failure:failure];
}

// download data

- (BOOL)downloadDataWithProgress:(ProgressDataBlock)progress
                         success:(SuccessDownloadBlock)success
                         failure:(FailureObjectBlock)failure {
    
    if (!self._identifier) { return NO; }
    NSNumber* version = [self numberForField:@"version"];
    if (!version) { return NO; }
    
    NSString* path = [NSString stringWithFormat:@"/data/file/download/%@/%@", self._identifier, version];
    [self._session downloadPath:path progress:progress success:^(NSData* data) {
        if (success) {
            success(self, data);
        }
    } failure:^(NSError* error) {
        if (failure) {
            failure(self, error);
        }
    }];
    return YES;
}

- (BOOL)downloadData:(SuccessDownloadBlock)success
             failure:(FailureObjectBlock)failure {
    
    return [self downloadDataWithProgress:nil success:success failure:failure];
}

// helper methods

- (BOOL)isEmpty {
    return self._createdAt == nil;
}

- (BOOL)idDirty {
    return self._commands.count > 0;
}

- (BOOL)isNew {
    return self._identifier == nil;
}

@end
