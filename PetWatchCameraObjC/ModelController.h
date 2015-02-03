//
//  ModelController.h
//  PetWatchCameraObjC
//
//  Created by UQ Times on 2015/02/03.
//  Copyright (c) 2015年 UQ Times. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DataViewController;

@interface ModelController : NSObject <UIPageViewControllerDataSource>

- (DataViewController *)viewControllerAtIndex:(NSUInteger)index storyboard:(UIStoryboard *)storyboard;
- (NSUInteger)indexOfViewController:(DataViewController *)viewController;

@end

