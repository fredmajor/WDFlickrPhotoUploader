Pod::Spec.new do |s|
  s.name             = "WDFlickrPhotoUploader"
  s.version          = "0.1.1"
  s.summary          = "A small library to upload a bunch of files to Flickr."
  s.description      = <<-DESC
This library is a high level abstration for uploading files to Flickr. Implemented using state machines.
                       DESC

  s.homepage         = "https://github.com/fredmajor/WDFlickrPhotoUploader"
  s.license          = 'MIT'
  s.author           = { "Fred" => "major.freddy@yahoo.com" }
  s.source           = { :git => "https://github.com/fredmajor/WDFlickrPhotoUploader.git", :tag => s.version.to_s }
  s.osx.deployment_target = '10.10'
  s.requires_arc = true
  s.source_files = 'Pod/Classes/**/*'
  s.dependency 'objectiveflickr'
end
