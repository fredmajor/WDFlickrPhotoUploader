//
// Created by est1908 on 11/22/12.
// Modified by Fred 10/1/15
//
// To change the template use AppCode | Preferences | File Templates.
//


#import "SMStateMachineAsync.h"


@interface SMStateMachineAsync()
@property (strong, nonatomic) NSMutableArray *allowedTimingEvents;
@end

@implementation SMStateMachineAsync

#pragma mark - Initialization and threads

static dispatch_group_t dispatchGroup;
static dispatch_queue_t dispatchQueue;

+ (void)initialize{

    if( self == [SMStateMachineAsync class] ){
        [[self class] setDispatchGroup:[[self class] defaultDispatchGroup]];
    }
}

+ (dispatch_group_t)defaultDispatchGroup{

    static dispatch_once_t dOnceToken;
    static dispatch_group_t defaultGroup;
    dispatch_once(&dOnceToken, ^{
        defaultGroup = dispatch_group_create();
    });

    return defaultGroup;
}

+ (void)setDispatchGroup:(dispatch_group_t)aDispatchGroup{

    @synchronized(self){
        dispatchGroup = aDispatchGroup;
    }
}

+ (dispatch_group_t)dispatchGroup{

    @synchronized(self){
        return dispatchGroup;
    }
}

- (dispatch_queue_t)serialQueue{

    if( _serialQueue == NULL ){
        _serialQueue = dispatch_get_main_queue();
    }
    return _serialQueue;
}

#pragma mark - API
- (void)postAsync:(NSString *)event {

    dispatch_group_async([[self class] dispatchGroup], self.serialQueue, ^{
        [self post: event];
    });
}

-(void)dropTimingEvent:(NSString *)eventUuid {
    if ([self.allowedTimingEvents containsObject:eventUuid]){
        [self.allowedTimingEvents removeObject:eventUuid];
    }
}

-(NSString *)postAsync:(NSString *)event after:(NSUInteger)milliseconds {
    __weak SMStateMachineAsync* weakSelf = self;
    NSString *uuid = [self createUuid];
    [self.allowedTimingEvents addObject:uuid];
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, milliseconds * NSEC_PER_MSEC);
    dispatch_group_enter([[self class] dispatchGroup]);
    dispatch_after(timeout, self.serialQueue, ^{
        if ([weakSelf.allowedTimingEvents containsObject:uuid]){
            [weakSelf.allowedTimingEvents removeObject:uuid];
            [weakSelf postAsync:event];
        }
        dispatch_group_leave([[self class] dispatchGroup]);
    });
    return uuid;
}

-(NSString *)createUuid{
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString * res= (__bridge NSString *) (CFUUIDCreateString(kCFAllocatorDefault, uuid));
    return res;
}

-(NSMutableArray *)allowedTimingEvents {
    if (_allowedTimingEvents == nil){
        _allowedTimingEvents = [[NSMutableArray alloc] init];
    }
    return _allowedTimingEvents;
}

@end