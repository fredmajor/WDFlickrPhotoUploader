#import "WDFlickrPhotoUploader.h"

@implementation WDFlickrUploadTask
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.state=@"init";
    }
    return self;
}

@end