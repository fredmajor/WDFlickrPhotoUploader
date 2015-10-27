//
//  WDDataUtils.m
//  Pods
//
//  Created by Fred on 06/10/15.
//
//

#import "WDDataUtils.h"

@implementation WDDataUtils

#pragma mark - mime

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
