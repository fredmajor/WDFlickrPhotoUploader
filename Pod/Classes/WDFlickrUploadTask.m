#import "WDFlickrPhotoUploader.h"

NSString *const WD_FlickrTaskInitState=@"init";
NSString *const WD_FlickrTaskInProgressState=@"inProgress";
NSString *const WD_FlickrTaskFinishedState=@"finished";
NSString *const WD_FlickrTaskErrorState=@"error";

@implementation WDFlickrUploadTask
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.state=WD_FlickrTaskInitState;
    }
    return self;
}

@end