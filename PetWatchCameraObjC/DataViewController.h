//
//  DataViewController.h
//  PetWatchCameraObjC
//
//  Created by UQ Times on 2015/02/03.
//  Copyright (c) 2015年 UQ Times. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface DataViewController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (strong, nonatomic) IBOutlet UILabel *dataLabel;
@property (strong, nonatomic) id dataObject;

@end

