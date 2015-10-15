#import <Foundation/Foundation.h>
#import "WDFlickrController.h"
#import "WDFlickrFactory.h"
#define DDLogInfo NSLog
#define DDLogDebug NSLog
#define DDLogWarn NSLog

extern NSUInteger const WD_UFlickr_uploadRetryCounter;
extern NSUInteger const WD_UFlickr_checkPhotosetExistsRetryLimit;
extern NSUInteger const WD_UFlickr_createPhotosetRetryLimit;
extern NSUInteger const WD_UFlickr_assignPhotoRetryLimit;

extern NSString *const WD_UFlickr_InitState;
extern NSString *const WD_UFlickr_GetNextTaskState;
extern NSString *const WD_UFlickr_IsLoggedInDecision;
extern NSString *const WD_UFlickr_IsTaskNilDecision;
extern NSString *const WD_UFlickr_UploadImageState;
extern NSString *const WD_UFlickr_FinishedState;
extern NSString *const WD_UFlickr_CheckUploadSuccessfulDecision;
extern NSString *const WD_UFlickr_CheckIfPhotosetExistsState;
extern NSString *const WD_UFlickr_ErrorState;
extern NSString *const WD_UFlickr_photosetExistsSuccessfulDecision;
extern NSString *const WD_UFlickr_photosetExistsOrNotDecision;
extern NSString *const WD_UFlickr_CreatePhotosetState;
extern NSString *const WD_UFlickr_CreatePhotosetSuccessfulDecision;
extern NSString *const WD_UFlickr_AssignPhotoState;
extern NSString *const WD_UFlickr_AssignPhotoSuccessfulDecision;
extern NSString *const WD_UFlickr_StopRequestedDecision;
extern NSString *const WD_UFlickr_StoppedState;

@class WDFlickrPhotoUploader, WDFlickrController, SMStateMachineAsync;

#pragma mark - FlickrUploadTask

@interface WDFlickrUploadTask : NSObject

@property(nonatomic, copy) NSURL *fileURL;
@property(nonatomic, copy) NSString *fileName;
@property(nonatomic, copy) NSString *albumName;
@property(nonatomic, copy) NSString *tags;
@property(nonatomic, copy) NSDictionary *extraUploadOptions;
@end

#pragma mark - WDFlickrPhotoUploaderDelegate

@protocol WDFlickrPhotoUploaderDelegate <NSObject>

@optional
- (void)photoUploadStartsSender:(WDFlickrPhotoUploader *)aSender task:(WDFlickrUploadTask *)aTask;

- (void)     sender:(WDFlickrPhotoUploader *)aSender
photoUploadFinished:(WDFlickrUploadTask *)aTask
     dataUploadTime:(NSTimeInterval)aUploadTime
     additionalTime:(NSTimeInterval)aAdditionalTime;

- (void)progressUpdateSender:(WDFlickrPhotoUploader *)aSender
                   sentBytes:(NSUInteger)aSent
                  totalBytes:(NSUInteger)aTotal;

- (void)errorSender:(WDFlickrPhotoUploader *)aSender error:(NSString *)aErrorDsc;

- (void)allTasksFinishedSender:(WDFlickrPhotoUploader *)aSender;


@end

#pragma mark - WDFlickrPhotoUploaderDataSource
@protocol WDFlickrPhotoUploaderDataSource <NSObject>

@required
- (WDFlickrUploadTask *)nextTask;

@end

#pragma mark - Class

@interface WDFlickrPhotoUploader : NSObject <WDFlickrControllerDelegate>

@property(readonly) WDFlickrController *flickrController;
@property(readonly) SMStateMachineAsync *stateMachine;
@property(nonatomic, weak) id <WDFlickrPhotoUploaderDelegate> delegate;
@property(nonatomic, weak) id <WDFlickrPhotoUploaderDataSource> dataSource;

- (instancetype)initWithFlickrController:(WDFlickrController *)flickrController
                            stateMachine:(SMStateMachineAsync *)stateMachine;

+ (instancetype)uploaderWithFlickrController:(WDFlickrController *)flickrController
                                stateMachine:(SMStateMachineAsync *)stateMachine;

/*public api*/
- (void)startUpload;

- (void)stopUpload;

- (NSString *)getState;
@end