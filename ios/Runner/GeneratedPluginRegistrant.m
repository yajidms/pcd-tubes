//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<camera_avfoundation/CameraPlugin.h>)
#import <camera_avfoundation/CameraPlugin.h>
#else
@import camera_avfoundation;
#endif

#if __has_include(<flutter_litert/FlutterLitertPlugin.h>)
#import <flutter_litert/FlutterLitertPlugin.h>
#else
@import flutter_litert;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [CameraPlugin registerWithRegistrar:[registry registrarForPlugin:@"CameraPlugin"]];
  [FlutterLitertPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterLitertPlugin"]];
}

@end
