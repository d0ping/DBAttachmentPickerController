//
//  DBAttachmentAlertController.m
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
#import "DBAttachmentAlertController.h"
#import "DBAttachmentPickerController.h"
#import "DBThumbnailPhotoCell.h"
#import "NSIndexSet+DBLibrary.h"

static const CGFloat kDefaultThumbnailHeight = 100.f;
static const CGFloat kDefaultItemOffset = 11.f;
static const CGFloat kDefaultInteritemSpacing = 4.f;
static NSString *const kPhotoCellIdentifier = @"DBThumbnailPhotoCellID";

@interface DBAttachmentAlertController () <UICollectionViewDataSource, UICollectionViewDelegate, PHPhotoLibraryChangeObserver>

@property (assign, nonatomic) BOOL showCollectionView;
@property (strong, nonatomic) UICollectionView *collectionView;
@property (copy, nonatomic) NSString *attachActionText;

@property (strong, nonatomic) PHFetchResult *assetsFetchResult;
@property (strong, nonatomic) PHCachingImageManager *imageManager;

@property (assign, nonatomic) PHAssetMediaType assetMediaType;
@property (assign, nonatomic) BOOL needsDisplayEmptySelectedIndicator;
@property (assign, nonatomic) BOOL allowsMultipleSelection;
@property (strong, nonatomic) NSMutableArray *selectedIndexPathArray;

@property (strong, nonatomic) AlertAttachAssetsHandler extensionAttachHandler;

@end

@implementation DBAttachmentAlertController

#pragma mark - Class methods

+ (_Nonnull instancetype)attachmentAlertControllerWithMediaType:(PHAssetMediaType)assetMediaType
                                        allowsMultipleSelection:(BOOL)allowsMultipleSelection
                                             allowsMediaLibrary:(BOOL)allowsPhotoOrVideo
                                                allowsOtherApps:(BOOL)allowsOtherApps
                                                  attachHandler:(nullable AlertAttachAssetsHandler)attachHandler
                                               allAlbumsHandler:(nullable AlertActionHandler)allAlbumsHandler
                                             takePictureHandler:(nullable AlertActionHandler)takePictureHandler
                                               otherAppsHandler:(nullable AlertActionHandler)otherAppsHandler
                                                  cancelHandler:(nullable AlertActionHandler)cancelHandler
{
    const BOOL showPhotoOrVideo = allowsPhotoOrVideo;
    
    DBAttachmentAlertController *controller = [DBAttachmentAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    controller.assetMediaType = assetMediaType;
    controller.allowsMultipleSelection = allowsMultipleSelection;
    controller.showCollectionView = ( showPhotoOrVideo && controller.assetsFetchResult.count );
    controller.title = ( controller.showCollectionView ? @"\n\n\n\n\n" : NSLocalizedString(@"Attach files", @"Title") );
    
    if ( showPhotoOrVideo && controller.assetsFetchResult.count ) {
        __weak DBAttachmentAlertController *weakController = controller;
        UIAlertAction *attachAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"All albums", @"Button on main menu") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if ([weakController.collectionView indexPathsForSelectedItems].count) {
                if (attachHandler) {
                    attachHandler([weakController getSelectedAssetArray]);
                }
            } else if (allAlbumsHandler) {
                allAlbumsHandler(action);
            }
        }];
        [controller addAction:attachAction];
        controller.attachActionText = attachAction.title;
        
        controller.extensionAttachHandler = ^(NSArray * _Nonnull assetArray) {
            if (attachHandler) {
                attachHandler(assetArray);
            }
            [weakController dismissViewControllerAnimated:YES completion:nil];
        };
    }
    
    if ( showPhotoOrVideo ) {
        NSString *buttonTitle;
        switch (controller.assetMediaType) {
            case PHAssetMediaTypeVideo:
                buttonTitle = NSLocalizedString(@"Take a video", @"Button on main menu");
                break;
            case PHAssetMediaTypeImage:
                buttonTitle = NSLocalizedString(@"Take a picture", @"Button on main menu");
                break;
            default:
                buttonTitle = NSLocalizedString(@"Take a picture or a video", @"Button on main menu");
                break;
        }
        UIAlertAction *cameraAction = [UIAlertAction actionWithTitle:buttonTitle style:UIAlertActionStyleDefault handler:takePictureHandler];
        [controller addAction:cameraAction];
    }
    
    if (allowsOtherApps) {
        UIAlertAction *otherAppsAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Other apps", @"Button on main menu") style:UIAlertActionStyleDefault handler:otherAppsHandler];
        [controller addAction:otherAppsAction];
    }
    
    UIAlertAction *actionCancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Common") style:UIAlertActionStyleCancel handler:cancelHandler];
    [controller addAction:actionCancel];
    
    return controller;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.selectedIndexPathArray = [NSMutableArray arrayWithCapacity:100];
    
    if (self.showCollectionView) {
        UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc]init];
        [flowLayout setScrollDirection:UICollectionViewScrollDirectionHorizontal];
        flowLayout.sectionInset = UIEdgeInsetsMake(.0f, kDefaultItemOffset, .0f, kDefaultItemOffset);
        flowLayout.minimumInteritemSpacing = kDefaultInteritemSpacing;
        
        CGRect collectionRect = CGRectMake(.0f, .0f, self.view.bounds.size.width, kDefaultThumbnailHeight + kDefaultItemOffset *2);
        self.collectionView = [[UICollectionView alloc] initWithFrame:collectionRect collectionViewLayout:flowLayout];
        self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.collectionView.backgroundColor = [UIColor clearColor];
        self.collectionView.allowsMultipleSelection = YES;
        self.collectionView.delegate = self;
        self.collectionView.dataSource = self;
        self.collectionView.tintColor = [[[UIApplication sharedApplication] delegate] window].tintColor;
        
        [self.collectionView registerNib:[UINib nibWithNibName:NSStringFromClass([DBThumbnailPhotoCell class]) bundle:[NSBundle dbAttachmentPickerBundle]] forCellWithReuseIdentifier:kPhotoCellIdentifier];
        
        [self.view addSubview:self.collectionView];
        
        self.imageManager = [[PHCachingImageManager alloc] init];
        [self.imageManager stopCachingImagesForAllAssets];
        
        [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self recalculateVisibleCellsSelectorOffsetWithScrollViewOffsetX:self.collectionView.contentOffset.x];
}

- (void)dealloc {
    if (self.showCollectionView) {
        [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
    }
}

#pragma mark Helpers

- (PHFetchResult *)assetsFetchResult {
    if (_assetsFetchResult == nil) {
        PHFetchOptions *allPhotosOptions = [PHFetchOptions new];
        allPhotosOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
        allPhotosOptions.fetchLimit = 50;
        
        if (self.assetMediaType == PHAssetMediaTypeImage || self.assetMediaType == PHAssetMediaTypeVideo) {
            allPhotosOptions.predicate = [NSPredicate predicateWithFormat:@"mediaType == %ld", self.assetMediaType];
            _assetsFetchResult = [PHAsset fetchAssetsWithMediaType:self.assetMediaType options:allPhotosOptions];
        } else {
            _assetsFetchResult = [PHAsset fetchAssetsWithOptions:allPhotosOptions];
        }
    }
    return _assetsFetchResult;
}

- (NSArray *)getSelectedAssetArray {
    NSArray *selectedItems = self.selectedIndexPathArray;
    NSMutableArray *assetArray = [NSMutableArray arrayWithCapacity:selectedItems.count];
    for (NSIndexPath *indexPath in selectedItems) {
        PHAsset *asset = self.assetsFetchResult[indexPath.item];
        [assetArray addObject:asset];
    }
    return [assetArray copy];
}

#pragma mark - Accessors

- (void)setNeedsDisplayEmptySelectedIndicator:(BOOL)needsDisplayEmptySelectedIndicator {
    if (_needsDisplayEmptySelectedIndicator != needsDisplayEmptySelectedIndicator) {
        _needsDisplayEmptySelectedIndicator = needsDisplayEmptySelectedIndicator;
        
        for (DBThumbnailPhotoCell *cell in self.collectionView.visibleCells) {
            cell.needsDisplayEmptySelectedIndicator = needsDisplayEmptySelectedIndicator;
        }
    }
}

- (void)setAttachActionText:(NSString *)attachActionText {
    if (![_attachActionText isEqualToString:attachActionText]) {
        if (self.isViewLoaded) {
            UILabel *attachLabel = [self attachActionLabelForView:self.view];
            attachLabel.text = [attachActionText copy];
        }
        
        _attachActionText = attachActionText;
    }
}

#pragma mark Helpers

- (UILabel *)attachActionLabelForView:(UIView *)baseView {
    UILabel *label = nil;
    if ([baseView isKindOfClass:[UILabel class]] && [((UILabel *)baseView).text isEqualToString:self.attachActionText]) {
        label = (UILabel *)baseView;
    } else if (baseView.subviews.count > 0) {
        for (UIView *subview in baseView.subviews) {
            label = [self attachActionLabelForView:subview];
            if (label) break;
        }
    }
    return label;
}

#pragma mark - PHPhotoLibraryChangeObserver

- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    dispatch_async(dispatch_get_main_queue(), ^{
        PHFetchResultChangeDetails *collectionChanges = [changeInstance changeDetailsForFetchResult:self.assetsFetchResult];
        
        if (collectionChanges) {
            self.assetsFetchResult = [collectionChanges fetchResultAfterChanges];
            
            if (![collectionChanges hasIncrementalChanges] || [collectionChanges hasMoves]) {
                [self.collectionView reloadData];
            } else {
                [self.collectionView performBatchUpdates:^{
                    NSIndexSet *removedIndexes = [collectionChanges removedIndexes];
                    if ([removedIndexes count]) {
                        [self.collectionView deleteItemsAtIndexPaths:[removedIndexes indexPathsFromIndexesWithSection:0]];
                    }
                    
                    NSIndexSet *insertedIndexes = [collectionChanges insertedIndexes];
                    if ([insertedIndexes count]) {
                        [self.collectionView insertItemsAtIndexPaths:[insertedIndexes indexPathsFromIndexesWithSection:0]];
                    }
                    
                    NSIndexSet *changedIndexes = [collectionChanges changedIndexes];
                    if ([changedIndexes count]) {
                        [self.collectionView reloadItemsAtIndexPaths:[changedIndexes indexPathsFromIndexesWithSection:0]];
                    }
                } completion:nil];
            }
            [self.imageManager stopCachingImagesForAllAssets];
            
            for (NSIndexPath *indexPath in [self.collectionView indexPathsForSelectedItems]) {
                [self.collectionView deselectItemAtIndexPath:indexPath animated:YES];
            }
            [self.selectedIndexPathArray removeAllObjects];
            [self updateAttachPhotoCountIfNedded];
        }
    });
}

#pragma mark - UICollectionView DataSource && Delegate

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.assetsFetchResult.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    DBThumbnailPhotoCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kPhotoCellIdentifier forIndexPath:indexPath];
    if (cell == nil) {
        cell = [DBThumbnailPhotoCell thumbnailImageCell];
    }
    [self configurePhotoCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configurePhotoCell:(DBThumbnailPhotoCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    PHAsset *asset = self.assetsFetchResult[indexPath.item];
    
    cell.tintColor = self.collectionView.tintColor;
    cell.identifier = asset.localIdentifier;
    cell.needsDisplayEmptySelectedIndicator = self.needsDisplayEmptySelectedIndicator;
    [cell.assetImageView configureWithAssetMediaType:asset.mediaType subtype:asset.mediaSubtypes];
    
    if (asset.mediaType == PHAssetMediaTypeVideo) {
        NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
        formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorPad;
        formatter.unitsStyle = NSDateComponentsFormatterUnitsStylePositional;
        formatter.allowedUnits = NSCalendarUnitMinute | NSCalendarUnitSecond;
        cell.durationLabel.text = [formatter stringFromTimeInterval:asset.duration];
    } else {
        cell.durationLabel.text = nil;
    }
    
    CGFloat scale = [UIScreen mainScreen].scale;
    CGSize cellSize = [self collectionItemCellSizeAtIndexPath:indexPath];
    CGSize scaledThumbnailSize = CGSizeMake( cellSize.width * scale, cellSize.height * scale );
    
    [self.imageManager requestImageForAsset:asset
                                 targetSize:scaledThumbnailSize
                                contentMode:PHImageContentModeAspectFill
                                    options:nil
                              resultHandler:^(UIImage *result, NSDictionary *info) {
                                  if ([cell.identifier isEqualToString:asset.localIdentifier]) {
                                      cell.assetImageView.image = result;
                                  }
                              }];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [self.selectedIndexPathArray addObject:indexPath];
    if (self.allowsMultipleSelection) {
        [self updateAttachPhotoCountIfNedded];
        self.needsDisplayEmptySelectedIndicator = YES;
    } else {
        self.extensionAttachHandler([self getSelectedAssetArray]);
    }
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    [self.selectedIndexPathArray removeObject:indexPath];
    [self updateAttachPhotoCountIfNedded];
}

#pragma mark Helpers

- (void)updateAttachPhotoCountIfNedded {
    NSArray *selectedItems = [self.collectionView indexPathsForSelectedItems];
    self.attachActionText = ( selectedItems.count ? [NSString stringWithFormat:NSLocalizedString(@"Attach %zd file(s)", @"Button on main menu"), selectedItems.count] : NSLocalizedString(@"All albums", nil) );
}

#pragma mark UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return [self collectionItemCellSizeAtIndexPath:indexPath];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self recalculateVisibleCellsSelectorOffsetWithScrollViewOffsetX:scrollView.contentOffset.x];
}

#pragma mark Helpers

- (CGSize)collectionItemCellSizeAtIndexPath:(NSIndexPath *)indexPath {
    PHAsset *asset = self.assetsFetchResult[indexPath.item];
    const CGFloat coef = (CGFloat)asset.pixelWidth / (CGFloat)asset.pixelHeight;
    CGFloat maxWidth = CGRectGetWidth(self.collectionView.bounds) - kDefaultInteritemSpacing *2;
    return CGSizeMake( MIN( kDefaultThumbnailHeight * coef, maxWidth ), kDefaultThumbnailHeight );
}

- (void)recalculateVisibleCellsSelectorOffsetWithScrollViewOffsetX:(CGFloat)offsetX {
    for (DBThumbnailPhotoCell *cell in self.collectionView.visibleCells) {
        BOOL isLastItem = ( offsetX + CGRectGetWidth(self.collectionView.frame) < CGRectGetMaxX(cell.frame) );
        cell.selectorOffset = ( isLastItem ? CGRectGetMaxX(cell.frame) - ( offsetX + CGRectGetWidth(self.collectionView.frame) ) : .0f);
    }
}

@end
