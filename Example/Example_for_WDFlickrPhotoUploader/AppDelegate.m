#import "AppDelegate.h"
#import <WDFlickrPhotoUploader/SMCommon.h>

@interface AppDelegate ()

@property(weak) IBOutlet NSWindow *window;

- (void)WD_initFlickr;
@end

@implementation AppDelegate{
    WDFlickrPhotoUploader *fPhotoUploader;
    WDFlickrController *fController;
    NSUInteger currentDatasourceIndex;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification{

    self.allDoneTb.hidden = YES;
    [self WD_initFlickr];
    currentDatasourceIndex = 0;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification{
    // Insert code here to tear down your application
}

- (void)WD_tearDonwFlickr{

    [[NSNotificationCenter defaultCenter] removeObserver:self name:WD_Flickr_StateChanged object:fController];
}

- (void)WD_initFlickr{

    [WDFlickrFactory setApiKey:@"--YOUR--KEY--"];
    [WDFlickrFactory setApiSecret:@"--YOUR--SECRET--"];
    [WDFlickrFactory setCallbackUrlBase:@"flickrexample://callback"];
    fController = [WDFlickrFactory getFlickrControllerInstance];
    fPhotoUploader = [WDFlickrFactory getFlickrUploaderInstance];
    fPhotoUploader.dataSource = self;
    fPhotoUploader.delegate = self;
    SMMonitorNSLog *fStateMachineMonitor = fPhotoUploader.stateMachine.monitor;
    fStateMachineMonitor.machineWatcher = self;
    [[NSNotificationCenter defaultCenter]
            addObserver:self
            selector:@selector(WD_flickrControllerNotificationHandler:)
            name:WD_Flickr_StateChanged
            object:fController];
}

- (IBAction)logIn:(id)sender{

    [fController logIn];
}

- (IBAction)logOut:(id)sender{

    [fController logOut];
    [self handleLogOut];
}

- (IBAction)resetControllerErrors:(id)sender{

    [fController resetErrors];
}

- (IBAction)selectFiles:(id)sender{

    NSOpenPanel *openDlg = [NSOpenPanel openPanel];
    NSArray *allowedExtensions = @[
            @"jpg",
            @"jpeg",
            @"tiff",
            @"gif",
            @"png",
            @"mp4",
            @"avi",
            @"wmv",
            @"mov",
            @"mpeg",
            @"3gp",
            @"m2ts",
            @"ogg",
            @"ogv"
    ];
    [openDlg setAllowedFileTypes:allowedExtensions];
    openDlg.title = @"Select files to upload";
    openDlg.showsResizeIndicator = YES;
    openDlg.showsHiddenFiles = NO;
    openDlg.canChooseDirectories = NO;
    openDlg.canChooseFiles = YES;
    openDlg.canCreateDirectories = NO;
    openDlg.allowsMultipleSelection = YES;

    [openDlg beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if( result == NSFileHandlingPanelOKButton ){
            NSMutableArray *tasks = [NSMutableArray array];
            for(NSURL *dirUrl in [openDlg URLs]){
                WDFlickrUploadTask *uploadTask = [[WDFlickrUploadTask alloc] init];
                uploadTask.fileURL = dirUrl;
                uploadTask.fileName = [dirUrl lastPathComponent];
                uploadTask.albumName = @"testAlbum";
                uploadTask.tags = @"example,tags";
                [tasks addObject:uploadTask];
                [self log:[NSString stringWithFormat:@"added upload job for a file: %@", [dirUrl absoluteString]]];
            }
            self.uploadTasks = tasks;
        }
    }];
}

- (IBAction)startUpload:(id)sender{
    
    self.allDoneTb.hidden = YES;
    [fPhotoUploader startUpload];
}

- (IBAction)stopUpload:(id)sender{
    [fPhotoUploader stopUpload];
}

- (IBAction)resetUploaderState:(id)sender{
    [fPhotoUploader resetState];
}

- (void)WD_flickrControllerNotificationHandler:(NSNotification *)aNote{

    NSNumber *oldState = aNote.userInfo[@"oldState"];
    NSNumber *newState = aNote.userInfo[@"newState"];
    NSString *reason = aNote.userInfo[@"reason"];
    [self log:[NSString stringWithFormat:@"Flickr controller state changed from %@ (%@) to %@ (%@). Reason:%@",
                                         [WDFlickrController controllerStateToString:[oldState unsignedIntegerValue]],
                                         oldState,
                                         [WDFlickrController controllerStateToString:[newState unsignedIntegerValue]],
                                         newState,
                                         reason]];

    if( [newState unsignedIntegerValue] == WD_Flickr_InitState ){
        self.loggedIn = NO;
    }
    if( [newState unsignedIntegerValue] == WD_Flickr_LoggedInState ){
        self.loggedIn = YES;
        [self handleLogIn:aNote];
    }
    if( [newState unsignedIntegerValue] == WD_Flickr_LoginErrorState
        || [newState unsignedIntegerValue] == WD_Flickr_LoginTimeoutState ){
        self.fControllerError = YES;
    }
    if( [oldState unsignedIntegerValue] == WD_Flickr_LoginErrorState
        || [oldState unsignedIntegerValue] == WD_Flickr_LoginTimeoutState ){
        self.fControllerError = NO;
    }
}


#pragma mark - WDFlickrPhotoUploaderDataSource

- (WDFlickrUploadTask *)nextTask{

    if(currentDatasourceIndex < [self.uploadTasks count]){
        return self.uploadTasks[currentDatasourceIndex++];
    }else{
        return nil;
    }
}

#pragma mark - WDFlickrPhotoUploaderDelegate

- (void)photoUploadStartsSender:(WDFlickrPhotoUploader *)aSender task:(WDFlickrUploadTask *)aTask{

    self.uploadInProgress = YES;
    [self log:[NSString stringWithFormat:@"started upload of a file: %@", [aTask.fileURL absoluteString]]];
    self.currentFileLabel.stringValue = aTask.fileName;
}

- (void)     sender:(WDFlickrPhotoUploader *)aSender
photoUploadFinished:(WDFlickrUploadTask *)aTask
     dataUploadTime:(NSTimeInterval)aUploadTime
       totalJobTime:(NSTimeInterval)aTotalJobTime{

    [self log:[NSString stringWithFormat:@"finished upload of a file: %@. Data upload time:%.2f, additional flickr operations time:%.2f",
                                         [aTask.fileURL absoluteString],
                                         aUploadTime,
                                         aTotalJobTime]];
    self.dataUploadTImeTb.stringValue = [NSString stringWithFormat:@"%.2f", aUploadTime];
    self.totalJobTimeTb.stringValue = [NSString stringWithFormat:@"%.2f", aTotalJobTime];
}

- (void)progressUpdateSender:(WDFlickrPhotoUploader *)aSender
                   sentBytes:(NSUInteger)aSent
                  totalBytes:(NSUInteger)aTotal{
    
    self.progressBar.doubleValue = aSent;
    self.progressBar.maxValue = aTotal;
    self.progressBar.minValue = 0;
}

- (void)errorSender:(WDFlickrPhotoUploader *)aSender error:(NSString *)aErrorDsc{
    
    [self log:[NSString stringWithFormat:@"error during upload. msg=%@", aErrorDsc]];
    self.uploadInProgress = NO;
}

- (void)allTasksFinishedSender:(WDFlickrPhotoUploader *)aSender{
    
    [self log:@"all upload tasks finished."];
    self.uploadInProgress = NO;
    self.allDoneTb.hidden = NO;
}


#pragma mark - SMMonitorNSLogDelegate
//state watching is currently implemented in a pretty ugly way
- (void)didExecuteTransitionFrom:(SMState *)from to:(SMState *)to withEvent:(NSString *)event{
    self.currState = to.name;
    if([to.name isEqualToString:WD_UFlickr_InitState]
       || [to.name isEqualToString:WD_UFlickr_ErrorState]
       || [to.name isEqualToString:WD_UFlickr_FinishedState]
       || [to.name isEqualToString:WD_UFlickr_StoppedState]){
        self.uploaderInSomeFinalState = YES;
    }else{
        self.uploaderInSomeFinalState = NO;
    }
}

#pragma mark - Helpers

- (void)handleLogIn:(NSNotification *)aNote{

    self.username = aNote.userInfo[@"username"];
    self.nsid = aNote.userInfo[@"nsid"];
    self.accessToken = aNote.userInfo[@"accessToken"];
    self.secret = aNote.userInfo[@"secret"];
    self.buddyImageView.image = [WDFlickrController getFlickrBuddyIcon:self.nsid];
}

- (void)handleLogOut{

    self.username = @"";
    self.nsid = @"";
    self.accessToken = @"";
    self.secret = @"";
    self.buddyImageView.image = [NSImage imageNamed:@"NSUser"];
}

- (void)log:(NSString *)aMsg{

    static NSInteger logCounter = 0;
    [self appendToTextView:[NSString stringWithFormat:@"%lu. %@\n", logCounter++, aMsg]];
}

- (void)appendToTextView:(NSString *)text{

    dispatch_async(dispatch_get_main_queue(), ^{
        NSAttributedString *attr = [[NSAttributedString alloc] initWithString:text];
        [[self.logTv textStorage] appendAttributedString:attr];
        [self.logTv scrollRangeToVisible:NSMakeRange([[self.logTv string] length], 0)];
    });
}

@end
