#import <XCTest/XCTest.h>
#import "WDGrandeTest.h"
#import <OCMock/OCMock.h>
#import <Expecta/Expecta.h>
#import "WDFlickrController.h"
#import "WDFlickrPhotoUploader.h"
#import "SMStateMachineAsync.h"
#import "SMMonitorNSLog.h"

@interface WDFlickrPhotoUploaderTest : WDGrandeTest <WDFlickrPhotoUploaderDelegate, WDFlickrPhotoUploaderDataSource, SMMonitorNSLogDelegate>

@end

@implementation WDFlickrPhotoUploaderTest{

    dispatch_group_t dispatchGroup;
    NSMutableSet *visitedStates;

    id mockedController;
    WDFlickrPhotoUploader *eut;
    BOOL delegateUploadStartedCalled;
    BOOL delegateUploadFinishedCalled;
    BOOL delegateUpateProgressCalled;
    BOOL delegateErrorCalled;
    BOOL delegaateAllTasksDoneCalled;
    BOOL datasourceNextCalled;

    WDFlickrUploadTask *taskToReturn;
    SMMonitorNSLog *machineMonitor;
    NSUInteger numberOfTasks;
    NSUInteger uploadStartedCounter;
}

- (void)setUp{

    [super setUp];

    /*tested object*/
    dispatchGroup = dispatch_group_create();
    mockedController = OCMClassMock([WDFlickrController class]);
    [SMStateMachineAsync setDispatchGroup:dispatchGroup];
    SMStateMachineAsync *sm = [[SMStateMachineAsync alloc] init];

    //monitor
    machineMonitor = [[SMMonitorNSLog alloc] initWithSmName:@"Flickr monitor"];
    machineMonitor.machineWatcher = self;
    sm.monitor = machineMonitor;

    eut = [WDFlickrPhotoUploader uploaderWithFlickrController:mockedController stateMachine:sm];
    eut.delegate = self;
    eut.dataSource = self;

    [self setVariables];
    taskToReturn = [[WDFlickrUploadTask alloc] init];
    visitedStates = [NSMutableSet set];
    numberOfTasks = 1;
    uploadStartedCounter = 0;
}

- (void)tearDown{

    [mockedController stopMocking];
    [self setVariables];
    [self waitForGroup:dispatchGroup];
    visitedStates = nil;
    [super tearDown];
}

- (void)setVariables{

    delegateUploadStartedCalled = NO;
    delegateUploadFinishedCalled = NO;
    delegateUpateProgressCalled = NO;
    delegateErrorCalled = NO;
    delegaateAllTasksDoneCalled = NO;
    datasourceNextCalled = NO;
}

#pragma mark - WDFlickrPhotoUploaderDelegate

- (void)photoUploadStartsSender:(WDFlickrPhotoUploader *)aSender task:(WDFlickrUploadTask *)aTask{

    WD_ASSERT_MT_TEST
    delegateUploadStartedCalled = YES;
    uploadStartedCounter++;
}

- (void)     sender:(WDFlickrPhotoUploader *)aSender
photoUploadFinished:(WDFlickrUploadTask *)aTask
     dataUploadTime:(NSTimeInterval)aUploadTime
       totalJobTime:(NSTimeInterval)aTotalJobTime{

    WD_ASSERT_MT_TEST
    delegateUploadFinishedCalled = YES;
}

- (void)progressUpdateSender:(WDFlickrPhotoUploader *)aSender
                   sentBytes:(NSUInteger)aSent
                  totalBytes:(NSUInteger)aTotal{

    WD_ASSERT_MT_TEST
    delegateUpateProgressCalled = YES;
}

- (void)errorSender:(WDFlickrPhotoUploader *)aSender error:(NSString *)aErrorDsc{

    WD_ASSERT_MT_TEST
    delegateErrorCalled = YES;
    DDLogDebug(@"delegate informed on error. msg=%@", aErrorDsc);
}

- (void)allTasksFinishedSender:(WDFlickrPhotoUploader *)aSender{

    WD_ASSERT_MT_TEST
    delegaateAllTasksDoneCalled = YES;
}

#pragma mark - WDFlickrPhotoUploaderDataSource

- (WDFlickrUploadTask *)nextTask{

    WD_ASSERT_MT_TEST
    datasourceNextCalled = YES;
    if( numberOfTasks-- > 0 ){
        return taskToReturn;
    }else{
        return nil;
    }
}

- (BOOL)didVisitState:(NSString *)stateName{

    return [visitedStates containsObject:stateName];
}

- (void)didExecuteTransitionFrom:(SMState *)from to:(SMState *)to withEvent:(NSString *)event{

    [visitedStates addObject:from.name];
    [visitedStates addObject:to.name];
}

#pragma mark - Tests

- (void)testStartUpload_failsOnNoLogin{
    //given
    OCMStub([mockedController isLoggedIn]).andReturn(NO);
    //when
    [eut startUpload];
    //test
    expect(delegateErrorCalled).will.equal(YES);
    expect([eut getState]).will.equal(WD_UFlickr_ErrorState);
}

- (void)testStartUpload_getsNextTask{
    //given
    OCMStub([mockedController isLoggedIn]).andReturn(YES);
    //when
    [eut startUpload];
    //test
    expect(delegateErrorCalled).will.equal(NO);
    expect(datasourceNextCalled).will.equal(YES);
}

- (void)testStartUpload_finishesWhenNoTasks{
    //given
    OCMStub([mockedController isLoggedIn]).andReturn(YES);
    taskToReturn = nil;

    //when
    [eut startUpload];

    //test
    expect([eut getState]).will.equal(WD_UFlickr_FinishedState);
}

- (void)testStartUpload_informsDelegateOnFinish{
    //given
    OCMStub([mockedController isLoggedIn]).andReturn(YES);
    taskToReturn = nil;

    //when
    [eut startUpload];

    //test
    expect(delegaateAllTasksDoneCalled).will.equal(YES);
}

- (void)testStartUpload_uploadsWhenTasksAvailable{
    //given
    OCMStub([mockedController isLoggedIn]).andReturn(YES);

    //when
    [eut startUpload];

    //test
    expect([eut getState]).will.equal(WD_UFlickr_UploadImageState);
}

- (void)testItRepeatsUploadXTimes{
    //given
    __block NSUInteger callCounter = 0;
    OCMStub([mockedController isLoggedIn]).andReturn(YES);
    OCMStub([mockedController uploadImageWithURL:[OCMArg any]
                              suggestedFilename:[OCMArg any]
                              flickrOptions:[OCMArg any]]).andDo(^(NSInvocation *invocation){
        callCounter++;
        dispatch_async(dispatch_get_main_queue(), ^{
            [eut photoUploadError:mockedController photoURL:nil];
        });
    });

    //when
    [eut startUpload];

    //test
    expect(callCounter).will.equal(WD_UFlickr_uploadRetryCounter);
}

- (void)testItCallsDelegateWhenUploadStarts{

    //given
    OCMStub([mockedController isLoggedIn]).andReturn(YES);

    //when
    [eut startUpload];

    //test
    expect(delegateUploadStartedCalled).will.equal(YES);
}

- (void)testIfUploadUpdatesDelegateOnProgress{

    //given
    OCMStub([mockedController isLoggedIn]).andReturn(YES);
    OCMStub([mockedController uploadImageWithURL:[OCMArg any]
                              suggestedFilename:[OCMArg any]
                              flickrOptions:[OCMArg any]]).andDo(^(NSInvocation *invocation){
        dispatch_async(dispatch_get_main_queue(), ^{
            [eut photoUploadProgress:nil photoURL:nil progress:nil];
        });
    });

    //when
    [eut startUpload];

    //test
    expect(delegateUpateProgressCalled).will.equal(YES);
}

- (void)testIfSuccessfulUploadGoesToCheckIfPhotosetExists{
    //given
    OCMStub([mockedController isLoggedIn]).andReturn(YES);
    OCMStub([mockedController uploadImageWithURL:[OCMArg any]
                              suggestedFilename:[OCMArg any]
                              flickrOptions:[OCMArg any]]).andDo(^(NSInvocation *invocation){
        dispatch_async(dispatch_get_main_queue(), ^{
            [eut photoUploadSucceeded:nil photoURL:nil photoId:nil];
        });
    });

    //when
    [eut startUpload];

    //test
    expect([self didVisitState:WD_UFlickr_CheckIfPhotosetExistsState]).will.equal(YES);
}

- (void)testIfFailedUploadGoesToError{
    //given
    OCMStub([mockedController isLoggedIn]).andReturn(YES);
    OCMStub([mockedController uploadImageWithURL:[OCMArg any]
                              suggestedFilename:[OCMArg any]
                              flickrOptions:[OCMArg any]]).andDo(^(NSInvocation *invocation){
        dispatch_async(dispatch_get_main_queue(), ^{
            [eut photoUploadError:nil photoURL:nil];
        });
    });

    //when
    [eut startUpload];

    //test
    expect([eut getState]).will.equal(WD_UFlickr_ErrorState);
}

- (void)testIfFailedUploadCallsDelegate{

    //given
    OCMStub([mockedController isLoggedIn]).andReturn(YES);
    OCMStub([mockedController uploadImageWithURL:[OCMArg any]
                              suggestedFilename:[OCMArg any]
                              flickrOptions:[OCMArg any]]).andDo(^(NSInvocation *invocation){
        dispatch_async(dispatch_get_main_queue(), ^{
            [eut photoUploadError:nil photoURL:nil];
        });

    });

    //when
    [eut startUpload];

    //test
    expect(delegateErrorCalled).will.equal(YES);
}

- (void)testThatRepeatsCheckIfPhotosetExistsOnError{

    //given
    __block NSUInteger callCounter = 0;
    OCMStub([mockedController isLoggedIn]).andReturn(YES);
    OCMStub([mockedController uploadImageWithURL:[OCMArg any]
                              suggestedFilename:[OCMArg any]
                              flickrOptions:[OCMArg any]]).andDo(^(NSInvocation *invocation){
        [eut photoUploadSucceeded:nil photoURL:nil photoId:nil];
    });

    [[[[mockedController stub]
            andDo:^(NSInvocation *invocation){
                callCounter++;
                NSError *__autoreleasing *anError = nil;
                [invocation getArgument:&anError atIndex:4];
                *anError = [NSError errorWithDomain:@"MYDomain" code:2323 userInfo:nil];
            }]
            ignoringNonObjectArgs]
            checkIfPhotosetExists:[OCMArg any] timeout:0 error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    //when
    [eut startUpload];

    //test
    expect(callCounter).will.equal(WD_UFlickr_checkPhotosetExistsRetryLimit);
}

- (void)testThatCheckIfPhotosetExistGoToErrorStateOnError{

    //given
    OCMStub([mockedController isLoggedIn]).andReturn(YES);
    OCMStub([mockedController uploadImageWithURL:[OCMArg any]
                              suggestedFilename:[OCMArg any]
                              flickrOptions:[OCMArg any]]).andDo(^(NSInvocation *invocation){
        [eut photoUploadSucceeded:nil photoURL:nil photoId:nil];
    });

    [[[[mockedController stub]
            andDo:^(NSInvocation *invocation){
                NSError *__autoreleasing *anError = nil;
                [invocation getArgument:&anError atIndex:4];
                *anError = [NSError errorWithDomain:@"MYDomain" code:2323 userInfo:nil];
            }]
            ignoringNonObjectArgs]
            checkIfPhotosetExists:[OCMArg any] timeout:0 error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    //when
    [eut startUpload];

    //test
    expect([eut getState]).will.equal(WD_UFlickr_ErrorState);
    expect(delegateErrorCalled).equal(YES);
}

- (void)testThatCheckIfPhotosetExistsCallsControllerMethod{

    //given
    OCMStub([mockedController isLoggedIn]).andReturn(YES);
    OCMStub([mockedController uploadImageWithURL:[OCMArg any]
                              suggestedFilename:[OCMArg any]
                              flickrOptions:[OCMArg any]]).andDo(^(NSInvocation *invocation){
        [eut photoUploadSucceeded:nil photoURL:nil photoId:nil];
    });

    [[[mockedController expect]
            ignoringNonObjectArgs]
            checkIfPhotosetExists:[OCMArg any] timeout:0 error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    //when
    [eut startUpload];

    //test
    OCMVerifyAllWithDelay(mockedController, 0.5);
}

- (void)testThatGoesToCreatePhotosetIfDoesntExist{

    //given
    OCMStub([mockedController isLoggedIn]).andReturn(YES);
    OCMStub([mockedController uploadImageWithURL:[OCMArg any]
                              suggestedFilename:[OCMArg any]
                              flickrOptions:[OCMArg any]]).andDo(^(NSInvocation *invocation){
        [eut photoUploadSucceeded:nil photoURL:nil photoId:nil];
    });
    [[[[mockedController stub]
            andReturn:nil]
            ignoringNonObjectArgs]
            checkIfPhotosetExists:[OCMArg any] timeout:0 error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    //when
    [eut startUpload];

    //test
    expect([self didVisitState:WD_UFlickr_CreatePhotosetState]).will.equal(YES);
}

- (void)testThatGoesToAssignPhotoIfPhotosetExists{

    //given
    OCMStub([mockedController isLoggedIn]).andReturn(YES);
    OCMStub([mockedController uploadImageWithURL:[OCMArg any]
                              suggestedFilename:[OCMArg any]
                              flickrOptions:[OCMArg any]]).andDo(^(NSInvocation *invocation){
        [eut photoUploadSucceeded:nil photoURL:nil photoId:nil];
    });
    [[[[mockedController stub]
            andReturn:@"lol"]
            ignoringNonObjectArgs]
            checkIfPhotosetExists:[OCMArg any] timeout:0 error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    //when
    [eut startUpload];

    //test
    expect([self didVisitState:WD_UFlickr_AssignPhotoState]).will.equal(YES);
}

- (void)testThatCreatePhotosetRepeatsOnErrors{

    /*
     *given
     */
    //logged in
    OCMStub([mockedController isLoggedIn]).andReturn(YES);

    //image uploaded
    OCMStub([mockedController uploadImageWithURL:[OCMArg any]
                              suggestedFilename:[OCMArg any]
                              flickrOptions:[OCMArg any]]).andDo(^(NSInvocation *invocation){
        [eut photoUploadSucceeded:nil photoURL:nil photoId:nil];
    });

    //photoset doesn't exist
    [[[[mockedController stub]
            andReturn:nil]
            ignoringNonObjectArgs]
            checkIfPhotosetExists:[OCMArg any] timeout:0 error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    //fake error when creating photoset
    __block NSUInteger callCounter = 0;
    [[[[mockedController stub]
            andDo:^(NSInvocation *invocation){
                callCounter++;
                NSError *__autoreleasing *anError = nil;
                [invocation getArgument:&anError atIndex:5];
                *anError = [NSError errorWithDomain:@"MYDomain" code:2323 userInfo:nil];
            }]
            ignoringNonObjectArgs]
            createPhotoset:[OCMArg any]
            primaryPhotoId:[OCMArg any]
            timeout:0
            error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    /*
     *when
     */
    [eut startUpload];

    /*
     *test
     */
    expect(callCounter).will.equal(WD_UFlickr_createPhotosetRetryLimit);

}

- (void)testThatCreatePhotosetCallsProperControllerMethod{
    /*
     *given
     */
    //logged in
    OCMStub([mockedController isLoggedIn]).andReturn(YES);

    //image uploaded
    OCMStub([mockedController uploadImageWithURL:[OCMArg any]
                              suggestedFilename:[OCMArg any]
                              flickrOptions:[OCMArg any]]).andDo(^(NSInvocation *invocation){
        [eut photoUploadSucceeded:nil photoURL:nil photoId:nil];
    });

    //photoset doesn't exist
    [[[[mockedController stub]
            andReturn:nil]
            ignoringNonObjectArgs]
            checkIfPhotosetExists:[OCMArg any] timeout:0 error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    [[[mockedController expect]
            ignoringNonObjectArgs]
            createPhotoset:[OCMArg any]
            primaryPhotoId:[OCMArg any]
            timeout:0
            error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    //when
    [eut startUpload];

    //test
    OCMVerifyAllWithDelay(mockedController, 0.5);
}

- (void)testThatIfCreatePhotosetFailedGoesToErrorAndNotifiesDelegate{

    /*
     *given
     */
    //logged in
    OCMStub([mockedController isLoggedIn]).andReturn(YES);

    //image uploaded
    OCMStub([mockedController uploadImageWithURL:[OCMArg any]
                              suggestedFilename:[OCMArg any]
                              flickrOptions:[OCMArg any]]).andDo(^(NSInvocation *invocation){
        [eut photoUploadSucceeded:nil photoURL:nil photoId:nil];
    });

    //photoset doesn't exist
    [[[[mockedController stub]
            andReturn:nil]
            ignoringNonObjectArgs]
            checkIfPhotosetExists:[OCMArg any] timeout:0 error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    //fake error when creating photoset
    [[[[mockedController stub]
            andDo:^(NSInvocation *invocation){
                NSError *__autoreleasing *anError = nil;
                [invocation getArgument:&anError atIndex:5];
                *anError = [NSError errorWithDomain:@"MYDomain" code:2323 userInfo:nil];
            }]
            ignoringNonObjectArgs]
            createPhotoset:[OCMArg any]
            primaryPhotoId:[OCMArg any]
            timeout:0
            error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    /*
     *when
     */
    [eut startUpload];

    /*
     *test
     */
    expect([eut getState]).will.equal(WD_UFlickr_ErrorState);
    expect(delegateErrorCalled).will.equal(YES);
}

- (void)testThatCreatePhotosetGoesToAssignPhotoOnSuccess{
    /*
     *given
     */

    //logged in
    OCMStub([mockedController isLoggedIn]).andReturn(YES);

    //image uploaded
    OCMStub([mockedController uploadImageWithURL:[OCMArg any]
                              suggestedFilename:[OCMArg any]
                              flickrOptions:[OCMArg any]]).andDo(^(NSInvocation *invocation){
        [eut photoUploadSucceeded:nil photoURL:nil photoId:nil];
    });

    //photoset doesn't exist
    [[[[mockedController stub]
            andReturn:nil]
            ignoringNonObjectArgs]
            checkIfPhotosetExists:[OCMArg any] timeout:0 error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    //photoset created just fine
    [[[[mockedController stub]
            andReturn:@"lol"]
            ignoringNonObjectArgs]
            createPhotoset:[OCMArg any]
            primaryPhotoId:[OCMArg any]
            timeout:0
            error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    /*
     *when
     */
    [eut startUpload];

    /*
     *test
     */
    expect([self didVisitState:WD_UFlickr_AssignPhotoState]).will.equal(YES);
}

- (void)testThatAssignPhotoRepeatsOnError{

    /*
     *given
     */
    //logged in
    OCMStub([mockedController isLoggedIn]).andReturn(YES);

    //image uploaded
    OCMStub([mockedController uploadImageWithURL:[OCMArg any]
                              suggestedFilename:[OCMArg any]
                              flickrOptions:[OCMArg any]]).andDo(^(NSInvocation *invocation){
        [eut photoUploadSucceeded:nil photoURL:nil photoId:nil];
    });

    //photoset doesn't exist
    [[[[mockedController stub]
            andReturn:nil]
            ignoringNonObjectArgs]
            checkIfPhotosetExists:[OCMArg any] timeout:0 error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    //photoset created just fine
    [[[[mockedController stub]
            andReturn:@"lol"]
            ignoringNonObjectArgs]
            createPhotoset:[OCMArg any]
            primaryPhotoId:[OCMArg any]
            timeout:0
            error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    //fake error on assign photo
    __block NSUInteger callCounter = 0;
    [[[[mockedController stub]
            andDo:^(NSInvocation *invocation){
                callCounter++;
                NSError *__autoreleasing *anError = nil;
                [invocation getArgument:&anError atIndex:5];
                *anError = [NSError errorWithDomain:@"MYDomain" code:2323 userInfo:nil];
            }]
            ignoringNonObjectArgs]
            assignPhoto:[OCMArg any]
            toPhotoset:[OCMArg any]
            timeout:0
            error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    /*
     *when
     */
    [eut startUpload];

    /*
     *test
     */
    expect(callCounter).will.equal(WD_UFlickr_assignPhotoRetryLimit);
}

- (void)testThatAssignPhotoCallController{
    /*
     *given
     */
    //logged in
    OCMStub([mockedController isLoggedIn]).andReturn(YES);

    //image uploaded
    OCMStub([mockedController uploadImageWithURL:[OCMArg any]
                              suggestedFilename:[OCMArg any]
                              flickrOptions:[OCMArg any]]).andDo(^(NSInvocation *invocation){
        [eut photoUploadSucceeded:nil photoURL:nil photoId:nil];
    });

    //photoset doesn't exist
    [[[[mockedController stub]
            andReturn:nil]
            ignoringNonObjectArgs]
            checkIfPhotosetExists:[OCMArg any] timeout:0 error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    //photoset created just fine
    [[[[mockedController stub]
            andReturn:@"lol"]
            ignoringNonObjectArgs]
            createPhotoset:[OCMArg any]
            primaryPhotoId:[OCMArg any]
            timeout:0
            error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    [[[mockedController expect]
            ignoringNonObjectArgs]
            assignPhoto:[OCMArg any]
            toPhotoset:[OCMArg any]
            timeout:0
            error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    //when
    [eut startUpload];

    //test
    OCMVerifyAllWithDelay(mockedController, 0.5);
}

- (void)testThatAssignPhotoGoesToErrorAndNotifiesDelegateOnError{

    /*
     *given
     */
    //logged in
    OCMStub([mockedController isLoggedIn]).andReturn(YES);

    //image uploaded
    OCMStub([mockedController uploadImageWithURL:[OCMArg any]
                              suggestedFilename:[OCMArg any]
                              flickrOptions:[OCMArg any]]).andDo(^(NSInvocation *invocation){
        [eut photoUploadSucceeded:nil photoURL:nil photoId:nil];
    });

    //photoset doesn't exist
    [[[[mockedController stub]
            andReturn:nil]
            ignoringNonObjectArgs]
            checkIfPhotosetExists:[OCMArg any] timeout:0 error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    //photoset created just fine
    [[[[mockedController stub]
            andReturn:@"lol"]
            ignoringNonObjectArgs]
            createPhotoset:[OCMArg any]
            primaryPhotoId:[OCMArg any]
            timeout:0
            error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    //fake error on assign photo
    [[[[mockedController stub]
            andDo:^(NSInvocation *invocation){
                NSError *__autoreleasing *anError = nil;
                [invocation getArgument:&anError atIndex:5];
                *anError = [NSError errorWithDomain:@"MYDomain" code:2323 userInfo:nil];
            }]
            ignoringNonObjectArgs]
            assignPhoto:[OCMArg any]
            toPhotoset:[OCMArg any]
            timeout:0
            error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    /*
     *when
     */
    [eut startUpload];

    /*test*/
    expect([eut getState]).will.equal(WD_UFlickr_ErrorState);
    expect(delegateErrorCalled).equal(YES);
}

- (void)testThatAssignPhotoGoesToStopRequestedOnSuccess{

    /*
     *given
     */
    //logged in
    OCMStub([mockedController isLoggedIn]).andReturn(YES);

    //image uploaded
    OCMStub([mockedController uploadImageWithURL:[OCMArg any]
                              suggestedFilename:[OCMArg any]
                              flickrOptions:[OCMArg any]]).andDo(^(NSInvocation *invocation){
        [eut photoUploadSucceeded:nil photoURL:nil photoId:nil];
    });

    //photoset doesn't exist
    [[[[mockedController stub]
            andReturn:nil]
            ignoringNonObjectArgs]
            checkIfPhotosetExists:[OCMArg any] timeout:0 error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    //photoset created just fine
    [[[[mockedController stub]
            andReturn:@"lol"]
            ignoringNonObjectArgs]
            createPhotoset:[OCMArg any]
            primaryPhotoId:[OCMArg any]
            timeout:0
            error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    /*
     *when
     */
    [eut startUpload];

    /*test*/
    expect([self didVisitState:WD_UFlickr_StopRequestedDecision]).will.equal(YES);
}

- (void)testThatStopRequestedStopsIfNeeded{

    /*
     *given
     */
    //logged in
    OCMStub([mockedController isLoggedIn]).andReturn(YES);

    //image uploaded
    OCMStub([mockedController uploadImageWithURL:[OCMArg any]
                              suggestedFilename:[OCMArg any]
                              flickrOptions:[OCMArg any]]).andDo(^(NSInvocation *invocation){
        [eut photoUploadSucceeded:nil photoURL:nil photoId:nil];
    });

    //photoset doesn't exist
    [[[[mockedController stub]
            andReturn:nil]
            ignoringNonObjectArgs]
            checkIfPhotosetExists:[OCMArg any] timeout:0 error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    //photoset created just fine
    [[[[mockedController stub]
            andReturn:@"lol"]
            ignoringNonObjectArgs]
            createPhotoset:[OCMArg any]
            primaryPhotoId:[OCMArg any]
            timeout:0
            error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    /*
     *when
     */
    [eut startUpload];
    [eut stopUpload];

    /*test*/
    expect([self didVisitState:WD_UFlickr_StopRequestedDecision]).will.equal(YES);
    expect([self didVisitState:WD_UFlickr_StoppedState]).will.equal(YES);
}

- (void)testThatItWorksInLoop{
    /*
     *given
     */
    //logged in
    OCMStub([mockedController isLoggedIn]).andReturn(YES);

    //image uploaded
    OCMStub([mockedController uploadImageWithURL:[OCMArg any]
                              suggestedFilename:[OCMArg any]
                              flickrOptions:[OCMArg any]]).andDo(^(NSInvocation *invocation){
        [eut photoUploadSucceeded:nil photoURL:nil photoId:nil];
    });

    //photoset doesn't exist
    [[[[mockedController stub]
            andReturn:nil]
            ignoringNonObjectArgs]
            checkIfPhotosetExists:[OCMArg any] timeout:0 error:(NSError *__autoreleasing *) [OCMArg anyPointer]];

    //photoset created just fine
    [[[[mockedController stub]
            andReturn:@"lol"]
            ignoringNonObjectArgs]
            createPhotoset:[OCMArg any]
            primaryPhotoId:[OCMArg any]
            timeout:0
            error:(NSError *__autoreleasing *) [OCMArg anyPointer]];
    numberOfTasks = 10;

    /*
     *when
     */
    [eut startUpload];

    expect(uploadStartedCounter).will.equal(10);
    expect([eut getState]).will.equal(WD_UFlickr_FinishedState);
}


@end
