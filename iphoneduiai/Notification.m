//
//  Notification.m
//  iphoneduiai
//
//  Created by Cloud Dai on 12-10-8.
//  Copyright (c) 2012年 duiai.com. All rights reserved.
//

#import "Notification.h"
#import <RestKit/RestKit.h>
#import <RestKit/JSONKit.h>
#import "Utils.h"

static Notification *sharedNDelegate = nil;
static NSString *fileName = @"notifications.plist";

@interface Notification ()

@property (strong, nonatomic) NSString *filePath;
@property (strong, nonatomic) NSMutableDictionary *message, *feed, *notice;
@property (strong, nonatomic) NSDate *updated;

@end

@implementation Notification

- (void)dealloc
{
    NSLog(@"page ...");
    [_feed release];
    [_message release];
    [_notice release];
    [_updated release];
    [super dealloc];
}

+ (Notification*)sharedInstance
{
    static Notification *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[Notification alloc] initWithPlist];
    });
    
    return _sharedInstance;
}

- (id)initWithPlist
{
    self = [super init];
    if (self == nil) {
        return nil;
    }

    NSMutableDictionary *notiData =nil;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.filePath]) {
        notiData = [NSDictionary dictionaryWithContentsOfFile:self.filePath];
        
    }
    
    if (notiData) {
        _message = [notiData[@"message"] retain];
        _notice = [notiData[@"notice"] retain];
        _feed = [notiData[@"feed"] retain];
        _updated = [notiData[@"updated"] retain];
    } else{
        _message = [[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:0], @"count",
                        [NSMutableDictionary dictionary], @"data",  nil] retain];
        _notice = [[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:0], @"count",
                        [NSMutableDictionary dictionaryWithObjectsAndKeys:@"notice", @"type",
                         @"系统通知", @"title",
                         @"来自系统的温馨提示", @"subTitle",
                         @"AppShareBook.png", @"logo",
                         [NSNumber numberWithInteger:0], @"bageNum",
                         [NSDate date], @"updated",
                         nil], @"data",  nil] retain];
        _feed = [[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:0], @"count",
                       [NSMutableDictionary dictionaryWithObjectsAndKeys:@"feed", @"type",
                        @"我的动态", @"title",
                        @"来自你的最新最热的动态", @"subTitle",
                        @"AppShareimage.png", @"logo",
                        [NSNumber numberWithInteger:0], @"bageNum",
                        [NSDate date], @"updated",
                        nil], @"data",  nil] retain];
        _updated = [[NSDate date] retain];
    }
    
    return self;
}

- (NSString *)filePath
{
    if (_filePath == nil) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *dpath = [paths objectAtIndex:0];
        NSString *pathForNotiFile = [dpath stringByAppendingPathComponent:fileName];
        
        _filePath = [pathForNotiFile retain];
    }
    
    return _filePath;
}

#pragma mark import data
- (void)setMessage:(NSMutableDictionary *)message
{
    if (message == nil) {
        return;
    }
    
    self.messageCount = [message[@"icount"] integerValue];
    
    for (NSDictionary *d in message[@"list"]) {
        NSString *uid = d[@"senduid"];
        _message[@"data"][uid] = @{@"title": d[@"uinfo"][@"niname"], @"subTitle": d[@"content"],
        @"bageNum": d[@"newcount"], @"logo": d[@"uinfo"][@"photo"], @"type": @"message",
        @"updated": [NSDate dateWithTimeIntervalSince1970:[d[@"addtime"] integerValue]],
        @"data": d};
    }
}

- (void)setFeed:(NSMutableDictionary *)feed
{
    if (feed == nil) {
        return;
    }
    
    if (_feed[@"data"] == nil) {
       _feed[@"data"] = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"feed", @"type",
         @"我的动态", @"title",
         @"来自你的最新最热的动态", @"subTitle",
         @"AppShareimage.png", @"logo",
         [NSNumber numberWithInteger:0], @"bageNum",
         [NSDate date], @"updated",
         nil];
    }
    
    self.feedCount = [feed[@"icount"] integerValue];
    _feed[@"data"][@"bageNum"] = _feed[@"count"];
    _feed[@"data"][@"updated"] = [NSDate date];
}

- (void)setNotice:(NSMutableDictionary *)notice
{
    if (notice == nil) {
        return;
    }
    
    if (_notice[@"data"] == nil) {
        _notice[@"data"] = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"notice", @"type",
         @"系统通知", @"title",
         @"来自系统的温馨提示", @"subTitle",
         @"AppShareBook.png", @"logo",
         [NSNumber numberWithInteger:0], @"bageNum",
         [NSDate date], @"updated",
         nil];
    }
    
    self.noticeCount = [notice[@"icount"] integerValue];
    _notice[@"data"][@"bageNum"] = _notice[@"count"];
    _notice[@"data"][@"updated"] = [NSDate date];
}

- (NSMutableArray*)mergeAndOrderNotices
{

    NSMutableArray *tmp = [NSMutableArray arrayWithArray:[self.message[@"data"] allValues]];
    [tmp addObject:self.notice[@"data"]];
    [tmp addObject:self.feed[@"data"]];
    
    [tmp sortUsingComparator:^NSComparisonResult(NSDictionary *d1, NSDictionary *d2){
        NSDate *date1 = d1[@"updated"];
        NSDate *date2 = d2[@"updated"];
        
        return [date2 compare:date1];
    }];
    
    return tmp;
}

- (void)removeNoticeObject:(NSDictionary*)d
{
    if ([d[@"type"] isEqualToString:@"message"]) {
        [self.message[@"data"] removeObjectForKey:d[@"data"][@"senduid"]];
    } else if([d[@"type"] isEqualToString:@"notice"]){
        [self.notice removeObjectForKey:@"data"];
    } else if([d[@"type"] isEqualToString:@"feed"]){
        [self.feed removeObjectForKey:@"data"];
    }
}

#pragma mark request
- (void)updateFromRemote:(void(^)())block
{
    NSMutableDictionary *dp = [Utils queryParams];
    [dp setObject:[NSNumber numberWithInteger:0] forKey:@"accesstime"];
    
    [[RKClient sharedClient] get:[@"/common/sysnotice.api" stringByAppendingQueryParameters:dp] usingBlock:^(RKRequest *request){
        [request setOnDidFailLoadWithError:^(NSError *error){
            NSLog(@"sys notice: %@", [error description]);
        }];
        
        [request setOnDidLoadResponse:^(RKResponse *response){
            
            if (response.isOK && response.isJSON) {
                NSMutableDictionary *data = [[response bodyAsString] mutableObjectFromJSONString];
                
                NSInteger code = [data[@"error"] integerValue];
                if (code == 0) {

                    self.message = data[@"data"][@"usermessage"];
                    self.notice = data[@"data"][@"sysnotice"];
                    self.feed = data[@"data"][@"feed"];
                    self.updated = [NSDate date];
                    block();
                }
                
            }
        }];
    }];
}

#pragma mark counters 
- (void)setFeedCount:(NSInteger)feedCount
{
    self.feed[@"count"] = [NSNumber numberWithInteger:feedCount];
}

- (NSInteger)feedCount
{
    return [self.feed[@"count"] integerValue];
}

- (void)setMessageCount:(NSInteger)messageCount
{
    self.message[@"count"] = [NSNumber numberWithInteger:messageCount];

}

- (NSInteger)messageCount
{
    return [self.message[@"count"] integerValue];
}

- (void)setNoticeCount:(NSInteger)noticeCount
{
    self.notice[@"count"] = [NSNumber numberWithInteger:noticeCount];
}

- (NSInteger)noticeCount
{
    return [self.notice[@"count"] integerValue];
}

#pragma mark save data to plist
- (void)saveDataToPlist
{
  
    NSDictionary *d = @{@"message" : self.message, @"feed": self.feed, @"notice": self.notice};
    [d writeToFile:self.filePath atomically:YES];
}

#pragma mark Singleton Object Methods

+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (sharedNDelegate == nil) {
            sharedNDelegate = [super allocWithZone:zone];
            return sharedNDelegate;  // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain {
    return self;
}

- (unsigned)retainCount {
    return UINT_MAX;  // denotes an object that cannot be released
}

- (oneway void)release {
    //do nothing
}

- (id)autorelease {
    return self;
}

@end