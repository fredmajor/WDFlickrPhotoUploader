//
//  WDFlickrFactory.h
//  Pods
//
//  Created by Fred on 14/10/15.
//
//

#import <Foundation/Foundation.h>
@class WDFlickrController;
@class WDFlickrPhotoUploader;

static const NSTimeInterval WD_Flickr_defaultRequestTimeout = 60;
static const NSTimeInterval WD_Flickr_defaultLoginTimeout   = 60;

@interface WDFlickrFactory : NSObject

#pragma mark - Settings
#pragma mark Mandatory
+ (NSString *)apiKey;
+ (void)      setApiKey:(NSString *)aApiKey;
+ (NSString *)apiSecret;
+ (void)setApiSecret:(NSString *)aApiSecret;
+ (NSString*)callbackUrlBase;
+ (void)setCallbackUrlBase:(NSString*)aUrlBase;

#pragma mark Optional
+ (NSTimeInterval)requestTimeout;
+ (void)          setRequestTimeout:(NSTimeInterval)aRequestTimeout;
+ (NSTimeInterval)loginTimeout;
+ (void)setLoginTimeout:(NSTimeInterval)aLoginTimeout;

#pragma mark - factory methods
+ (WDFlickrController *)   getFlickrControllerInstance;
+ (WDFlickrPhotoUploader *)getFlickrUploaderInstance;

@end
