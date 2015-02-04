//
//  OpenCVTest.m
//  PetWatchCameraObjC
//
//  Created by UQ Times on 2015/02/04.
//  Copyright (c) 2015年 UQ Times. All rights reserved.
//

#import "OpenCVTest.h"

#include <opencv2/opencv.hpp>
#import <opencv2/highgui/ios.h>

@implementation OpenCVTest

+ (UIImage *)check {
    UIImage *inImage = [UIImage imageNamed:@"in.png"];
    UIImage *bgImage = [UIImage imageNamed:@"bg.png"];
//    UIImage *bgImage = [UIImage imageNamed:@"new_bg.png"];
    
    cv::Mat inMat, bgMat;
    UIImageToMat(inImage, inMat);
    UIImageToMat(bgImage, bgMat);
    
//    cv::Mat forceGroundMask;
//    cv::BackgroundSubtractorGMG backgroundSubtractor;
//    backgroundSubtractor(inMat, forceGroundMask);
    
    cv::Mat diffMat, grayMat, binaryMat;
    cv::absdiff(inMat, bgMat, diffMat);
    
    cv::cvtColor(diffMat, grayMat, CV_BGR2GRAY);
    cv::threshold(grayMat, binaryMat, 20, 255, cv::THRESH_BINARY);
    
    int whiteCount = cv::countNonZero(binaryMat);
    
    //500 * 281 = 140500
    NSLog(@"%d x %d = %d", binaryMat.cols, binaryMat.rows, binaryMat.cols * binaryMat.rows);
    //17295
    NSLog(@"white:%d", whiteCount);
    //12.309608
    NSLog(@"difference percentage:%f", (((float)whiteCount) / (binaryMat.cols * binaryMat.rows)) * 100);
    return MatToUIImage(binaryMat);
}

@end
