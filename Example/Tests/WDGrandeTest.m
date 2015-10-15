#import "WDGrandeTest.h"


@implementation WDGrandeTest{

}

+ (void)setUp{

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
//        [WDCommon setUpCocoaLumberjack];
    });
}

- (void)waitForNotification:(NSString *)aNoteName block:(void (^)(void))aBlock{

    XCTestExpectation *expectation = [self expectationWithDescription:[NSString stringWithFormat:@"notification %@ arrived.",
                                                                                                 aNoteName]];
    id observer = [[NSNotificationCenter defaultCenter]
            addObserverForName:aNoteName object:nil queue:nil usingBlock:^(NSNotification *note){
                if( [note.name isEqualToString:aNoteName] ){
                    [expectation fulfill];
                }
            }];
    if( aBlock ){
        aBlock();
    }
    [self waitForExpectationsWithTimeout:10.0 handler:^(NSError *error){
        if( error ){
            DDLogError(@"There was an error waiting for notification named %@. Error=%@", aNoteName, error);
        }
    }];
    DDLogDebug(@"notification %@ arrived.", aNoteName);
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

- (NSArray *)filterArray:(NSArray *)aArray PredicateWithFormat:(NSString *)aFormat{

    NSPredicate *predicate = [NSPredicate predicateWithFormat:aFormat];
    return [aArray filteredArrayUsingPredicate:predicate];
}

- (NSInteger)getRandomNumberBetween:(int)from to:(int)to{

    return from+arc4random()%(to-from+1);
}

- (BOOL)randomTrueOrFalseWithProb:(NSUInteger)prob{

    NSInteger i = [self getRandomNumberBetween:1 to:100];
    return prob > i;
}

- (NSString *)generateRandomString:(NSUInteger)num{

    NSString *alphabet = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXZY0123456789";
    NSMutableString *s = [NSMutableString stringWithCapacity:num];
    for(NSUInteger i = 0U; i < num; i++){
        u_int32_t r = (u_int32_t) (arc4random()%[alphabet length]);
        unichar c = [alphabet characterAtIndex:r];
        [s appendFormat:@"%C", c];
    }
    return [NSString stringWithString:s];
}


- (NSURL *)generateRandomFileUrlMaxElements:(NSUInteger)aMaxElements minElements:(NSUInteger)aMinElements{

    NSURL *retval;
    NSMutableString *path = [NSMutableString string];
    NSUInteger elementsCount = (NSUInteger) [self getRandomNumberBetween:(int) aMinElements to:(int) aMaxElements];
    [path appendString:@"/"];
    for(int i = 0; i < elementsCount; ++i){
        [path appendFormat:@"%@/", [self generateRandomString:4]];
    }
    retval = [NSURL fileURLWithPath:path];
    return retval;
}

- (void)busyWaitingWithTimeout:(NSTimeInterval)aTimeout forCondition:(BOOL(^)(void))aBlock{
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:aTimeout];
    while( !aBlock() && ([timeoutDate timeIntervalSinceNow] > 0) ){
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, YES);
    }
}

- (void)waitForGroup:(dispatch_group_t)aGroup{

    __block BOOL didComplete = NO;
    DDLogDebug(@"Will wait for a dispatch group to finish");
    NSDate *start = [NSDate date];
    dispatch_group_notify(aGroup, dispatch_get_main_queue(), ^{
        didComplete = YES;
    });
    while( !didComplete ){
        NSTimeInterval const interval = 0.002;
        if( ![[NSRunLoop currentRunLoop]
                runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:interval]] ){
            [NSThread sleepForTimeInterval:interval];
        }
    }
    NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:start];
    DDLogDebug(@"Done waiting for a dispatch group. Wait time was=%f", duration);
}

@end