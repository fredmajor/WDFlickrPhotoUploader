//
//  WDFlickrFactory.m
//  Pods
//
//  Created by Fred on 14/10/15.
//
//

#import "WDFlickrFactory.h"
#import <objectiveflickr/ObjectiveFlickr.h>
#import "WDFlickrController.h"
#import "WDFlickrPhotoUploader.h"
#import "SMStateMachineAsync.h"
#import "SMMonitorNSLog.h"

@implementation WDFlickrFactory
static NSString *apiKey;
static NSString *apiSecret;
static NSString *callbackUrlBase;
static NSTimeInterval requestTimeout;
static NSTimeInterval loginTimeout;

#pragma mark - Settings
#pragma mark Mandatory
+ (NSString *)apiKey {
    @synchronized(self) {
        NSAssert(apiKey, @"needed to log in");
        return apiKey;
    }
}

+ (void)setApiKey:(NSString *)aApiKey {
    @synchronized(self) {
        apiKey = aApiKey;
    }
}

+ (NSString *)apiSecret {
    @synchronized(self) {
        NSAssert(apiSecret, @"needed to log in");
        return apiSecret;
    }
}

+ (void)setApiSecret:(NSString *)aApiSecret {
    @synchronized(self) {
        apiSecret = aApiSecret;
    }
}

+ (NSString *)callbackUrlBase {
    @synchronized(self) {
        NSAssert(callbackUrlBase, @"Needed to log in");
        return callbackUrlBase;
    }
}

+ (void)setCallbackUrlBase:(NSString *)aUrlBase {
    @synchronized(self) {
        callbackUrlBase = aUrlBase;
    }
}

#pragma mark Optional
+ (NSTimeInterval)requestTimeout {
    @synchronized(self) {
        if (requestTimeout) {
            return requestTimeout;
        } else {
            return WD_Flickr_defaultRequestTimeout;
        }
    }
}

+ (void)setRequestTimeout:(NSTimeInterval)aRequestTimeout {
    @synchronized(self) {
        requestTimeout = aRequestTimeout;
    }
}

+ (NSTimeInterval)loginTimeout {
    @synchronized(self) {
        if (loginTimeout) {
            return loginTimeout;
        } else {
            return WD_Flickr_defaultLoginTimeout;
        }
    }
}

+ (void)setLoginTimeout:(NSTimeInterval)aLoginTimeout {
    @synchronized(self) {
        loginTimeout = aLoginTimeout;
    }
}

#pragma mark - factory methods
+ (WDFlickrController *)getFlickrControllerInstance {
    static dispatch_once_t fOnce;
    static WDFlickrController *fController;
    dispatch_once(&fOnce, ^{
        OFFlickrAPIContext *flickrAPIContext = [[OFFlickrAPIContext alloc]
                                                initWithAPIKey:self.apiKey sharedSecret:self.apiSecret];
        OFFlickrAPIRequest *flickrAPIRequest = [[OFFlickrAPIRequest alloc]
                                                initWithAPIContext:flickrAPIContext];
        flickrAPIRequest.requestTimeoutInterval = self.requestTimeout;
        fController = [WDFlickrController controllerWithFlickrAPIContext:flickrAPIContext
                                                        flickrAPIRequest:flickrAPIRequest];
        fController.loginTimeout = self.loginTimeout;
        fController.callbackUrlBase = self.callbackUrlBase;
    });
    return fController;
}

+ (WDFlickrPhotoUploader *)getFlickrUploaderInstance {
    static WDFlickrPhotoUploader *flickrUploader;
    static dispatch_once_t fUploaderOnce;
    dispatch_once(&fUploaderOnce, ^{
        SMStateMachineAsync *sm = [[SMStateMachineAsync alloc] init];
        SMMonitorNSLog *machineMonitor = [[SMMonitorNSLog alloc] initWithSmName:@"Flickr monitor"];
        sm.monitor = machineMonitor;
        WDFlickrController *fController = [self getFlickrControllerInstance];
        flickrUploader = [WDFlickrPhotoUploader uploaderWithFlickrController:fController stateMachine:sm];
    });
    return flickrUploader;
}

@end
