//
//  ViewController.m
//  PetWatchCameraObjC
//
//  Created by UQ Times on 2/13/15.
//  Copyright (c) 2015 UQ Times. All rights reserved.
//

#import "ViewController.h"

#import <ImageIO/ImageIO.h>
#import "OpenCVUtils.h"

#define DIFF_PERCENTAGE 20.0f
#define INTERVAL 100

@interface ViewController ()
{
    void *bitmap;
}
@property (nonatomic) CGSize size;
@property (nonatomic) BOOL watching;
@property (nonatomic, strong) UIImage *imageBuffer;
@property (nonatomic, strong) AVCaptureSession *session;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (nonatomic, strong) DBRestClient *restClient;
@property (nonatomic, copy) UIImage *previousImage;
@property (nonatomic) int count;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.count = 0;
    self.watching = NO;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (![[DBSession sharedSession] isLinked]) {
        [self dropboxSignIn];
    } else {
        self.restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        self.restClient.delegate = self;
        NSLog(@"%f", self.view.bounds.size.width);
        NSLog(@"%f", self.view.bounds.size.height);
        //self.size = CGSizeMake(640, 480);
                self.size = self.view.bounds.size;
        //[self initBuffer];
        [self initCamera];
    }
}

- (void)dropboxSignIn {
    if (![[DBSession sharedSession] isLinked]) {
        [[DBSession sharedSession] linkFromController:self];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)initBuffer {
    size_t width = self.size.width;
    size_t height = self.size.height;
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
        
        videoOutput.alwaysDiscardsLateVideoFrames = YES;
        //dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
        dispatch_queue_t queue = dispatch_get_main_queue();
        [videoOutput setSampleBufferDelegate:self queue:queue];
        //dispatch_release(queue);
        
        AVCaptureConnection *videoConnection = NULL;

        // カメラの向きなどを設定する
        [self.session beginConfiguration];
        
        //self.session.sessionPreset = AVCaptureSessionPreset640x480;
//        //self.session.sessionPreset = AVCaptureSessionPresetHigh;
        
        for (AVCaptureConnection *connection in [videoOutput connections]) {
            for ( AVCaptureInputPort *port in [connection inputPorts] ) {
                if ( [[port mediaType] isEqual:AVMediaTypeVideo] ) {
                    videoConnection = connection;
                }
            }
        }
        if([videoConnection isVideoOrientationSupported]) // **Here it is, its always false**
        {
            [videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
        }
        
        [self.session commitConfiguration];

        
        [self.session startRunning];
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    UIImage *image = [self imageFromSampleBufferRef:sampleBuffer];
    self.imageView.image = image;
    
    if (self.watching) {
        ++self.count;
        if (INTERVAL < self.count) {
            self.count = 0;
            
            float diffPercentage = 100;
            if (self.previousImage) {
                diffPercentage = [OpenCVUtils check:image bgImage:self.previousImage];
            }
            self.previousImage = image;
            
            if (DIFF_PERCENTAGE < diffPercentage) {
                NSData *data = UIImageJPEGRepresentation(image, 1.0f);
                CMAttachmentMode attachmentMode;
                CFDictionaryRef metadataRef = CMGetAttachment(sampleBuffer, CFSTR("MetadataDictionay"), &attachmentMode);
                NSMutableDictionary *metadata = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)CFBridgingRelease(metadataRef)];
                [metadata setObject:[NSNumber numberWithInt:UIImageOrientationUp] forKey:(NSString *)kCGImagePropertyOrientation];
                
                NSString *filePath = [self exifExport:data withMetaData:nil];
                [self uploadToDropbox:filePath];
            }
        }
    }
    
    return;
    
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (CVPixelBufferLockBaseAddress(pixelBuffer, 0) == kCVReturnSuccess) {
        memcpy(bitmap, CVPixelBufferGetBaseAddress(pixelBuffer), self.size.width * self.size.height * 4);
        
        CMAttachmentMode attachmentMode;
        CFDictionaryRef metadataRef = CMGetAttachment(sampleBuffer, CFSTR("MetadataDictionay"), &attachmentMode);
        NSMutableDictionary *metadata = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)CFBridgingRelease(metadataRef)];
        
        //[metadata setObject:[NSNumber numberWithInt:UIImageOrientationUp] forKey:(NSString *)kCGImagePropertyOrientation];
        //[metadata setObject:@"Test Message" forKey:(NSString *)kCGImagePropertyExifUserComment];
        
        NSData *jpgData = UIImageJPEGRepresentation(self.imageBuffer, 1.0f);
        
        NSString *filePath = [self exifExport:jpgData withMetaData:metadata];
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        
        [self uploadToDropbox:filePath];
    }
}

- (UIImage *)imageFromSampleBufferRef:(CMSampleBufferRef)sampleBuffer
{
//    // サンプルバッファからピクセルバッファを取り出す
//    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
//    // ピクセルバッファをベースにCoreImageのCIImageオブジェクトを作成
//    CIImage *ciimage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
//    // CIImageからUIImageを作成
//    return [UIImage imageWithCIImage:ciimage];

    // イメージバッファの取得
    CVImageBufferRef buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // イメージバッファのロック
    CVPixelBufferLockBaseAddress(buffer, 0);
    // イメージバッファ情報の取得
    size_t height = CVPixelBufferGetHeight(buffer);
    size_t width = CVPixelBufferGetWidth(buffer);
    void *base = CVPixelBufferGetBaseAddress(buffer);

#if false
    UIImage *image = [OpenCVUtils toUIImage:height width:width base:base];
#else
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
    
    //NSLog(@"width:%ul, height:%ul", width, height);
    
    // ビットマップコンテキストの作成
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef cgContext = CGBitmapContextCreate(base, width, height, 8, bytesPerRow, colorSpace,
                                                   kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // 画像の作成
    CGImageRef cgImage = CGBitmapContextCreateImage(cgContext);
    UIImage *image = [UIImage imageWithCGImage:cgImage
                                         scale:1.0f
                                   orientation:UIImageOrientationUp];
    CGImageRelease(cgImage);
    CGContextRelease(cgContext);
    CGColorSpaceRelease(colorSpace);
#endif
    
    // イメージバッファのアンロック
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    return image;
}

- (NSString *)exifExport:(NSData *)jpgData withMetaData:(NSDictionary *)metaData {
    CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)jpgData, NULL);
    
    NSMutableData *imageData = [NSMutableData data];
    CGImageDestinationRef dest = CGImageDestinationCreateWithData((CFMutableDataRef)imageData, CGImageSourceGetType(source), 1, nil);
    CGImageDestinationAddImageFromSource(dest, source, 0, (CFDictionaryRef)[NSDictionary dictionaryWithObjectsAndKeys:metaData, (NSString *)kCGImagePropertyExifDictionary, nil]);
    CGImageDestinationFinalize(dest);
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *exportImagePath = [NSString stringWithFormat:@"%@/sample.jpg", paths[0]];
    [imageData writeToFile:exportImagePath atomically:YES];
    CFRelease(dest);
    CFRelease(source);
    
    return exportImagePath;
}

- (IBAction)onTapWatchToggle:(UIButton *)sender {
    self.watching = !self.watching;
    NSString *title = self.watching ? @"Watching" : @"Not Watching";
    [sender setTitle:title forState:UIControlStateNormal];
}

- (void)uploadToDropbox:(NSString *)path {
    [self.restClient uploadFile:@"sample.jpg" toPath:@"/" withParentRev:nil fromPath:path];
}

- (void)restClient:(DBRestClient *)client uploadedFile:(NSString *)destPath
              from:(NSString *)srcPath metadata:(DBMetadata *)metadata {
    NSLog(@"File uploaded successfully to path: %@", metadata.path);
}

- (void)restClient:(DBRestClient *)client uploadFileFailedWithError:(NSError *)error {
    NSLog(@"File upload failed with error: %@", error);
}

@end
