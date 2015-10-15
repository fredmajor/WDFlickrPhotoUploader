//
//  AppDelegate.m
//  Example_for_WDFlickrPhotoUploader
//
//  Created by Fred on 04/10/15.
//  Copyright © 2015 Fred. All rights reserved.
//

#import "AppDelegate.h"
#import <WDFlickrPhotoUploader/WDFlickrPhotoUploader.h>

@interface AppDelegate ()
@property (weak) IBOutlet NSWindow *window;

- (void)WD_initFlickr;
@end

@implementation AppDelegate {
    WDFlickrPhotoUploader *fPhotoUploader;
    WDFlickrController *fController;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    [self WD_initFlickr];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (void)WD_initFlickr {
    [WDFlickrFactory setApiKey:@""];
    [WDFlickrFactory setApiSecret:@""];
    [WDFlickrFactory setCallbackUrlBase:@"flickrexample://callback"];
    fController    = [WDFlickrFactory getFlickrControllerInstance];
    fPhotoUploader = [WDFlickrFactory getFlickrUploaderInstance];
}

@end
