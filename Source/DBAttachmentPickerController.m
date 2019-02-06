//
//  DBAttachmentPickerController.m
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
#import <MobileCoreServices/UTCoreTypes.h>
#import "DBAttachmentPickerController.h"
#import "DBAttachmentAlertController.h"
#import "DBAttachment.h"
#import "DBAssetPickerController.h"

const DBAttachmentMediaType DBAttachmentMediaTypeMaskAll = DBAttachmentMediaTypeImage | DBAttachmentMediaTypeVideo | DBAttachmentMediaTypeOther;

@interface DBAttachmentPickerController () <UIDocumentMenuDelegate, UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, DBAssetPickerControllerDelegate>

@property (strong, nonatomic) UIViewController *initialViewController;
@property (strong, nonatomic) DBAttachmentAlertController *alertController;

@property (strong, nonatomic) FinishPickingBlock extendedFinishPickingBlock;
@property (strong, nonatomic) CancelBlock extendedCancelBlock;

@property (assign, nonatomic) BOOL ignoreChangeMediaType;

@end

@implementation DBAttachmentPickerController

#pragma mark - Class methods

+ (instancetype)attachmentPickerControllerFinishPickingBlock:(FinishPickingBlock)finishPickingBlock
                                                 cancelBlock:(_Nullable CancelBlock)cancelBlock
{
    DBAttachmentPickerController *controller = [[DBAttachmentPickerController alloc] init];
    controller.mediaType = DBAttachmentMediaTypeMaskAll;
    controller.allowsSelectionFromOtherApps = NO;
    controller.allowsMultipleSelection = NO;
    controller.saveToPhotoLibrary = NO;
    controller.capturedVideoQulity = UIImagePickerControllerQualityTypeMedium;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    controller.extendedFinishPickingBlock = ^void(NSArray<DBAttachment *> * attachmentArray) {
        if (finishPickingBlock) finishPickingBlock(attachmentArray);
        [controller dismissAttachmentPicker];
    };
    controller.extendedCancelBlock = ^void() {
        if (cancelBlock) cancelBlock();
        [controller dismissAttachmentPicker];
    };
#pragma clang diagnostic pop
    
    return controller;
}

+ (instancetype)imagePickerControllerFinishPickingBlock:(FinishImagePickingBlock)finishPickingBlock
                                            cancelBlock:(_Nullable CancelBlock)cancelBlock
{
    void (^finishBlock)(NSArray<DBAttachment *> * _Nonnull attachmentArray) = ^(NSArray<DBAttachment *> * _Nonnull attachmentArray) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            dispatch_group_t loadGroup = dispatch_group_create();
            
            NSMutableDictionary *imageDict = [NSMutableDictionary dictionaryWithCapacity:attachmentArray.count];
            for (DBAttachment *attachment in attachmentArray) {
                dispatch_group_enter(loadGroup);
                [attachment loadOriginalImageWithCompletion:^(UIImage * _Nullable resultImage) {
                    if (resultImage) {
                        [imageDict setObject:resultImage forKey:@([attachment hash])];
                    }
                    dispatch_group_leave(loadGroup);
                }];
            }
            
            dispatch_group_wait(loadGroup, DISPATCH_TIME_FOREVER);
            dispatch_async(dispatch_get_main_queue(), ^{
                NSMutableArray *imageArray = [NSMutableArray arrayWithCapacity:attachmentArray.count];
                for (DBAttachment *attachment in attachmentArray) {
                    UIImage *image = imageDict[@([attachment hash])];
                    if (image) {
                        [imageArray addObject:image];
                    }
                }
                if (finishPickingBlock) {
                    finishPickingBlock([imageArray copy]);
                }
            });
        });
    };
    
    DBAttachmentPickerController *controller = [self attachmentPickerControllerFinishPickingBlock:finishBlock cancelBlock:cancelBlock];
    controller.mediaType = DBAttachmentMediaTypeImage;
    controller.ignoreChangeMediaType = YES;
    controller.saveToPhotoLibrary = NO;
    return controller;
}

+ (instancetype)videoPickerControllerFinishPickingBlock:(FinishVideoPickingBlock)finishPickingBlock
                                            cancelBlock:(_Nullable CancelBlock)cancelBlock
{
    void (^finishBlock)(NSArray<DBAttachment *> * _Nonnull attachmentArray) = ^(NSArray<DBAttachment *> * _Nonnull attachmentArray) {
        NSMutableArray *resourceArray = [NSMutableArray arrayWithCapacity:attachmentArray.count];
        for (DBAttachment *attachment in attachmentArray) {
            id resource = [attachment originalFileResource];
            if (resource) {
                [resourceArray addObject:resource];
            }
        }
        if (finishPickingBlock) {
            finishPickingBlock([resourceArray copy]);
        }
    };
    
    DBAttachmentPickerController *controller = [self attachmentPickerControllerFinishPickingBlock:finishBlock cancelBlock:cancelBlock];
    controller.mediaType = DBAttachmentMediaTypeVideo;
    controller.ignoreChangeMediaType = YES;
    controller.saveToPhotoLibrary = NO;
    return controller;
}

#pragma mark - Lifecycle

- (void)dealloc {
    [self.alertController dismissViewControllerAnimated:YES completion:^{
        NSLog(@"Error: Responder must initialize DBAttachmentPickerController through special method attachmentPickerControllerFinishPickingBlock:cancelBlock:");
    }];
}

#pragma mark - Public

- (void)presentOnViewController:(UIViewController *)initialViewController {
    self.initialViewController = initialViewController;
    __weak typeof(self) weakSelf = self;
    self.alertController = [DBAttachmentAlertController attachmentAlertControllerWithMediaType:[self assetMediaType]
                                                                       allowsMultipleSelection:self.allowsMultipleSelection
                                                                            allowsMediaLibrary:( (self.mediaType & DBAttachmentMediaTypeImage) || (self.mediaType & DBAttachmentMediaTypeVideo) )
                                                                               allowsOtherApps:self.allowsSelectionFromOtherApps
                                                                                 attachHandler:^(NSArray<PHAsset *> *assetArray) {
                                                                                     NSArray<DBAttachment *> *attachmentArray = [weakSelf attachmentArrayFromPHAssetArray:assetArray];
                                                                                     [weakSelf finishPickingWithAttachmentArray:attachmentArray];
                                                                                 } allAlbumsHandler:^(UIAlertAction *action) {
                                                                                     [weakSelf allAlbumsDidSelect];
                                                                                 } takePictureHandler:^(UIAlertAction *action) {
                                                                                     [weakSelf takePictureButtonDidSelect];
                                                                                 } otherAppsHandler:^(UIAlertAction *action) {
                                                                                     [weakSelf otherAppsButtonDidSelect];
                                                                                 } cancelHandler:^(UIAlertAction * _Nonnull action) {
                                                                                     [weakSelf cancelDidSelect];
                                                                                 }];
    
    self.alertController.popoverPresentationController.sourceView = [self popoverPresentationView];
    self.alertController.popoverPresentationController.sourceRect = [self popoverPresentationRect];
    self.alertController.popoverPresentationController.permittedArrowDirections = [self popoverPresentationArrowDirection];
    
    [self.initialViewController presentViewController:self.alertController animated:YES completion:^{
        weakSelf.alertController = nil;
    }];
}

- (void)dismissAttachmentPicker {
    self.extendedFinishPickingBlock = nil;
    self.extendedCancelBlock = nil;
}

#pragma mark Helpers

- (PHAssetMediaType)assetMediaType {
    if ( (self.mediaType & DBAttachmentMediaTypeImage) && !(self.mediaType & DBAttachmentMediaTypeVideo) ) {
        return PHAssetMediaTypeImage;
    } else if ( !(self.mediaType & DBAttachmentMediaTypeImage) && (self.mediaType & DBAttachmentMediaTypeVideo) ) {
        return PHAssetMediaTypeVideo;
    }
    return PHAssetMediaTypeUnknown;
}

- (NSArray<DBAttachment *> *)attachmentArrayFromPHAssetArray:(NSArray<PHAsset *> *)assetArray {
    NSMutableArray *attachmentArray = [NSMutableArray arrayWithCapacity:assetArray.count];
    for (PHAsset *asset in assetArray) {
        DBAttachment *model = [DBAttachment attachmentFromPHAsset:asset];
        [attachmentArray addObject:model];
    }
    return [attachmentArray copy];
}

#pragma mark - Popover presentation options

- (UIView *)popoverPresentationView {
    return ( self.senderView ? self.senderView : self.initialViewController.view );
}

- (CGRect)popoverPresentationRect {
    return ( self.senderView ? self.senderView.bounds : CGRectMake( CGRectGetMidX(self.initialViewController.view.bounds), CGRectGetMidY(self.initialViewController.view.bounds), .0f, .0f) );
}

- (UIPopoverArrowDirection)popoverPresentationArrowDirection {
    return ( self.senderView ? UIPopoverArrowDirectionAny : 0 );
}

#pragma mark - Accessors

- (void)setMediaType:(DBAttachmentMediaType)mediaType {
    if (self.ignoreChangeMediaType)
        return;
    
    _mediaType = mediaType;
}

#pragma mark - Actions

- (void)allAlbumsDidSelect {
    DBAssetPickerController *viewController =[[DBAssetPickerController alloc] init];
    viewController.assetMediaType = [self assetMediaType];
    viewController.assetPickerDelegate = self;
    [self.initialViewController presentViewController:viewController animated:YES completion:nil];
}

- (void)otherAppsButtonDidSelect {
    NSMutableArray *documentMediaTypes = [NSMutableArray arrayWithCapacity:10];
    if (self.mediaType & DBAttachmentMediaTypeImage) {
        [documentMediaTypes addObject:(NSString *)kUTTypeImage];
    }
    if (self.mediaType & DBAttachmentMediaTypeVideo) {
        [documentMediaTypes addObject:(NSString *)kUTTypeVideo];
        [documentMediaTypes addObject:(NSString *)kUTTypeMovie];
    }
    if (self.mediaType & DBAttachmentMediaTypeOther) {
        [documentMediaTypes addObject:(NSString *)kUTTypeItem];
    }
    
    @try {
        UIDocumentMenuViewController *viewController = [[UIDocumentMenuViewController alloc] initWithDocumentTypes:documentMediaTypes inMode:UIDocumentPickerModeImport];
        viewController.delegate = self;
        viewController.modalPresentationStyle = UIModalPresentationFullScreen;
        
        viewController.popoverPresentationController.sourceView = [self popoverPresentationView];
        viewController.popoverPresentationController.sourceRect = [self popoverPresentationRect];
        viewController.popoverPresentationController.permittedArrowDirections = [self popoverPresentationArrowDirection];
        
        [self.initialViewController presentViewController:viewController animated:YES completion:nil];
        
    } @catch (NSException *exception) {
        [self cancelWithAlertErrorText:NSLocalizedString(@"Can't load Document Picker", @"Error text")];
    }
}

- (void)takePictureButtonDidSelect {
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [self cancelWithAlertErrorText:NSLocalizedString(@"Device has no camera", @"Error text")];
        return;
    }
    
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.allowsEditing = NO;
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    
    if ( (self.mediaType & DBAttachmentMediaTypeImage) && !(self.mediaType & DBAttachmentMediaTypeVideo) ) {
        picker.mediaTypes = @[(NSString *)kUTTypeImage];
        picker.cameraCaptureMode = UIImagePickerControllerCameraCaptureModePhoto;
    } else if ( !(self.mediaType & DBAttachmentMediaTypeImage) && (self.mediaType & DBAttachmentMediaTypeVideo) ) {
        picker.mediaTypes = @[(NSString *)kUTTypeMovie, (NSString *)kUTTypeVideo];
        picker.cameraCaptureMode = UIImagePickerControllerCameraCaptureModeVideo;
        picker.videoQuality = self.capturedVideoQulity;
    } else {
        picker.mediaTypes = @[(NSString *)kUTTypeMovie, (NSString *)kUTTypeVideo, (NSString *)kUTTypeImage];
        picker.cameraCaptureMode = UIImagePickerControllerCameraCaptureModePhoto;
    }
    
    [self.initialViewController presentViewController:picker animated:YES completion:nil];
}

#pragma mark

- (void)finishPickingWithAttachmentArray:(NSArray <DBAttachment *> *)attachmentArray {
    self.extendedFinishPickingBlock(attachmentArray);
}

- (void)cancelDidSelect {
    self.extendedCancelBlock();
}

- (void)cancelWithAlertErrorText:(NSString *)errorText {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", @"Common") message:errorText preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *actionCancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"Common") style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:actionCancel];
    [self.initialViewController presentViewController:alertController animated:YES completion:nil];
    self.extendedCancelBlock();
}

#pragma mark - UIDocumentMenuViewControllerDelegate

- (void)documentMenu:(UIDocumentMenuViewController *)documentMenu didPickDocumentPicker:(UIDocumentPickerViewController *)documentPicker {
    documentPicker.delegate = self;
    [self.initialViewController presentViewController:documentPicker animated:YES completion:nil];
}

- (void)documentMenuWasCancelled:(UIDocumentMenuViewController *)documentMenu {
    [self cancelDidSelect];
}

#pragma mark - UIDocumentPickerViewControllerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url {
    DBAttachment *attachment = [DBAttachment attachmentFromDocumentURL:url];
    [self finishPickingWithAttachmentArray:@[attachment]];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    [self cancelDidSelect];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    NSString *mediaType = info[UIImagePickerControllerMediaType];
    NSArray *attachmentArray = @[];
    if ([mediaType isEqualToString:(NSString *)kUTTypeImage]) {
        UIImage *image = info[UIImagePickerControllerOriginalImage];
        DBAttachment *attachment = [DBAttachment attachmentFromCameraImage:image];
        attachmentArray = @[attachment];
        if (self.saveToPhotoLibrary) {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
        }
    } else if ([mediaType isEqualToString:(NSString *)kUTTypeMovie] || [mediaType isEqualToString:(NSString *)kUTTypeVideo]) {
        NSURL *documentURL = info[UIImagePickerControllerMediaURL];
        if (documentURL) {
            DBAttachment *attachment = [DBAttachment attachmentFromDocumentURL:documentURL];
            attachmentArray = @[attachment];
        }
        if (self.saveToPhotoLibrary) {
            UISaveVideoAtPathToSavedPhotosAlbum([documentURL path], nil, nil, nil);
        }
    }
    
    __weak typeof(self) weakSelf = self;
    [picker dismissViewControllerAnimated:YES completion:^{
        [weakSelf finishPickingWithAttachmentArray:attachmentArray];
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    __weak typeof(self) weakSelf = self;
    [picker dismissViewControllerAnimated:YES completion:^{
        [weakSelf cancelDidSelect];
    }];
}

#pragma mark - DBImagePickerControllerDelegate

- (void)DBAssetPickerController:(nonnull DBAssetPickerController *)controller didFinishPickingAssetArray:(nonnull NSArray<PHAsset *> *)assetArray {
    __weak typeof(self) weakSelf = self;
    [controller dismissViewControllerAnimated:YES completion:^{
        NSArray<DBAttachment *> *attachmentArray = [weakSelf attachmentArrayFromPHAssetArray:assetArray];
        [weakSelf finishPickingWithAttachmentArray:attachmentArray];
    }];
}

- (void)DBAssetPickerControllerDidCancel:(nonnull DBAssetPickerController *)controller {
    __weak typeof(self) weakSelf = self;
    [controller dismissViewControllerAnimated:YES completion:^{
        [weakSelf cancelDidSelect];
    }];
}

- (BOOL)DBAssetPickerControllerAllowsMultipleSelection:(DBAssetPickerController *)controller {
    return self.allowsMultipleSelection;
}

@end
