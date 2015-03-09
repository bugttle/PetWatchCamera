//
//  OpenCVUtils.h
//  PetWatchCameraObjC
//
//  Created by UQ Times on 2/16/15.
//  Copyright (c) 2015 UQ Times. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OpenCVUtils : NSObject 

+ (UIImage *)toUIImage:(int)height width:(int)width base:(void *)base;
+ (float)check:(UIImage *)inImage bgImage:(UIImage *)bgImage;

@end
