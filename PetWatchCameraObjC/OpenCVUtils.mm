//
//  OpenCVUtils.mm
//  PetWatchCameraObjC
//
//  Created by UQ Times on 2/16/15.
//  Copyright (c) 2015 UQ Times. All rights reserved.
//

#include "OpenCVUtils.h"

#include <opencv2/opencv.hpp>
#import <opencv2/highgui/ios.h>

@implementation OpenCVUtils

+ (UIImage *)toUIImage:(int)height width:(int)width base:(void *)base
{
    cv::Mat mat = cv::Mat(height, width, CV_8UC4, base);
    return MatToUIImage(mat);
}

+ (UIImage *)MatToUIImage:(const cv::Mat &)mat {
    CV_Assert(mat.depth() == CV_8U);
    NSData *data = [NSData dataWithBytes:mat.data length:mat.step*mat.rows];
    CGColorSpaceRef colorSpace = mat.channels() == 1 ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(mat.cols, mat.cols, mat.elemSize1()*8, mat.elemSize()*8,
                                        mat.step[0], colorSpace, kCGImageAlphaNoneSkipLast|kCGBitmapByteOrderDefault,
                                        provider, NULL, false, kCGRenderingIntentDefault);
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    return finalImage;

}
+ (void)UIImageToMat:(const UIImage *)image mat:(cv::Mat &)mat alphaExist:(BOOL)alphaExist
{
//    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
//    if (colorSpace == NULL) {
//        return;
//    }
//    CGFloat cols = image.size.width, rows = image.size.height;
//    CGContextRef contextRef;
//    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedLast;
//    if (CGColorSpaceGetModel(colorSpace) == 0)
//    {
//        m.create(rows, cols, CV_8UC1); // 8 bits per component, 1 channel
//        bitmapInfo = kCGImageAlphaNone;
//        if (!alphaExist)
//            bitmapInfo = kCGImageAlphaNone;
//        contextRef = CGBitmapContextCreate(m.data, m.cols, m.rows, 8,
//                                           m.step[0], colorSpace,
//                                           bitmapInfo);
//    }
//    else
//    {
//        m.create(rows, cols, CV_8UC4); // 8 bits per component, 4 channels
//        if (!alphaExist)
//            bitmapInfo = kCGImageAlphaNoneSkipLast |
//            kCGBitmapByteOrderDefault;
//        contextRef = CGBitmapContextCreate(m.data, m.cols, m.rows, 8,
//                                           m.step[0], colorSpace,
//                                           bitmapInfo);
//    }
//    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows),
//                       image.CGImage);
//    CGContextRelease(contextRef);
//    CGColorSpaceRelease(colorSpace);
//
//    
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    mat.create(rows, cols, CV_8UC4); // 8 bits per component, 4 channels
    CGContextRef contextRef = CGBitmapContextCreate(mat.data, mat.cols, mat.rows, 8,
                                                    mat.step[0], colorSpace, kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault);
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    //CGColorSpaceRelease(colorSpace);
}

+ (float)check:(UIImage *)inImage bgImage:(UIImage *)bgImage {
    //UIImage *inImage = [UIImage imageNamed:@"in.png"];
    //UIImage *bgImage = [UIImage imageNamed:@"bg.png"];
    //    UIImage *bgImage = [UIImage imageNamed:@"new_bg.png"];

    cv::Mat inMat, bgMat;
    [self UIImageToMat:inImage mat:inMat alphaExist:NO];
    [self UIImageToMat:bgImage mat:bgMat alphaExist:NO];


    //    cv::Mat forceGroundMask;
    //    cv::BackgroundSubtractorGMG backgroundSubtractor;
    //    backgroundSubtractor(inMat, forceGroundMask);
    
    cv::Mat diffMat, grayMat, binaryMat;
    cv::absdiff(inMat, bgMat, diffMat);
    
    cv::cvtColor(diffMat, grayMat, CV_BGR2GRAY);
    cv::threshold(grayMat, binaryMat, 20, 255, cv::THRESH_BINARY);
    
    int whiteCount = cv::countNonZero(binaryMat);
    
    //500 * 281 = 140500
//    NSLog(@"%d x %d = %d", binaryMat.cols, binaryMat.rows, binaryMat.cols * binaryMat.rows);
    //17295
    NSLog(@"white:%d", whiteCount);
    //12.309608
    NSLog(@"difference percentage:%f", (((float)whiteCount) / (binaryMat.cols * binaryMat.rows)) * 100);
    //return [self MatToUIImage:binaryMat];
    
    return (((float)whiteCount) / (binaryMat.cols * binaryMat.rows)) * 100;
}

@end
