#import <XCTest/XCTest.h>
#define DDLogInfo NSLog
#define DDLogDebug NSLog
#define DDLogWarn NSLog
#define DDLogError NSLog

#define WD_ASSERT_MT_TEST NSAssert([NSThread isMainThread], @"Has to be run from main thread.");

@interface WDGrandeTest : XCTestCase


- (void)waitForNotification:(NSString *)aNoteName block:(void (^)(void))aBlock;

- (NSArray *)filterArray:(NSArray *)aArray PredicateWithFormat:(NSString *)aFormat;

- (NSInteger)getRandomNumberBetween:(int)from to:(int)to;

- (BOOL)randomTrueOrFalseWithProb:(NSUInteger)prob;

- (NSString *)generateRandomString:(NSUInteger)num;

- (NSURL *)generateRandomFileUrlMaxElements:(NSUInteger)aMaxElements minElements:(NSUInteger)aMinElements;

- (void)busyWaitingWithTimeout:(NSTimeInterval)aTimeout forCondition:(BOOL(^)(void))aBlock;

- (void)waitForGroup:(dispatch_group_t)aGroup;
@end