//
//  Created by est1908 on 8/24/12.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <Foundation/Foundation.h>
#import "SMStateMachine.h"

@protocol SMMonitorNSLogDelegate <NSObject>

@optional
- (void)didExecuteTransitionFrom:(SMState *)from to:(SMState *)to withEvent:(NSString *)event;
@end

@interface SMMonitorNSLog : NSObject<SMMonitorDelegate>
@property (nonatomic, readonly, strong) NSString* smName;
@property(nonatomic, weak) id <SMMonitorNSLogDelegate> machineWatcher;
- (id)initWithSmName:(NSString *)smName;
@end