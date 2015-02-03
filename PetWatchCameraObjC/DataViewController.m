//
//  DataViewController.m
//  PetWatchCameraObjC
//
//  Created by UQ Times on 2015/02/03.
//  Copyright (c) 2015年 UQ Times. All rights reserved.
//

#import "DataViewController.h"
#import <ImageIO/ImageIO.h>

@interface DataViewController ()
{
    BOOL exported;
    void *bitmap;
}
@property (nonatomic, strong) UIImage *imageBuffer;
@property (nonatomic, strong) AVCaptureSession *session;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@end

@implementation DataViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    exported = NO;
    
    [self initBuffer];
    [self initCamera];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.dataLabel.text = [self.dataObject description];
}

- (void)initBuffer {
    size_t width = 640;
    size_t height = 480;
    bitmap = malloc(width * height * 4);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef dataProviderRef = CGDataProviderCreateWithData(NULL, bitmap, width * height * 4, NULL);
    CGImageRef cgImage = CGImageCreate(width, height, 8, 32, width * 4, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst, dataProviderRef, NULL, 0, kCGRenderingIntentDefault);
    self.imageBuffer = [UIImage imageWithCGImage:cgImage];
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(dataProviderRef);
}

- (void)initCamera {
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    NSError *error = nil;
    AVCaptureInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    
    self.session = [[AVCaptureSession alloc] init];
    if ([self.session canAddInput:captureInput]) {
        [self.session addInput:captureInput];
        
        AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        NSDictionary *settings = @{(id)kCVPixelBufferPixelFormatTypeKey:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]};
        videoOutput.videoSettings = settings;
        [self.session addOutput:videoOutput];
        
        //dispatch_queue_t queue = dispatch_queue_create("com.blogspot.uqtimes", NULL);
        [videoOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
        //dispatch_release(queue);
        
        [self.session beginConfiguration];
        self.session.sessionPreset = AVCaptureSessionPreset640x480;
        //self.session.sessionPreset = AVCaptureSessionPresetHigh;
        [self.session commitConfiguration];
        
        [self.session startRunning];
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    self.imageView.image = [self imageFromSampleBufferRef:sampleBuffer];
    
    if (exported) {
        return;
    }
    
    exported = YES;
    
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (CVPixelBufferLockBaseAddress(pixelBuffer, 0) == kCVReturnSuccess) {
        memcpy(bitmap, CVPixelBufferGetBaseAddress(pixelBuffer), 640 * 480 * 4);
        
        CMAttachmentMode attachmentMode;
        CFDictionaryRef metadataRef = CMGetAttachment(sampleBuffer, CFSTR("MetadataDictionay"), &attachmentMode);
        NSMutableDictionary *metadata = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)CFBridgingRelease(metadataRef)];
        
        [metadata setObject:[NSNumber numberWithInt:6] forKey:(NSString *)kCGImagePropertyOrientation];
        
        NSData *jpgData = UIImageJPEGRepresentation(self.imageBuffer, 1.0f);
        
        [self exifExport:jpgData withMetaData:metadata];
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    }
}

- (UIImage *)imageFromSampleBufferRef:(CMSampleBufferRef)sampleBuffer
{
    // イメージバッファの取得
    CVImageBufferRef    buffer;
    buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // イメージバッファのロック
    CVPixelBufferLockBaseAddress(buffer, 0);
    // イメージバッファ情報の取得
    uint8_t*    base;
    size_t      width, height, bytesPerRow;
    base = CVPixelBufferGetBaseAddress(buffer);
    width = CVPixelBufferGetWidth(buffer);
    height = CVPixelBufferGetHeight(buffer);
    bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
    
    // ビットマップコンテキストの作成
    CGColorSpaceRef colorSpace;
    CGContextRef    cgContext;
    colorSpace = CGColorSpaceCreateDeviceRGB();
    cgContext = CGBitmapContextCreate(
                                      base, width, height, 8, bytesPerRow, colorSpace,
                                      kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace);
    
    // 画像の作成
    CGImageRef  cgImage;
    UIImage*    image;
    cgImage = CGBitmapContextCreateImage(cgContext);
    image = [UIImage imageWithCGImage:cgImage scale:1.0f
                          orientation:UIImageOrientationUp];
    CGImageRelease(cgImage);
    CGContextRelease(cgContext);
    
    // イメージバッファのアンロック
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    return image;
}

- (void)exifExport:(NSData *)jpgData withMetaData:(NSDictionary *)metaData {
    CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)jpgData, NULL);
    
    NSMutableData *imageData = [[NSMutableData alloc] init];
    CGImageDestinationRef dest = CGImageDestinationCreateWithData((CFMutableDataRef)imageData, CGImageSourceGetType(source), 1, nil);
    CGImageDestinationAddImageFromSource(dest, source, 0, (CFDictionaryRef)[NSDictionary dictionaryWithObjectsAndKeys:metaData, (NSString *)kCGImagePropertyExifDictionary, nil]);
    CGImageDestinationFinalize(dest);
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *exportImagePath = [NSString stringWithFormat:@"%@/sample.jpg", paths[0]];
    [imageData writeToFile:exportImagePath atomically:YES];
    CFRelease(dest);
}

@end
