//
//  DBAttachmentPickerController.h
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

#import <UIKit/UIKit.h>
#import "NSBundle+DBLibrary.h"

typedef NS_OPTIONS(NSUInteger, DBAttachmentMediaType) {
    DBAttachmentMediaTypeImage = (1 << 0),
    DBAttachmentMediaTypeVideo = (1 << 1),
    DBAttachmentMediaTypeOther = (1 << 2),
};

UIKIT_EXTERN const DBAttachmentMediaType DBAttachmentMediaTypeMaskAll;

NS_ASSUME_NONNULL_BEGIN

@class DBAttachment;

typedef void (^FinishPickingBlock)(NSArray<DBAttachment *> * attachmentArray);
typedef void (^FinishImagePickingBlock)(NSArray<UIImage *> * imageArray);
typedef void (^FinishVideoPickingBlock)(NSArray* resourceArray);
typedef void (^CancelBlock)();

@interface DBAttachmentPickerController : NSObject

/*!
 @brief Used to provide opportunity to correctly calculate position popover view when app works on iPad. You can specify UIButton, UITableViewCell, etc. instance to which the user touched.
 @attention The parameter must contain only UIView subclass instance or nil
 */
@property (weak, nonatomic) UIView *senderView;

/*!
 @brief Used to determine the types of attachments that can be picked
 @note You can specify one or more than one from following types: <br>
 ● @a DBAttachmentMediaTypePhoto - photo from camera, camera roll or other apps;<br>
 ● @a DBAttachmentMediaTypeVideo - video from camera, camera roll or other apps;<br>
 ● @a DBAttachmentMediaTypeOther - any files from other apps.<br>
 Also you can use @a DBAttachmentMediaTypeMaskAll to select all available types.
 */
@property (assign, nonatomic) DBAttachmentMediaType mediaType;                          // default is DBAttachmentMediaTypeMaskAll

/*!
 @brief Used to determine the quality of the captured video from camera
 */
@property (assign, nonatomic) UIImagePickerControllerQualityType capturedVideoQulity;   // default is UIImagePickerControllerQualityTypeMedium

/*!
 @brief Used to add Other Apps button
 @attention To correctly work this option you must select iCloud Documents capability on project settings.
 To view detail information, see README.md.
 */
@property (assign, nonatomic) BOOL allowsSelectionFromOtherApps;                        // default is NO

/*!
 @brief Used to allow multiple selection where it possible
 */
@property (assign, nonatomic) BOOL allowsMultipleSelection;                             // default is NO

/*!
 @brief Used to save photos or videos taken with the camera to camera roll
 */
@property (assign, nonatomic) BOOL saveToPhotoLibrary;                                  // default is NO

/*!
 @brief Creates and returns an attachment picker controller
 @see presentOnViewController:
 @param finishPickingBlock The block will be performed when user select attachment(s)
 @param cancelBlock The block will be performed when user select cancel button
 @return An instance attachment picker controller
 */
+ (instancetype)attachmentPickerControllerFinishPickingBlock:(FinishPickingBlock)finishPickingBlock
                                                 cancelBlock:(_Nullable CancelBlock)cancelBlock;

/*!
 @brief Creates and returns an attachment picker controller with constant media type (image)
 @see presentOnViewController:
 @param finishPickingBlock The block will be performed when user select image(s)
 @param cancelBlock The block will be performed when user select cancel button
 @return An instance attachment picker controller
 */
+ (instancetype)imagePickerControllerFinishPickingBlock:(FinishImagePickingBlock)finishPickingBlock
                                            cancelBlock:(_Nullable CancelBlock)cancelBlock;

/*!
 @brief Creates and returns an attachment picker controller with constant media type (video)
 @see presentOnViewController:
 @param finishPickingBlock The block will be performed when user select video(s)
 @param cancelBlock The block will be performed when user select cancel button
 @return An instance attachment picker controller
 */
+ (instancetype)videoPickerControllerFinishPickingBlock:(FinishVideoPickingBlock)finishPickingBlock
                                            cancelBlock:(_Nullable CancelBlock)cancelBlock;

/*!
 @brief Present attachment picker controller on specify UIViewController
 @param initialViewController The view controller to present the attachment picker controller
 */
- (void)presentOnViewController:(UIViewController *)initialViewController;

@end

NS_ASSUME_NONNULL_END
