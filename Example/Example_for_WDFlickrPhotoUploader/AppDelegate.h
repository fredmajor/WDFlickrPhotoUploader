#import <Cocoa/Cocoa.h>
#import <WDFlickrPhotoUploader/WDFlickrPhotoUploader.h>
#import <WDFlickrPhotoUploader/SMStateMachineAsync.h>
#import <WDFlickrPhotoUploader/SMMonitorNSLog.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, WDFlickrPhotoUploaderDataSource, WDFlickrPhotoUploaderDelegate, SMMonitorNSLogDelegate>
- (IBAction)logIn:(id)sender;
- (IBAction)logOut:(id)sender;
- (IBAction)resetControllerErrors:(id)sender;
- (IBAction)selectFiles:(id)sender;
- (IBAction)startUpload:(id)sender;
- (IBAction)stopUpload:(id)sender;
- (IBAction)resetUploaderState:(id)sender;


@property (weak) IBOutlet NSImageView *buddyImageView;
@property (unsafe_unretained) IBOutlet NSTextView *logTv;
@property (weak) IBOutlet NSArrayController *uploadTaskArrayController;
@property (weak) IBOutlet NSTextField *currentFileLabel;
@property (weak) IBOutlet NSProgressIndicator *progressBar;
@property (weak) IBOutlet NSTextField *dataUploadTImeTb;
@property (weak) IBOutlet NSTextField *totalJobTimeTb;
@property (weak) IBOutlet NSTextField *allDoneTb;

@property (strong, nonatomic) NSMutableArray *uploadTasks;
@property (nonatomic) BOOL loggedIn;
@property (nonatomic) BOOL fControllerError;
@property (nonatomic, copy) NSString *currState;
@property (nonatomic,copy) NSString* username;
@property (nonatomic,copy) NSString* nsid;
@property (nonatomic,copy) NSString* accessToken;
@property (nonatomic,copy) NSString* secret;
@property (nonatomic) BOOL uploadInProgress;
@property (nonatomic) BOOL uploaderInSomeFinalState;

@end

