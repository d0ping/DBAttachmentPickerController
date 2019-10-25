//
//  DBAttachment.m
//  DBAttachmentPickerController
//
//  Created by Denis Bogatyrev on 14.03.16.
//
//  The MIT License (MIT)
//  Copyright (c) 2016 Denis Bogatyrev.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

@import Photos;
@import CoreLocation;
#import "DBAttachment.h"
#import "UIImage+DBAssetIcons.h"

@interface DBAttachment ()

@property (strong, nonatomic) NSString *fileName;
@property (assign, nonatomic) NSUInteger fileSize;
@property (strong, nonatomic) NSDate *creationDate;

@property (assign, nonatomic) DBAttachmentSourceType sourceType;
@property (assign, nonatomic) DBAttachmentMediaType mediaType;

@property (strong, nonatomic) PHAsset *photoAsset;
@property (strong, nonatomic) UIImage *image;
@property (strong, nonatomic) UIImage *thumbmailImage;
@property (strong, nonatomic) NSString *originalFilePath;

@property (strong, nonatomic) NSString *restorationIdentifier;

@end

@implementation DBAttachment

+ (instancetype)attachmentFromPHAsset:(PHAsset *)asset {
    DBAttachment *model = [[[self class] alloc] init];
    model.sourceType = DBAttachmentSourceTypePHAsset;
    model.photoAsset = asset;
    
    NSArray *resources = [PHAssetResource assetResourcesForAsset:asset];
    PHAssetResource *resource = [resources firstObject];
    switch (asset.mediaType) {
        case PHAssetMediaTypeImage:
            model.mediaType = DBAttachmentMediaTypeImage;
            break;
        case PHAssetMediaTypeVideo:
            model.mediaType = DBAttachmentMediaTypeVideo;
            break;
        default:
            model.mediaType = DBAttachmentMediaTypeOther;
            break;
    }
    model.fileName = resource.originalFilename;
    model.creationDate = asset.creationDate;
    
    return model;
}

+ (instancetype)attachmentFromCameraImage:(UIImage *)image {
    DBAttachment *model = [[[self class] alloc] init];
    model.sourceType = DBAttachmentSourceTypeImage;
    model.mediaType = DBAttachmentMediaTypeImage;
    model.image = image;
    
    NSData *imgData = UIImageJPEGRepresentation(image, 1);
    model.fileSize = imgData.length;
    model.creationDate = [NSDate date];
    model.fileName = @"capturedimage.jpg";
    
    return model;
}

+ (instancetype)attachmentFromDocumentURL:(NSURL *)url {
    DBAttachment *model = [[[self class] alloc] init];
    model.sourceType = DBAttachmentSourceTypeDocumentURL;
    
    NSString *fileTmpPath = [url path];
    if ( [[NSFileManager defaultManager] fileExistsAtPath:fileTmpPath] ) {
        model.fileName = [fileTmpPath lastPathComponent];
        NSString *cacheFolderPath = [[model cacheFolderPath] stringByAppendingPathComponent:model.restorationIdentifier];
        NSError *error;
        if ( ![[NSFileManager defaultManager] fileExistsAtPath:cacheFolderPath] ) {
            [[NSFileManager defaultManager] createDirectoryAtPath:cacheFolderPath withIntermediateDirectories:YES attributes:nil error:&error];
        }
        
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fileTmpPath error:nil];
        model.creationDate = attributes[NSFileCreationDate];
        model.fileSize = [attributes[NSFileSize] integerValue];
        
        model.originalFilePath = [cacheFolderPath stringByAppendingPathComponent:model.fileName];
        [[NSFileManager defaultManager] copyItemAtPath:fileTmpPath toPath:model.originalFilePath error:&error];
    }
    
    NSString *fileExt = [[[url absoluteString] pathExtension] lowercaseString];
    if ( [fileExt isEqualToString:@"png"] || [fileExt isEqualToString:@"jpeg"] || [fileExt isEqualToString:@"jpg"] || [fileExt isEqualToString:@"gif"] || [fileExt isEqualToString:@"tiff"]) {
        model.mediaType = DBAttachmentMediaTypeImage;
        model.thumbmailImage = [UIImage imageWithContentsOfFile:model.originalFilePath];
    } else if ( [fileExt isEqualToString:@"mov"] || [fileExt isEqualToString:@"avi"]) {
        model.mediaType = DBAttachmentMediaTypeVideo;
        model.thumbmailImage = [model generateThumbnailImageFromURL:url];
    } else {
        model.mediaType = DBAttachmentMediaTypeOther;
        model.thumbmailImage = [UIImage imageOfFileIconWithExtensionText:[fileExt uppercaseString]];
    }
    return model;
}

#pragma mark Helpers

- (NSString *)cacheFolderPath {
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    return [documentsDirectory stringByAppendingPathComponent:@"DBAttachmentPickerControllerCache"];
}

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        self.restorationIdentifier = [NSUUID UUID].UUIDString;
    }
    return self;
}

- (void)dealloc {
    NSString *cacheFolderPath = [[self cacheFolderPath] stringByAppendingPathComponent:self.restorationIdentifier];
    if ( [[NSFileManager defaultManager] fileExistsAtPath:cacheFolderPath] ) {
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:cacheFolderPath error:&error];
    }
}

#pragma mark - Accessors

- (NSString *)fileSizeStr {
    if (self.fileSize == 0) return nil;
    return [NSByteCountFormatter stringFromByteCount:self.fileSize countStyle:NSByteCountFormatterCountStyleFile];
}

#pragma mark -

- (void)loadThumbnailImageWithTargetSize:(CGSize)targetSize completion:(void(^)(UIImage *resultImage))completion {
    switch (self.sourceType) {
        case DBAttachmentSourceTypePHAsset:
            if (completion) {
                [[PHImageManager defaultManager] requestImageForAsset:self.photoAsset
                                                           targetSize:targetSize
                                                          contentMode:PHImageContentModeDefault
                                                              options:nil
                                                        resultHandler:^(UIImage *result, NSDictionary *info) {
                                                            if (![info[PHImageResultIsDegradedKey] boolValue]) {
                                                                completion(result);
                                                            }
                                                        }];
            }
            break;
        case DBAttachmentSourceTypeDocumentURL: {
            if (self.thumbmailImage) {
                completion(self.thumbmailImage);
            } else {
                [self loadOriginalImageWithCompletion:completion];
            }
        }
            break;
        default:
            [self loadOriginalImageWithCompletion:completion];
            break;
    }
}

- (void)loadOriginalImageWithCompletion:(void(^)(UIImage *resultImage))completion {
    switch (self.sourceType) {
        case DBAttachmentSourceTypePHAsset:
            if (completion) {
                PHImageRequestOptions *options = [PHImageRequestOptions new];
                options.synchronous = YES;
                [[PHImageManager defaultManager] requestImageForAsset:self.photoAsset
                                                           targetSize:PHImageManagerMaximumSize
                                                          contentMode:PHImageContentModeDefault
                                                              options:options
                                                        resultHandler:^(UIImage *result, NSDictionary *info) {
                                                            completion(result);
                                                        }];
            }
            break;
        case DBAttachmentSourceTypeImage: {
            if (completion) {
                completion(self.image);
            }
            break;
        }
        case DBAttachmentSourceTypeDocumentURL: {
            if (!self.image) {
                self.image = [UIImage imageWithContentsOfFile:self.originalFilePath];
            }
            if (completion) {
                completion(self.image);
            }
            break;
        }
        default:
            if (completion) {
                completion(nil);
            }
            break;
    }
}

- (id)originalFileResource {
    switch (self.sourceType) {
        case DBAttachmentSourceTypePHAsset:
            return self.photoAsset;
            break;
        case DBAttachmentSourceTypeImage:
            return self.image;
            break;
        case DBAttachmentSourceTypeDocumentURL:
            return self.originalFilePath;
            break;
            
        default:
            return nil;
            break;
    }
}

#pragma mark Helpers

- (UIImage *)generateThumbnailImageFromURL:(NSURL *)url {
    AVAsset *asset = [AVAsset assetWithURL:url];
    AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    imageGenerator.appliesPreferredTrackTransform = YES;
    CMTime time = [asset duration];
    time.value = 0;
    CGImageRef imageRef = [imageGenerator copyCGImageAtTime:time actualTime:NULL error:NULL];
    UIImage *thumbnail = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    return thumbnail;
}

@end
