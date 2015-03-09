//
//  ViewController.h
//  PetWatchCameraObjC
//
//  Created by UQ Times on 2/13/15.
//  Copyright (c) 2015 UQ Times. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <DropboxSDK/DropboxSDK.h>

@interface ViewController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate, DBRestClientDelegate>


@end

