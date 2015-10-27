#import <Foundation/Foundation.h>
#import <objectiveflickr/ObjectiveFlickr.h>

#define DDLogInfo NSLog
#define DDLogDebug NSLog
#define DDLogWarn NSLog

@class WDFlickrController;

typedef NS_ENUM (NSUInteger, WDFlickrState){
    WD_Flickr_InitState,
    WD_Flickr_FetchingOauthRequestTokenState,
    WD_Flickr_UserInBrowserState,
    WD_Flickr_fetchingOauthAccessTokenState,
    WD_Flickr_LoggedInState,
    WD_Flickr_TestingLoginState,
    WD_Flickr_LoginTimeoutState,
    WD_Flickr_LoginErrorState,
    WD_Flickr_PhotoUploadState,
    WD_Flickr_CheckPhotosetExists,
    WD_Flickr_ManualLogin,
    WD_Flickr_CreatePhotoset,
    WD_Flickr_AssignPhoto
};

/*events*/
extern NSString *const WD_Flickr_StateChanged;

@protocol WDFlickrControllerDelegate <NSObject>

@optional
- (void)photoUploadError:(WDFlickrController *)aSender photoURL:(NSURL *)aURL;

- (void)photoUploadSucceeded:(WDFlickrController *)aSender photoURL:(NSURL *)aURL photoId:(NSString *)aPhotoId;

- (void)photoUploadProgress:(WDFlickrController *)aSender photoURL:(NSURL *)aURL progress:(id)aProgress;

@end

@interface WDFlickrController : NSObject <OFFlickrAPIRequestDelegate>

@property(readonly) OFFlickrAPIContext *flickrAPIContext;
@property(readonly) OFFlickrAPIRequest *flickrAPIRequest;
@property(readonly) NSString *username;
@property(readonly) NSString *nsid;
@property(readonly) WDFlickrState controllerState;
@property(nonatomic, weak) id <WDFlickrControllerDelegate> delegate;

/*settings*/
@property(nonatomic) NSTimeInterval loginTimeout;
@property(nonatomic, copy) NSString *callbackUrlBase;

- (instancetype)initWithFlickrAPIContext:(OFFlickrAPIContext *)flickrAPIContext
                        flickrAPIRequest:(OFFlickrAPIRequest *)flickrAPIRequest;

+ (instancetype)controllerWithFlickrAPIContext:(OFFlickrAPIContext *)flickrAPIContext
                              flickrAPIRequest:(OFFlickrAPIRequest *)flickrAPIRequest;

+ (NSString *)controllerStateToString:(WDFlickrState)aControllerState;

- (void)logIn;

- (void)logOut;

- (BOOL)testLogin;

- (BOOL)isLoggedIn;

- (BOOL)logInManuallyWithToken:(NSString *)aToken
                    withSecret:(NSString *)aSecret
                      username:(NSString *)aUsername
                          nsid:(NSString *)aNsid;

- (void)resetErrors;

/**
 * Async. Calls back through delegate methods.
 */
- (void)uploadImageWithURL:(NSURL *)aImageUrl
         suggestedFilename:(NSString *)aFilename
             flickrOptions:(NSDictionary *)aOptions;

/*
 * Blocking.
 */
- (NSString *)checkIfPhotosetExists:(NSString *)aPhotosetName
                            timeout:(NSTimeInterval)aTimeout
                              error:(NSError *__autoreleasing *)aError;

/**
 * Blocking
 */
- (NSArray *)availablePhotosetsSync:(NSTimeInterval)aTimeout error:(NSError *__autoreleasing *)aError;

/**
 * Blocking
 */
- (NSString *)createPhotoset:(NSString *)aTitle
              primaryPhotoId:(NSString *)aPhotoId
                     timeout:(NSTimeInterval)aTimeout
                       error:(NSError *__autoreleasing *)aError;

/**
 * Blocking
 */
- (void)assignPhoto:(NSString *)aPhotoId
         toPhotoset:(NSString *)aPhotoset
            timeout:(NSTimeInterval)aTimeout
              error:(NSError *__autoreleasing *)aError;

/**
 * Blocking, no login required
 */
+ (NSImage *)getFlickrBuddyIcon:(NSString *)aUserNsid;

@end