//
// Created by est1908 on 11/22/12.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <Foundation/Foundation.h>
#import "SMStateMachine.h"


@interface SMStateMachineAsync : SMStateMachine

/**
   The process events serialQueue. If `NULL` (default), the main serialQueue is used.
 */
@property (nonatomic, strong) dispatch_queue_t serialQueue;

+ (dispatch_group_t)defaultDispatchGroup;

+ (void)setDispatchGroup:(dispatch_group_t)aDispatchGroup;

+ (dispatch_group_t)dispatchGroup;

- (void)postAsync:(NSString *)event;

- (NSString *)postAsync:(NSString *)event after:(NSUInteger)milliseconds;

- (void)dropTimingEvent:(NSString *)eventUuid;



@end