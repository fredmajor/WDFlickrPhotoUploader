#import "WDFlickrController.h"

/*local constants*/
static const NSString *WD_Flickr_buddyUrlBase = @"https://flickr.com/buddyicons/";

/*defaults*/
static const NSTimeInterval WD_Flickr_defaultLoginTimeoutInt = 60;

/*notifications*/
NSString *const WD_Flickr_StateChanged = @"WD_Flickr_StateChanged";

@interface WDFlickrController ()

- (void)WD_PostNotificationOnMainThread:(NSString *)aNotification userInfo:(NSDictionary *)aUserInfo;
+ (NSString *)mimeTypeForFile:(NSString *)aFilePath;
@end

@implementation WDFlickrController{
    WDFlickrState _controllerState;
    NSTimer *loginTimer;
    BOOL loginTestResult;
    BOOL loginTestResponseArrived;

    struct{
        BOOL photoUploadError : 1;
        BOOL photoUploadSucceeded : 1;
        BOOL photoUploadProgress : 1;
    } _delegateHas;

    /*image upload*/
    NSURL *currentImageUpload;

    /*check if a photoset exists*/
    NSMutableArray *photosetsReceivedRaw;
    BOOL photosetCheckComplete;
    BOOL photosetCheckError;

    /*create photoset*/
    BOOL createPhotosetComplete;
    BOOL createPhotosetError;
    NSString *createPhotosetResult;

    /*assign photo*/
    BOOL assignPhotoComplete;
    BOOL assignPhotoError;
}

#pragma mark - Properties

- (void)setDelegate:(id <WDFlickrControllerDelegate>)delegate{

    if( _delegate != delegate ){
        _delegate = delegate;
        _delegateHas.photoUploadError = [delegate respondsToSelector:@selector(photoUploadError:photoURL:)];
        _delegateHas.photoUploadSucceeded = [delegate respondsToSelector:@selector(photoUploadSucceeded:photoURL:photoId:)];
        _delegateHas.photoUploadProgress = [delegate respondsToSelector:@selector(photoUploadProgress:photoURL:progress:)];
    }
}

- (NSTimeInterval)loginTimeout{

    if( _loginTimeout ){
        return _loginTimeout;
    }else{
        return WD_Flickr_defaultLoginTimeoutInt;
    }
}

- (NSString *)callbackUrlBase{

    NSAssert(_callbackUrlBase, @"Callback url needs to be set for login to work");
    return _callbackUrlBase;
}

#pragma mark - Init

- (instancetype)initWithFlickrAPIContext:(OFFlickrAPIContext *)flickrAPIContext
                        flickrAPIRequest:(OFFlickrAPIRequest *)flickrAPIRequest{

    self = [super init];
    if( self ){
        _flickrAPIContext = flickrAPIContext;
        _flickrAPIRequest = flickrAPIRequest;
        flickrAPIRequest.delegate = self;
        [[NSAppleEventManager sharedAppleEventManager]
                setEventHandler:self
                andSelector:@selector(handleGetURLEvent:withReplyEvent:)
                forEventClass:kInternetEventClass
                andEventID:kAEGetURL];
        DDLogInfo(@"WDFlickrController initiated!");
    }
    return self;
}

+ (instancetype)controllerWithFlickrAPIContext:(OFFlickrAPIContext *)flickrAPIContext
                              flickrAPIRequest:(OFFlickrAPIRequest *)flickrAPIRequest{

    return [[self alloc] initWithFlickrAPIContext:flickrAPIContext flickrAPIRequest:flickrAPIRequest];
}

- (void)dealloc{

    DDLogWarn(@"deallocating WDFLickrController");
    [[NSAppleEventManager sharedAppleEventManager]
            removeEventHandlerForEventClass:kInternetEventClass andEventID:kAEGetURL];
}

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent{

    NSURL *url = [NSURL URLWithString:[[event paramDescriptorForKeyword:keyDirectObject] stringValue]];
    NSLog(@"GET call handler got url=%@", url);
    [self WD_handleNotificationWithGetUrl:url];
}

- (void)WD_handleNotificationWithGetUrl:(NSURL *)aUrl{

    if( _controllerState == WD_Flickr_UserInBrowserState ){
        NSString *token, *verifier = nil;
        NSURL *url = aUrl;
        BOOL result = OFExtractOAuthCallback(url, [NSURL URLWithString:self.callbackUrlBase], &token, &verifier);
        if( result ){
            [self WD_changeState:WD_Flickr_fetchingOauthAccessTokenState
                  withDescription:@"requested access token"];
            [self.flickrAPIRequest fetchOAuthAccessTokenWithRequestToken:token verifier:verifier];
            DDLogInfo(@"Requested for OAuth access token.");
            return;
        }

        //there was a problem if we are here
        [self WD_changeState:WD_Flickr_LoginErrorState withDescription:@"error after user action"];
    }else{
        DDLogWarn(@"callback received but wrong state");
    }
}

- (void)WD_checkRunningLoginForTimeout:(NSTimer *)aTimer{

    if( _controllerState == WD_Flickr_FetchingOauthRequestTokenState
        || _controllerState == WD_Flickr_UserInBrowserState
        || _controllerState == WD_Flickr_fetchingOauthAccessTokenState ){
        [self.flickrAPIRequest cancel];
        [self WD_changeState:WD_Flickr_LoginTimeoutState withDescription:@"login timeout"];
    }

    [aTimer invalidate];
    loginTimer = nil;
}

#pragma mark - Public Interface

- (void)logIn{

    if( _controllerState == WD_Flickr_InitState ){
        [self WD_changeState:WD_Flickr_FetchingOauthRequestTokenState withDescription:@"login started"];

        BOOL b = [self.flickrAPIRequest fetchOAuthRequestTokenWithCallbackURL:[NSURL URLWithString:self.callbackUrlBase]];
        if( !b ){
            [self WD_changeState:WD_Flickr_LoginErrorState
                  withDescription:@"login failed when trying to fetch request token"];
        }else{
            loginTimer = [NSTimer scheduledTimerWithTimeInterval:self.loginTimeout
                                  target:self
                                  selector:@selector(WD_checkRunningLoginForTimeout:)
                                  userInfo:nil
                                  repeats:NO];
        }
    }
}

- (void)logOut{

    if( _controllerState == WD_Flickr_LoggedInState ){
        [self.flickrAPIRequest cancel];
        self.flickrAPIContext.OAuthToken = nil;
        self.flickrAPIContext.OAuthTokenSecret = nil;
        [self WD_changeState:WD_Flickr_InitState withDescription:@"log out"];
    }
}

- (BOOL)testLogin{

    BOOL retval = NO;
    if( _controllerState == WD_Flickr_LoggedInState || _controllerState == WD_Flickr_PhotoUploadState
        || _controllerState == WD_Flickr_ManualLogin || _controllerState == WD_Flickr_CheckPhotosetExists
        || _controllerState == WD_Flickr_CreatePhotoset || _controllerState == WD_Flickr_AssignPhoto ){
        [self WD_changeState:WD_Flickr_TestingLoginState withDescription:@"testing login"];
        [self.flickrAPIRequest callAPIMethodWithGET:@"flickr.test.login" arguments:nil];

        NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:7.0];
        loginTestResult = NO;
        loginTestResponseArrived = NO;
        while( !loginTestResponseArrived && ([timeoutDate timeIntervalSinceNow] > 0) ){
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, YES);
        }
        retval = loginTestResult;
        if( retval ){
            [self autoChangeStateToLoggedIn];
        }else{
            [self WD_changeState:WD_Flickr_InitState withDescription:@"login test failed"];
        }
    }
    return retval;
}

- (BOOL)logInManuallyWithToken:(NSString *)aToken
                    withSecret:(NSString *)aSecret
                      username:(NSString *)aUsername
                          nsid:(NSString *)aNsid{

    if( _controllerState == WD_Flickr_InitState ){
        [self WD_changeState:WD_Flickr_ManualLogin withDescription:@"Manual login procedure started"];
        self.flickrAPIContext.OAuthToken = aToken;
        self.flickrAPIContext.OAuthTokenSecret = aSecret;
        _nsid = aNsid;
        _username = aUsername;

        BOOL result = [self testLogin];
        if( result ){
            DDLogInfo(@"autologin succeded");
        }else{
            DDLogWarn(@"autologin failed.");
        }
        return result;
    }
    return NO;
}

- (void)resetErrors{

    if( _controllerState == WD_Flickr_LoginErrorState || _controllerState == WD_Flickr_LoginTimeoutState ){
        [self.flickrAPIRequest cancel];
        [self WD_changeState:WD_Flickr_InitState withDescription:@"reset errors"];
    }
}

- (BOOL)isLoggedIn{

    return _controllerState == WD_Flickr_LoggedInState;
}

- (void)uploadImageWithURL:(NSURL *)aImageUrl
         suggestedFilename:(NSString *)aFilename
             flickrOptions:(NSDictionary *)aOptions{

    if( _controllerState == WD_Flickr_LoggedInState ){
        [self WD_changeState:WD_Flickr_PhotoUploadState withDescription:@"photo upload starts up"];
        [_flickrAPIRequest uploadImageStream:[NSInputStream inputStreamWithURL:aImageUrl]
                           suggestedFilename:aFilename
                           MIMEType:[WDFlickrController mimeTypeForFile:[aImageUrl path]]
                           arguments:aOptions];
        currentImageUpload = aImageUrl;
        DDLogInfo(@"Ordered upload of:%@", aImageUrl);
    }
}

- (NSArray *)availablePhotosetsSync:(NSTimeInterval)aTimeout error:(NSError *__autoreleasing *)aError{

    NSArray *result;
    NSDate *startDate = [NSDate date];
    if( _controllerState == WD_Flickr_LoggedInState ){
        [self WD_changeState:WD_Flickr_CheckPhotosetExists withDescription:@"check if a photoset exists"];
        photosetCheckComplete = NO;
        photosetCheckError = NO;
        [_flickrAPIRequest callAPIMethodWithGET:@"flickr.photosets.getList" arguments:nil];
        NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:aTimeout];
        while( !photosetCheckComplete && ([timeoutDate timeIntervalSinceNow] > 0) ){
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, YES);
        }

        if( photosetCheckComplete ){
            if( photosetCheckError ){
                result = nil;
                *aError = [NSError errorWithDomain:@"FlickrError"
                                   code:4
                                   userInfo:@{@"reason" : @"Flickr communication error. Try again."}];
            }else{
                result = [NSArray arrayWithArray:photosetsReceivedRaw];
            }
        }else{
            /*timeout*/
            [self autoChangeStateToLoggedIn];
            result = nil;
            *aError = [NSError errorWithDomain:@"FlickrError"
                               code:3
                               userInfo:@{@"reason" : @"Timeout. Try again."}];
        }
    }else{
        *aError = [NSError errorWithDomain:@"FlickrError"
                           code:2
                           userInfo:@{@"reason" : @"Wrong internal state of Flickr controller. Sounds like a bug."}];
    }
    NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:startDate];
    DDLogInfo(@"Getting photoset took: %.2f", duration);
    return result;
}

- (NSString *)createPhotoset:(NSString *)aTitle
              primaryPhotoId:(NSString *)aPhotoId
                     timeout:(NSTimeInterval)aTimeout
                       error:(NSError *__autoreleasing *)aError{

    NSString *retval = nil;
    NSDate *startDate = [NSDate date];
    if( _controllerState == WD_Flickr_LoggedInState ){
        [self WD_changeState:WD_Flickr_CreatePhotoset withDescription:@"create photoset"];
        createPhotosetComplete = NO;
        createPhotosetError = NO;
        createPhotosetResult = nil;
        [_flickrAPIRequest callAPIMethodWithPOST:@"flickr.photosets.create"
                           arguments:@{@"primary_photo_id" : aPhotoId, @"title" : aTitle}];

        NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:aTimeout];
        while( !createPhotosetComplete && ([timeoutDate timeIntervalSinceNow] > 0) ){
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, YES);
        }

        if( createPhotosetComplete ){
            if( createPhotosetError ){
                *aError = [NSError errorWithDomain:@"FlickrError"
                                   code:4
                                   userInfo:@{@"reason" : @"Flickr communication error. Try again."}];
            }else{
                retval = createPhotosetResult;
            }
        }else{
            /*timeout*/
            [self autoChangeStateToLoggedIn];
            *aError = [NSError errorWithDomain:@"FlickrError"
                               code:3
                               userInfo:@{@"reason" : @"timeout. try again."}];
        }
    }else{
        *aError = [NSError errorWithDomain:@"FlickrError"
                           code:2
                           userInfo:@{@"reason" : @"Wrong internal state of Flickr controller. Sounds like a bug."}];
    }
    NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:startDate];
    DDLogInfo(@"creating photoset took: %f", duration);

    return retval;
}

- (void)assignPhoto:(NSString *)aPhotoId
         toPhotoset:(NSString *)aPhotoset
            timeout:(NSTimeInterval)aTimeout
              error:(NSError *__autoreleasing *)aError{

    NSDate *startDate = [NSDate date];
    if( _controllerState == WD_Flickr_LoggedInState ){
        [self WD_changeState:WD_Flickr_AssignPhoto withDescription:@"assign photo to a photoset"];
        assignPhotoComplete = NO;
        assignPhotoError = NO;
        [_flickrAPIRequest callAPIMethodWithPOST:@"flickr.photosets.addPhoto"
                           arguments:@{@"photoset_id" : aPhotoset, @"photo_id" : aPhotoId}];

        NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:aTimeout];
        while( !assignPhotoComplete && ([timeoutDate timeIntervalSinceNow] > 0) ){
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, YES);
        }

        if( assignPhotoComplete ){
            if( assignPhotoError ){
                *aError = [NSError errorWithDomain:@"FlickrError"
                                   code:4
                                   userInfo:@{@"reason" : @"Flickr communication error. Try again."}];
            }else{
                DDLogInfo(@"photo assigned successfully");
            }
        }else{
            /*timeout*/
            [self autoChangeStateToLoggedIn];
            *aError = [NSError errorWithDomain:@"FlickrError"
                               code:3
                               userInfo:@{@"reason" : @"timeout. try again."}];
        }
    }else{
        *aError = [NSError errorWithDomain:@"FlickrError"
                           code:2
                           userInfo:@{@"reason" : @"Wrong internal state of Flickr controller. Sounds like a bug."}];
    }
    NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:startDate];
    DDLogInfo(@"assigning photo took: %f", duration);
}

- (NSString *)checkIfPhotosetExists:(NSString *)aPhotosetName
                            timeout:(NSTimeInterval)aTimeout
                              error:(NSError *__autoreleasing *)aError{

    __block NSString *retval;
    NSError *error;
    NSArray *availablePhotosets = [self availablePhotosetsSync:aTimeout error:&error];

    if( error ){
        *aError = error;
        retval = nil;
    }else{
        [availablePhotosets enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
            if( [aPhotosetName isEqualToString:obj[@"title"]] ){
                retval = obj[@"id"];
                *stop = YES;
            }
        }];
    }
    return retval;
}

+ (NSImage *)getFlickrBuddyIcon:(NSString *)aUserNsid{

    NSString *buddyUrl = [NSString stringWithFormat:@"%@%@.jpg", WD_Flickr_buddyUrlBase, aUserNsid];
    NSImage *buddy = [[NSImage alloc] initWithContentsOfURL:[NSURL URLWithString:buddyUrl]];
    return buddy;
}

#pragma mark - OFFlickrAPIRequestDelegate

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest
 didCompleteWithResponse:(NSDictionary *)inResponseDictionary{

    DDLogInfo(@"request complete with response");
    switch(_controllerState){
        case WD_Flickr_TestingLoginState:{
            DDLogInfo(@"test response arrived. You are logged in properly");
            [self autoChangeStateToLoggedIn];
            @synchronized(self){
                loginTestResult = YES;
                loginTestResponseArrived = YES;
            }
        }
            break;

        case WD_Flickr_PhotoUploadState:{
            DDLogDebug(@"photo upload completed.");
            if( _delegateHas.photoUploadSucceeded ){
                NSString *photoId = inResponseDictionary[@"photoid"][@"_text"];
                [self WD_callOnMainThreadWithWait:@"call delegate upon upload succees"
                      block:^(WDFlickrController *weakSelf){
                          [_delegate photoUploadSucceeded:weakSelf photoURL:currentImageUpload photoId:photoId];
                      }];
            }
            [self autoChangeStateToLoggedIn];
        }
            break;

        case WD_Flickr_CheckPhotosetExists:{
            NSLog(@"Getting a list of photosets completed");
            id photosets = inResponseDictionary[@"photosets"][@"photoset"];

            photosetsReceivedRaw = [NSMutableArray array];
            for(NSDictionary *photoset in photosets){
                NSString *currAlbumName = photoset[@"title"][@"_text"];
                NSString *currAlbumId = photoset[@"id"];
                [photosetsReceivedRaw addObject:@{@"id" : currAlbumId, @"title" : currAlbumName}];
            }
            photosetCheckComplete = YES;
            photosetCheckError = NO;
            [self autoChangeStateToLoggedIn];
        }
            break;

        case WD_Flickr_CreatePhotoset:{
            DDLogInfo(@"Create photoset completed.");
            createPhotosetResult = inResponseDictionary[@"photoset"][@"id"];
            createPhotosetComplete = YES;
            createPhotosetError = NO;
            [self autoChangeStateToLoggedIn];
        }
            break;
        case WD_Flickr_AssignPhoto:{
            DDLogInfo(@"Assign photo completed.");
            assignPhotoError = NO;
            assignPhotoComplete = YES;
            [self autoChangeStateToLoggedIn];
        }
            break;
        default:
            DDLogWarn(@"unknown flickr request completed. WTF?!");
            break;
    }
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest didFailWithError:(NSError *)inError{

    DDLogInfo(@"request failed with error. Error:%@", inError);
    switch(_controllerState){
        case WD_Flickr_FetchingOauthRequestTokenState:
        case WD_Flickr_UserInBrowserState:
        case WD_Flickr_fetchingOauthAccessTokenState:{
            [inRequest cancel];
            NSString *msg = [NSString stringWithFormat:@"Login error. Reason: %@", inError];
            [self WD_changeState:WD_Flickr_LoginErrorState withDescription:msg];
        }
            break;
        case WD_Flickr_TestingLoginState:{
            @synchronized(self){
                loginTestResult = NO;
                loginTestResponseArrived = YES;
            }
            NSString *msg = [NSString stringWithFormat:@"Login test failed. Reason: %@", inError];
            [self WD_changeState:WD_Flickr_InitState withDescription:msg];
        }
            break;
        case WD_Flickr_PhotoUploadState:{
            DDLogWarn(@"error during image upload");
            if( _delegateHas.photoUploadError ){
                [self WD_callOnMainThreadWithWait:@"upload failed" block:^(WDFlickrController *weakSelf){
                    [_delegate photoUploadError:weakSelf photoURL:currentImageUpload];
                }];
            }
            [self testLogin];
        }
            break;
        case WD_Flickr_CheckPhotosetExists:{
            photosetCheckComplete = YES;
            photosetCheckError = YES;
            [self testLogin];
        }
            break;
        case WD_Flickr_CreatePhotoset:{
            createPhotosetComplete = YES;
            createPhotosetError = YES;
            [self testLogin];
        }
            break;
        case WD_Flickr_AssignPhoto:{
            assignPhotoComplete = YES;
            assignPhotoError = YES;
            [self testLogin];
        }
            break;
        default:
            DDLogWarn(@"unknown flickr error. WTF?!");
            break;
    }
}

- (void)flickrAPIRequest:(OFFlickrAPIRequest *)inRequest
    imageUploadSentBytes:(NSUInteger)inSentBytes
              totalBytes:(NSUInteger)inTotalBytes{

    DDLogInfo(@"image upload progress callback");
    if( _controllerState == WD_Flickr_PhotoUploadState ){
        if( _delegateHas.photoUploadProgress ){
            [self WD_callOnMainThreadWithWait:@"image upload update" block:^(WDFlickrController *weakSelf){
                [_delegate photoUploadProgress:weakSelf
                           photoURL:currentImageUpload
                           progress:@{@"sentBytes" : @(inSentBytes), @"totalBytes" : @(inTotalBytes)}];
            }];
        }
    }
}

/* Used during first part of login */
- (void)  flickrAPIRequest:(OFFlickrAPIRequest *)inRequest
didObtainOAuthRequestToken:(NSString *)inRequestToken
                    secret:(NSString *)inSecret{

    if( _controllerState == WD_Flickr_FetchingOauthRequestTokenState ){
        self.flickrAPIContext.OAuthToken = inRequestToken;
        self.flickrAPIContext.OAuthTokenSecret = inSecret;

        NSURL *url = [self.flickrAPIContext userAuthorizationURLWithRequestToken:inRequestToken
                                            requestedPermission:OFFlickrWritePermission];
        [[NSWorkspace sharedWorkspace] openURL:url];
        DDLogInfo(@"Opened login URL");
        [self WD_changeState:WD_Flickr_UserInBrowserState withDescription:@"now user should log in"];
    }else{
        DDLogWarn(@"request token arrived but wrong state.");
    }
}

/* Used during second part of login */
- (void) flickrAPIRequest:(OFFlickrAPIRequest *)inRequest
didObtainOAuthAccessToken:(NSString *)inAccessToken
                   secret:(NSString *)inSecret
             userFullName:(NSString *)inFullName
                 userName:(NSString *)inUserName
                 userNSID:(NSString *)inNSID{

    if( _controllerState == WD_Flickr_fetchingOauthAccessTokenState ){
        [loginTimer invalidate];
        loginTimer = nil;
        _username = inUserName;
        _nsid = inNSID;
        self.flickrAPIContext.OAuthToken = inAccessToken;
        self.flickrAPIContext.OAuthTokenSecret = inSecret;
        self.flickrAPIRequest.sessionInfo = nil;
        [self changeStateToLoggedIn:_username accessToken:self.flickrAPIContext.OAuthToken secret:self.flickrAPIContext.OAuthTokenSecret nsid:_nsid];
    }else{
        DDLogWarn(@"access token arrived but controller in wrong state");
    }
}

- (void)autoChangeStateToLoggedIn{

    [self changeStateToLoggedIn:_username
          accessToken:self.flickrAPIContext.OAuthToken
          secret:self.flickrAPIContext.OAuthTokenSecret
          nsid:_nsid];
}

- (void)changeStateToLoggedIn:(NSString *)aUsername
                  accessToken:(NSString *)aAccessToken
                       secret:(NSString *)aSecret
                         nsid:(NSString *)aNsid {
    NSDictionary *userInfo = @{
                               @"username" : aUsername,
                               @"accessToken" : aAccessToken,
                               @"secret" : aSecret,
                               @"nsid" : aNsid
                               };
    [self WD_changeState:WD_Flickr_LoggedInState
         withDescription:@"logged in"
            optionalInfo:userInfo];
}

#pragma mark - Helpers

- (void)WD_callOnMainThreadWithWait:(NSString *)aDesc block:(void (^)(WDFlickrController *weakSelf))aBlock{

    DDLogInfo(@"calling on main thread with wait. Reason:%@", aDesc);
    __weak WDFlickrController *weakSelf = self;
    if( [NSThread isMainThread] ){
        aBlock(weakSelf);
    }else{
        dispatch_sync(dispatch_get_main_queue(), ^{
            aBlock(weakSelf);
        });
    }
    DDLogInfo(@"Did call on main thread");
}

- (void)WD_PostNotificationOnMainThread:(NSString *)aNotification userInfo:(NSDictionary *)aUserInfo{

    DDLogDebug(@"FlickrController will post a notification=%@ on main thread.", aNotification);
    __weak WDFlickrController *weakSelf = self;
    if( [NSThread isMainThread] ){
        [[NSNotificationCenter defaultCenter]
                postNotificationName:aNotification object:weakSelf userInfo:aUserInfo];
    }else{
        dispatch_sync(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                    postNotificationName:aNotification object:weakSelf userInfo:aUserInfo];
        });
    }
    DDLogDebug(@"FlickrController did post a notification=%@ on main thread.", aNotification);
}

- (void)WD_changeState:(WDFlickrState)aState withDescription:(NSString *)aDesc{

    [self WD_changeState:aState withDescription:aDesc optionalInfo:nil];
}

- (void)WD_changeState:(WDFlickrState)aState withDescription:(NSString *)aDesc optionalInfo:(NSDictionary *)aInfo{

    WDFlickrState oldState = _controllerState;
    _controllerState = aState;
    [self WD_PostStateChangeNotificationOnMainThread:aState
          fromState:oldState
          optionalInfo:aInfo
          description:aDesc];
}

- (void)WD_PostStateChangeNotificationOnMainThread:(WDFlickrState)aNewState
                                         fromState:(WDFlickrState)aOldState
                                      optionalInfo:(NSDictionary *)aUserInfo
                                       description:(NSString *)aDesc{

    DDLogInfo(@"Changing state from %ld to %ld because:%@", aOldState, aNewState, aDesc);
    NSMutableDictionary *finalUserInfo = [NSMutableDictionary dictionary];
    finalUserInfo[@"oldState"] = @(aOldState);
    finalUserInfo[@"newState"] = @(aNewState);
    finalUserInfo[@"reason"] = aDesc;
    if( aUserInfo ){
        [finalUserInfo addEntriesFromDictionary:aUserInfo];
    }
    [self WD_PostNotificationOnMainThread:WD_Flickr_StateChanged userInfo:finalUserInfo];
}

+ (NSString *)controllerStateToString:(WDFlickrState)aControllerState{

    switch(aControllerState){
        case WD_Flickr_InitState:
            return @"WD_Flickr_InitState";
        case WD_Flickr_FetchingOauthRequestTokenState:
            return @"WD_Flickr_FetchingOauthRequestTokenState";
        case WD_Flickr_UserInBrowserState:
            return @"WD_Flickr_UserInBrowserState";
        case WD_Flickr_fetchingOauthAccessTokenState:
            return @"WD_Flickr_fetchingOauthAccessTokenState";
        case WD_Flickr_LoggedInState:
            return @"WD_Flickr_LoggedInState";
        case WD_Flickr_TestingLoginState:
            return @"WD_Flickr_TestingLoginState";
        case WD_Flickr_LoginTimeoutState:
            return @"WD_Flickr_LoginTimeoutState";
        case WD_Flickr_LoginErrorState:
            return @"WD_Flickr_LoginErrorState";
        case WD_Flickr_PhotoUploadState:
            return @"WD_Flickr_PhotoUploadState";
        case WD_Flickr_CheckPhotosetExists:
            return @"WD_Flickr_CheckPhotosetExists";
        case WD_Flickr_ManualLogin:
            return @"WD_Flickr_ManualLogin";
        case WD_Flickr_CreatePhotoset:
            return @"WD_Flickr_CreatePhotoset";
        case WD_Flickr_AssignPhoto:
            return @"WD_Flickr_AssignPhoto";
        default:
            return @"unknown state";
    }
}

+ (NSString *)mimeTypeForFile:(NSString *)aFilePath{
    
    NSString *filePath = aFilePath;
    CFStringRef fileExtension = (__bridge CFStringRef) [filePath pathExtension];
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, NULL);
    CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType);
    CFRelease(UTI);
    NSString *MIMETypeString = (__bridge_transfer NSString *) MIMEType;
    return MIMETypeString;
}


@end