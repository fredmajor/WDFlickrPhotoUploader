# WDFlickrPhotoUploader

[![Version](https://img.shields.io/cocoapods/v/WDFlickrPhotoUploader.svg?style=flat)](http://cocoapods.org/pods/WDFlickrPhotoUploader)
[![License](https://img.shields.io/cocoapods/l/WDFlickrPhotoUploader.svg?style=flat)](http://cocoapods.org/pods/WDFlickrPhotoUploader)
[![Platform](https://img.shields.io/cocoapods/p/WDFlickrPhotoUploader.svg?style=flat)](http://cocoapods.org/pods/WDFlickrPhotoUploader)

This Pod makes it easier for you to:
1. sign in to flickr
2. upload a bunch of photos (or videos) and assign them to albums
3. create an album (called also a photoset)
4. assign an already uploaded file to a photoset
5. check if a photoset exists
6. download flickr's buddy image

This Pod is currently configured to build in OSX however there shouldn't be bigger problems to extend it to support iOS. I simply don't know how to configure the pod project to handle that and currently don't have time to learn that. Pull requests highly appreciated.
The project uses [objectiveflickr](https://github.com/lukhnos/objectiveflickr) and [SimpleStateMachine](https://github.com/est1908/SimpleStateMachine).

## Usage
### Example app

To run the example project, clone the repo, and run `pod install` from the Example directory first.
Then go AppDelegate.m file and replace:
````objective-c
    [WDFlickrFactory setApiKey:@"--YOUR--KEY--"];
    [WDFlickrFactory setApiSecret:@"--YOUR--SECRET--"];
```
dummy strings with flickr credentials of your app. That's necessry to use the Pod since everything except getting buddu image requires to be authenticated and authorized. You can create your flickr app here: [link](https://www.flickr.com/services/apps/create/).
Now you are ready to build an example app and play with it. Sign in (the browser will pop up with flickr's oAuth authentication page), choose some media files to upload, and hit the upload button. Example app prints a lot of debug information which is not needed during regular real-life application usage.
Entire Example app is contained inside the AppDelegate class.
### API
Basic steps to use the pod in your code:
1. Configure the apiKey and apiSecret, as in the example app
2. Your client class needs to implement the WDFlickrPhotoUploaderDataSource protocol. For an example of implementation see the demo app.
3. The uploader will carry on uploading as long as you return WDFlickrUploadTask object from the `- (WDFlickrUploadTask *)nextTask` method. Once you return nil - the Uploader will go to the Finished state.
4. To reply to events from the uploader - implement WDFlickrPhotoUploaderDelegate protocol. The protocol is quite self-explanatory. All methods will be called back on the main thread, so feel free to modify your UI. 
5. To reply to events from WDFlickrController - register for the WD_Flickr_StateChanged notifiction from the controller object. See the `- (void)WD_flickrControllerNotificationHandler:(NSNotification *)aNote` method for what you can get from there.
6. `- (void)WD_initFlickr` method show how to use WDFlickrFactory to configure and create the Controller and the Uploader.
7. There should me only one instance of WDFlickrController and WDFlickrUploader and they should work together. I don't know if underlying libraries I used are fine to run more instances and my code is also not meant to run in parallel. Treat it as a singleton.
8. SMMonitorNSLogDelegate is only a quick, ugly fix to get more debug output from underlying SimpleStateMachine library
9. Have fun!

## Documentation
There are two main classes: WDFlickrController and WDFlickrUploader.
WDFlickrController implements primitive communication with Flickr, such as sign in, upload one picture, create photoset etc.
WDFlickrUploader on the other hand implements the logic of a batch photo upload with assignment of the files to specified photosets. If specified photosets don't exist - they will be created.
Both classes are implemented as state machines. Controller is more primitive, switch-case based, whilst Uploader uses more structured approach and utilizes a [SimpleStateMachine](https://github.com/est1908/SimpleStateMachine) cocoa pod. WDFlickrUploader has a buch of unit tests.
Some methods are synchronous, some asynchronous, depending on what if thought to be a better approach in a given context.
Below attached are state diagrams for both automata. The second one is way more precise and can be a huge help if you need to get some more understanding on the code.
The uploader features simple error handling and it will repeat a couple of times before failing.

Primitive and simplified state diagram for WDFlickrController:
![](http://raw.githubusercontent.com/fredmajor/WDFlickrPhotoUploader/master/docs/WDFlickrControllerFSMGraph.gif)

Pretty nice state diagram for WDFlickrUploader:
![](http://raw.githubusercontent.com/fredmajor/WDFlickrPhotoUploader/master/docs/WDFlickrPhotoUploaderFSMGraph.gif)


## Installation

WDFlickrPhotoUploader is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "WDFlickrPhotoUploader"
```
Don't forget to configure your app's api key and api secret! (obtained from flickr)

## Author

Fred, major [dot] freddy [at] yahoo [dot] com

## License

WDFlickrPhotoUploader is available under the MIT license. See the LICENSE file for more info.
