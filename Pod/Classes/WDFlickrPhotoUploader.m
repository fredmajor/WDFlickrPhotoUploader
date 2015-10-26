#import "WDFlickrPhotoUploader.h"
#import "SMStateMachineAsync.h"

NSUInteger const WD_UFlickr_uploadRetryCounter = 3;
NSUInteger const WD_UFlickr_checkPhotosetExistsRetryLimit = 3;
NSUInteger const WD_UFlickr_createPhotosetRetryLimit = 3;
NSUInteger const WD_UFlickr_assignPhotoRetryLimit = 3;

NSString *const WD_UFlickr_InitState = @"WD_UFlickr_InitState";
NSString *const WD_UFlickr_GetNextTaskState = @"WD_UFlickr_GetNextTaskState";
NSString *const WD_UFlickr_IsLoggedInDecision = @"WD_UFlickr_IsLoggedInDecision";
NSString *const WD_UFlickr_IsTaskNilDecision = @"WD_UFlickr_IsTaskNilDecision";
NSString *const WD_UFlickr_UploadImageState = @"WD_UFlickr_UploadImageState";
NSString *const WD_UFlickr_FinishedState = @"WD_UFlickr_FinishedState";
NSString *const WD_UFlickr_CheckUploadSuccessfulDecision = @"WD_UFlickr_CheckUploadSuccessfulDecision";
NSString *const WD_UFlickr_CheckIfPhotosetExistsState = @"WD_UFlickr_CheckIfPhotosetExistsState";
NSString *const WD_UFlickr_ErrorState = @"WD_UFlickr_ErrorState";
NSString *const WD_UFlickr_photosetExistsSuccessfulDecision = @"WD_UFlickr_photosetExistsSuccessfulDecision";
NSString *const WD_UFlickr_photosetExistsOrNotDecision = @"WD_UFlickr_photosetExistsOrNotDecision";
NSString *const WD_UFlickr_CreatePhotosetState = @"WD_UFlickr_CreatePhotosetState";
NSString *const WD_UFlickr_CreatePhotosetSuccessfulDecision = @"WD_UFlickr_CreatePhotosetSuccessfulDecision";
NSString *const WD_UFlickr_AssignPhotoState = @"WD_UFlickr_AssignPhotoState";
NSString *const WD_UFlickr_AssignPhotoSuccessfulDecision = @"WD_UFlickr_AssignPhotoSuccessfulDecision";
NSString *const WD_UFlickr_StopRequestedDecision = @"WD_UFlickr_StopRequestedDecision";
NSString *const WD_UFlickr_StoppedState = @"WD_UFlickr_StoppedState";

@implementation WDFlickrPhotoUploader{
    struct{
        BOOL photoUploadStarts : 1;
        BOOL photoUploadFinished : 1;
        BOOL progressUpdate : 1;
        BOOL error : 1;
        BOOL allTasksFinished : 1;
    } _delegateHas;

    __block WDFlickrUploadTask *currentUploadTask;
    NSUInteger uploadErrorCounter;
    NSUInteger checkPhotosetExistsCounter;
    NSUInteger createPhotosetErrorCounter;
    NSUInteger assignPhotoErrorCounter;

    BOOL uploadSuccessful;
    BOOL checkPhotosetExistsSuccessful;
    BOOL createPhotosetSuccessful;
    BOOL assignPhotoSuccessful;
    BOOL isStopRequested;

    NSString *errorMsg;
    NSString *currentPhotoId;
    NSString *currentPhotosetId;
    
    NSTimeInterval dataUploadTime;
    NSTimeInterval singleJobTotalTime;
    NSDate *dataUploadStart;
    NSDate *jobStart;
}

- (void)setDelegate:(id <WDFlickrPhotoUploaderDelegate>)delegate{

    if( _delegate != delegate ){
        _delegate = delegate;
        _delegateHas.photoUploadStarts = [delegate respondsToSelector:@selector(photoUploadStartsSender:task:)];
        _delegateHas.photoUploadFinished = [delegate respondsToSelector:@selector(sender:photoUploadFinished:dataUploadTime:totalJobTime:)];
        _delegateHas.progressUpdate = [delegate respondsToSelector:@selector(progressUpdateSender:sentBytes:totalBytes:)];
        _delegateHas.error = [delegate respondsToSelector:@selector(errorSender:error:)];
        _delegateHas.allTasksFinished = [delegate respondsToSelector:@selector(allTasksFinishedSender:)];
    }
}

- (instancetype)initWithFlickrController:(WDFlickrController *)flickrController
                            stateMachine:(SMStateMachineAsync *)stateMachine{

    self = [super init];
    if( self ){
        _flickrController = flickrController;
        _flickrController.delegate = self;
        _stateMachine = stateMachine;
        [self initStateMachine];
    }

    return self;
}

+ (instancetype)uploaderWithFlickrController:(WDFlickrController *)flickrController
                                stateMachine:(SMStateMachineAsync *)stateMachine{

    return [[self alloc] initWithFlickrController:flickrController stateMachine:stateMachine];
}

#pragma mark - State machine

- (void)initStateMachine{

    NSAssert(_stateMachine, @"sm needs to be set");
    __weak WDFlickrPhotoUploader *weakSelf = self;
    _stateMachine.globalExecuteIn = self;

    /*init to either getNextTask or back to init*/
    SMState *init = [_stateMachine createState:WD_UFlickr_InitState];
    _stateMachine.initialState = init;
    SMState *error = [_stateMachine createState:WD_UFlickr_ErrorState];
    [error setEntrySelector:@selector(informDelegateOnError)];
    SMState *getNextTask = [_stateMachine createState:WD_UFlickr_GetNextTaskState];
    SMDecision *isLoggedIn = [_stateMachine createDecision:WD_UFlickr_IsLoggedInDecision
                                            withPredicateBoolBlock:^BOOL{
                                                return [weakSelf.flickrController isLoggedIn];
                                            }];
    [_stateMachine transitionFrom:init to:isLoggedIn forEvent:@"C(startUpload)"];
    [_stateMachine trueTransitionFrom:isLoggedIn to:getNextTask];
    [_stateMachine falseTransitionFrom:isLoggedIn to:error withSel:@selector(setNotLoggedInErrorMsg)];
    [getNextTask setEntrySelector:@selector(getNextTaskAction)];

    /*getNextTask to either finish or UploadImage */
    SMDecision *isTaskNil = [_stateMachine createDecision:WD_UFlickr_IsTaskNilDecision
                                           withPredicateBoolBlock:^BOOL{
                                               return (currentUploadTask == nil);
                                           }];
    [_stateMachine transitionFrom:getNextTask to:isTaskNil forEvent:@"C(checkTask)"];
    SMState *finished = [_stateMachine createState:WD_UFlickr_FinishedState];
    [finished setEntrySelector:@selector(informDelegateOnFinishedAll)];
    SMState *uploadImage = [_stateMachine createState:WD_UFlickr_UploadImageState];
    [uploadImage setEntrySelector:@selector(uploadImageAction)];
    [_stateMachine trueTransitionFrom:isTaskNil to:finished];
    [_stateMachine falseTransitionFrom:isTaskNil to:uploadImage withSel:@selector(fromIsTaskNilToImageUpload)];

    /*from UploadImage to either CheckPhotosetExists or back to Init*/
    SMDecision *checkUploadSuccessful = [_stateMachine createDecision:WD_UFlickr_CheckUploadSuccessfulDecision
                                                       withPredicateBoolBlock:^BOOL{
                                                           return uploadSuccessful;
                                                       }];
    [_stateMachine falseTransitionFrom:checkUploadSuccessful
                   to:error
                   withSel:@selector(setFailedPhotoUploadErrorMsg)];
    SMState *checkIfPhotoExistsState = [_stateMachine createState:WD_UFlickr_CheckIfPhotosetExistsState];
    [checkIfPhotoExistsState setEntrySelector:@selector(checkIfPhotosetExistsAction)];
    [_stateMachine trueTransitionFrom:checkUploadSuccessful
                   to:checkIfPhotoExistsState
                   withSel:@selector(fromCheckUploadSuccessfulToCheckIfPhotosetExists)];
    [_stateMachine transitionFrom:uploadImage to:checkUploadSuccessful forEvent:@"C(checkUploadResult)"];

    /*from photosetExistsSuccessful decision*/
    SMDecision *photosetExistsSuccessfulDecision = [_stateMachine createDecision:WD_UFlickr_photosetExistsSuccessfulDecision
                                                                  withPredicateBoolBlock:^BOOL{
                                                                      return checkPhotosetExistsSuccessful;
                                                                  }];
    [_stateMachine transitionFrom:checkIfPhotoExistsState
                   to:photosetExistsSuccessfulDecision
                   forEvent:@"C(checkPhotosetExistsSuccessful)"];
    [_stateMachine falseTransitionFrom:photosetExistsSuccessfulDecision
                   to:error
                   withSel:@selector(setPhotosetCheckErrorMsg)];

    SMDecision *photosetExistsOrNotDecision = [_stateMachine createDecision:WD_UFlickr_photosetExistsOrNotDecision
                                                             withPredicateBoolBlock:^BOOL{
                                                                 return (currentPhotosetId != nil);
                                                             }];
    [_stateMachine trueTransitionFrom:photosetExistsSuccessfulDecision to:photosetExistsOrNotDecision];

    /*from createPhotosetState */
    SMState *createPhotosetState = [_stateMachine createState:WD_UFlickr_CreatePhotosetState];
    [_stateMachine falseTransitionFrom:photosetExistsOrNotDecision
                   to:createPhotosetState
                   withSel:@selector(fromPhotosetExistsOrNotToCreatePhotoset)];
    [createPhotosetState setEntrySelector:@selector(createPhotosetAction)];
    SMState *assignPhoto = [_stateMachine createState:WD_UFlickr_AssignPhotoState];
    [assignPhoto setEntrySelector:@selector(assignPhotoAction)];
    [_stateMachine trueTransitionFrom:photosetExistsOrNotDecision to:assignPhoto withSel:@selector(toAssignPhoto)];
    SMDecision *createPhotosetSuccessfulDecision = [_stateMachine createDecision:WD_UFlickr_CreatePhotosetSuccessfulDecision
                                                                  withPredicateBoolBlock:^BOOL{
                                                                      return createPhotosetSuccessful;
                                                                  }];
    [_stateMachine falseTransitionFrom:createPhotosetSuccessfulDecision
                   to:error
                   withSel:@selector(setPhotosetCreateErrorMsg)];
    [_stateMachine transitionFrom:createPhotosetState
                   to:createPhotosetSuccessfulDecision
                   forEvent:@"C(checkPhotosetCreation)"];

    /* from assignPhotoSuccessful decision*/
    SMState *stoppedState = [_stateMachine createState:WD_UFlickr_StoppedState];
    SMDecision *assignPhotoSuccessfulDecision = [_stateMachine createDecision:WD_UFlickr_AssignPhotoSuccessfulDecision
                                                               withPredicateBoolBlock:^BOOL{
                                                                   return assignPhotoSuccessful;
                                                               }];
    [_stateMachine transitionFrom:assignPhoto
                   to:assignPhotoSuccessfulDecision
                   forEvent:@"C(checkAssignmentSuccessful)"];
    [_stateMachine falseTransitionFrom:assignPhotoSuccessfulDecision
                   to:error
                   withSel:@selector(setAssignPhotoErrorMsg)];
    SMDecision *stopRequested = [_stateMachine createDecision:WD_UFlickr_StopRequestedDecision
                                               withPredicateBoolBlock:^BOOL{
                                                   return isStopRequested;
                                               }];
    [_stateMachine trueTransitionFrom:assignPhotoSuccessfulDecision
                   to:stopRequested
                   withSel:@selector(informDelegateOnPhotoUploadCompleted)];
    [_stateMachine trueTransitionFrom:stopRequested to:stoppedState];
    [_stateMachine falseTransitionFrom:stopRequested to:getNextTask];
    [_stateMachine trueTransitionFrom:createPhotosetSuccessfulDecision
                   to:stopRequested
                   withSel:@selector(informDelegateOnPhotoUploadCompleted)];

    [_stateMachine transitionFrom:finished to:init forEvent:@"C(resetState)"];
    [_stateMachine transitionFrom:stoppedState to:init forEvent:@"C(resetState)"];
    [_stateMachine transitionFrom:error to:init forEvent:@"C(resetState)"];
    
    [_stateMachine validate];
    DDLogInfo(@"FSM validated.");
}


#pragma mark Internal methods

- (void)moveToAssignPhotoSuccessfulDecision{

    [_stateMachine postAsync:@"C(checkAssignmentSuccessful)"];
}

- (void)moveToCreatePhotosetSuccessfulDecision{

    [_stateMachine postAsync:@"C(checkPhotosetCreation)"];
}

- (void)moveToPhotosetExistsSuccessfulDecision{

    [_stateMachine postAsync:@"C(checkPhotosetExistsSuccessful)"];
}

- (void)moveToIsTaskNilDecision{

    [_stateMachine postAsync:@"C(checkTask)"];
}

- (void)moveToCheckUploadSuccessful{

    [_stateMachine postAsync:@"C(checkUploadResult)"];
}

- (void)moveToIsLoggedIn{

    [_stateMachine postAsync:@"C(startUpload)"];
}

- (void)resetStateCall{
    [_stateMachine postAsync:@"C(resetState)"];
}

- (void)getNextTaskAction{

    jobStart = [NSDate date];
    if( _dataSource ){
        [self callOnMainThread:^(WDFlickrPhotoUploader *weakSelf){
            currentUploadTask = [_dataSource nextTask];
        }];
    }
    [self moveToIsTaskNilDecision];
}

- (void)informDelegateOnFinishedAll{

    DDLogDebug(@"%s", __PRETTY_FUNCTION__);
    if( _delegateHas.allTasksFinished ){
        [self callOnMainThread:^(WDFlickrPhotoUploader *weakSelf){
            [_delegate allTasksFinishedSender:weakSelf];
        }];
    }
}

- (void)informDelegateOnPhotoUploadCompleted{

    DDLogDebug(@"photo upload completed");
    singleJobTotalTime = [[NSDate date]timeIntervalSinceDate:jobStart];
    if( _delegateHas.photoUploadFinished ){
        [self callOnMainThread:^(WDFlickrPhotoUploader *weakSelf){
            [_delegate sender:weakSelf
                       photoUploadFinished:currentUploadTask
                       dataUploadTime:dataUploadTime
                       totalJobTime:singleJobTotalTime];
        }];
    }
}

#pragma mark Errors

- (void)setNotLoggedInErrorMsg{

    errorMsg = @"You are not logged in.";
}

- (void)setFailedPhotoUploadErrorMsg{

    errorMsg = @"Photo upload failed.";
}

- (void)setPhotosetCheckErrorMsg{

    errorMsg = @"Error while checking if a photoset exists.";
}

- (void)setPhotosetCreateErrorMsg{

    errorMsg = @"Error while creating a photoset.";
}

- (void)setAssignPhotoErrorMsg{

    errorMsg = @"Error while assigning a photo to a photoset";
}

- (void)informDelegateOnError{

    DDLogDebug(@"Will inform delegate on error if it listens.");
    if( _delegateHas.error ){
        [self callOnMainThread:^(WDFlickrPhotoUploader *weakSelf){
            [_delegate errorSender:weakSelf error:errorMsg];
        }];
    }
}

#pragma mark Image upload

- (void)fromIsTaskNilToImageUpload{

    uploadErrorCounter = 0;
    if( _delegateHas.photoUploadStarts ){
        [self callOnMainThread:^(WDFlickrPhotoUploader *weakSelf){
            [_delegate photoUploadStartsSender:weakSelf task:currentUploadTask];
        }];
    }
    dataUploadStart = [NSDate date];
}

- (void)uploadImageAction{

    NSMutableDictionary *uploadOptions = [NSMutableDictionary dictionary];
    if( currentUploadTask.tags ){
        uploadOptions[@"tags"] = currentUploadTask.tags;
    }
    if( [currentUploadTask.extraUploadOptions count] > 0 ){
        [uploadOptions addEntriesFromDictionary:currentUploadTask.extraUploadOptions];
    }
    [_flickrController uploadImageWithURL:currentUploadTask.fileURL
                       suggestedFilename:currentUploadTask.fileName
                       flickrOptions:[NSDictionary dictionaryWithDictionary:uploadOptions]];

}

- (void)fromCheckUploadSuccessfulToCheckIfPhotosetExists{

    checkPhotosetExistsCounter = 0;
    currentPhotosetId = nil;
}

- (void)checkIfPhotosetExistsAction{

    NSError *error;
    currentPhotosetId = [_flickrController checkIfPhotosetExists:currentUploadTask.albumName
                                           timeout:15.0
                                           error:&error];
    if( error ){
        if( ++checkPhotosetExistsCounter >= WD_UFlickr_checkPhotosetExistsRetryLimit ){
            checkPhotosetExistsSuccessful = NO;
            [self moveToPhotosetExistsSuccessfulDecision];
        }else{
            [self checkIfPhotosetExistsAction];
        }
    }else{
        checkPhotosetExistsSuccessful = YES;
        [self moveToPhotosetExistsSuccessfulDecision];
    }
}

- (void)fromPhotosetExistsOrNotToCreatePhotoset{

    createPhotosetErrorCounter = 0;
}

- (void)createPhotosetAction{

    NSError *error;
    currentPhotosetId = [_flickrController createPhotoset:currentUploadTask.albumName
                                           primaryPhotoId:currentPhotoId
                                           timeout:15.0
                                           error:&error];
    if( error ){
        if( ++createPhotosetErrorCounter >= WD_UFlickr_createPhotosetRetryLimit ){
            createPhotosetSuccessful = NO;
            [self moveToCreatePhotosetSuccessfulDecision];
        }else{
            DDLogWarn(@"repeating failed photoset creation");
            [self createPhotosetAction];
        }
    }else{
        createPhotosetSuccessful = YES;
        [self moveToCreatePhotosetSuccessfulDecision];
    }
}

- (void)toAssignPhoto{

    assignPhotoErrorCounter = 0;
    assignPhotoSuccessful = NO;
}

- (void)assignPhotoAction{

    NSError *error;
    [_flickrController assignPhoto:currentPhotoId toPhotoset:currentPhotosetId timeout:15.0 error:&error];

    if( error ){
        if( ++assignPhotoErrorCounter >= WD_UFlickr_assignPhotoRetryLimit ){
            assignPhotoSuccessful = NO;
            [self moveToAssignPhotoSuccessfulDecision];
        }else{
            [self assignPhotoAction];
        }
    }else{
        assignPhotoSuccessful = YES;
        [self moveToAssignPhotoSuccessfulDecision];
    }
}

#pragma mark WDFlickrControllerDelegate

- (void)photoUploadError:(WDFlickrController *)aSender photoURL:(NSURL *)aURL{

    if( ++uploadErrorCounter >= WD_UFlickr_uploadRetryCounter ){
        uploadSuccessful = NO;
        [self moveToCheckUploadSuccessful];
    }else{
        [self uploadImageAction];
    }
}

- (void)photoUploadSucceeded:(WDFlickrController *)aSender photoURL:(NSURL *)aURL photoId:(NSString *)aPhotoId{

    uploadSuccessful = YES;
    currentPhotoId = aPhotoId;
    dataUploadTime = [[NSDate date]timeIntervalSinceDate:dataUploadStart];
    [self moveToCheckUploadSuccessful];
}

- (void)photoUploadProgress:(WDFlickrController *)aSender photoURL:(NSURL *)aURL progress:(id)aProgress{

    if( _delegateHas.progressUpdate ){
        [self callOnMainThread:^(WDFlickrPhotoUploader *weakSelf){
            NSNumber *sentBytes = aProgress[@"sentBytes"];
            NSNumber *totalBytes = aProgress[@"totalBytes"];
            [_delegate progressUpdateSender:weakSelf
                       sentBytes:[sentBytes unsignedIntegerValue]
                       totalBytes:[totalBytes unsignedIntegerValue]];
        }];
    }
}

#pragma mark - Helpers

- (void)callOnMainThread:(void (^)(WDFlickrPhotoUploader *weakSelf))aBlock{

    if( !aBlock ){return;}
    __weak WDFlickrPhotoUploader *weakSelf = self;
    if( [NSThread isMainThread] ){
        aBlock(weakSelf);
    }else{
        dispatch_sync(dispatch_get_main_queue(), ^{
            aBlock(weakSelf);
        });
    }
}

#pragma mark - API

- (void)startUpload{

    isStopRequested = NO;
    [self moveToIsLoggedIn];
}

- (void)stopUpload{

    isStopRequested = YES;
}

- (void)resetState{
    
    [self resetStateCall];
}

- (NSString *)getState{

    return [[_stateMachine curState] name];
}

@end