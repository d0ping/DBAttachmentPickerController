//
//  DBAssetGroupsViewController.m
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
#import "DBAssetGroupsViewController.h"
#import "DBAssetItemsViewController.h"
#import "DBAssetGroupCell.h"
#import "UIImage+DBAssetIcons.h"
#import "NSBundle+DBLibrary.h"

static const CGSize kDefaultThumbnailSize = {68.f, 68.f};
static NSString *const kAssetGroupsCellIdentifier = @"DBAssetGroupCellID";

@interface DBAssetGroupsViewController ()

@property (nonatomic, copy) NSArray *fetchResults;
@property (nonatomic, copy) NSArray *assetCollections;

@end

@implementation DBAssetGroupsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = NSLocalizedString(@"Albums", nil);
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelButtonDidSelect:)];
    
    [self.tableView registerNib:[UINib nibWithNibName:NSStringFromClass([DBAssetGroupCell class]) bundle:[NSBundle dbAttachmentPickerBundle]] forCellReuseIdentifier:kAssetGroupsCellIdentifier];
    
    PHFetchResult *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAny options:nil];
    PHFetchResult *userAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:nil];
    self.fetchResults = @[smartAlbums, userAlbums];

    [self updateAssetCollections];
}

#pragma mark - Actions

- (void)cancelButtonDidSelect:(UIBarButtonItem *)sender {
    if ([self.assetGroupsDelegate respondsToSelector:@selector(DBAssetGroupsViewControllerDidCancel:)]) {
        [self.assetGroupsDelegate DBAssetGroupsViewControllerDidCancel:self];
    }
}

#pragma mark -

- (void)updateAssetCollections {
    // Filter albums
    NSArray *assetCollectionSubtypes = @[
//                                         @(PHAssetCollectionSubtypeAlbumRegular),
//                                         @(PHAssetCollectionSubtypeAlbumImported),
                                         @(PHAssetCollectionSubtypeSmartAlbumUserLibrary),
                                         @(PHAssetCollectionSubtypeAlbumMyPhotoStream),
                                         @(PHAssetCollectionSubtypeSmartAlbumFavorites),
                                         @(PHAssetCollectionSubtypeSmartAlbumSelfPortraits),
                                         @(PHAssetCollectionSubtypeSmartAlbumPanoramas),
                                         @(PHAssetCollectionSubtypeSmartAlbumVideos),
                                         @(PHAssetCollectionSubtypeSmartAlbumSlomoVideos),
                                         @(PHAssetCollectionSubtypeSmartAlbumTimelapses),
                                         @(PHAssetCollectionSubtypeSmartAlbumBursts),
                                         @(PHAssetCollectionSubtypeSmartAlbumScreenshots),
                                         @(PHAssetCollectionSubtypeAlbumCloudShared)
                                         ];
    NSMutableDictionary *smartAlbums = [NSMutableDictionary dictionaryWithCapacity:assetCollectionSubtypes.count];
    NSMutableArray *userAlbums = [NSMutableArray array];
    
    for (PHFetchResult *fetchResult in self.fetchResults) {
        [fetchResult enumerateObjectsUsingBlock:^(PHAssetCollection *assetCollection, NSUInteger index, BOOL *stop) {
            PHAssetCollectionSubtype subtype = assetCollection.assetCollectionSubtype;
            
            if (subtype == PHAssetCollectionSubtypeAlbumRegular) {
                [userAlbums addObject:assetCollection];
            } else if ([assetCollectionSubtypes containsObject:@(subtype)]) {
                if (!smartAlbums[@(subtype)]) {
                    smartAlbums[@(subtype)] = [NSMutableArray array];
                }
                [smartAlbums[@(subtype)] addObject:assetCollection];
            }
        }];
    }
    
    NSMutableArray *assetCollections = [NSMutableArray array];
    
    // Fetch smart albums
    for (NSNumber *assetCollectionSubtype in assetCollectionSubtypes) {
        NSArray *collections = smartAlbums[assetCollectionSubtype];
        for (PHAssetCollection *assetCollection in collections) {

            PHFetchOptions *options = [PHFetchOptions new];
            if (self.assetMediaType == PHAssetMediaTypeVideo || self.assetMediaType == PHAssetMediaTypeImage) {
                options.predicate = [NSPredicate predicateWithFormat:@"mediaType == %ld", self.assetMediaType];
            }
            PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection:assetCollection options:options];

            if (fetchResult.count) {
                [assetCollections addObject:assetCollection];
            }
        }
    }
    
    // Fetch user albums
    [assetCollections addObjectsFromArray:userAlbums];
    
    self.assetCollections = assetCollections;
}

#pragma mark - PHPhotoLibraryChangeObserver

- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Update fetch results
        NSMutableArray *fetchResults = [self.fetchResults mutableCopy];
        
        [self.fetchResults enumerateObjectsUsingBlock:^(PHFetchResult *fetchResult, NSUInteger index, BOOL *stop) {
            PHFetchResultChangeDetails *changeDetails = [changeInstance changeDetailsForFetchResult:fetchResult];
            
            if (changeDetails) {
                [fetchResults replaceObjectAtIndex:index withObject:changeDetails.fetchResultAfterChanges];
            }
        }];
        
        if (![self.fetchResults isEqualToArray:fetchResults]) {
            self.fetchResults = fetchResults;
            
            // Reload albums
            [self updateAssetCollections];
            [self.tableView reloadData];
        }
    });
}

#pragma mark - UITableView DataSource && Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.assetCollections.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DBAssetGroupCell *cell = [tableView dequeueReusableCellWithIdentifier:kAssetGroupsCellIdentifier];
    if (cell == nil) {
        cell = [[DBAssetGroupCell alloc] init];
    }
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(DBAssetGroupCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    PHAssetCollection *assetCollection = self.assetCollections[indexPath.row];
    
    PHFetchOptions *options = [PHFetchOptions new];
    if (self.assetMediaType == PHAssetMediaTypeVideo || self.assetMediaType == PHAssetMediaTypeImage) {
        options.predicate = [NSPredicate predicateWithFormat:@"mediaType == %ld", self.assetMediaType];
    }
    PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection:assetCollection options:options];
    
    cell.titleLabel.text = assetCollection.localizedTitle;
    cell.countLabel.text = [NSString stringWithFormat:@"%lu", (long)fetchResult.count];
    [cell.imageViewFront configureCollectionSubtype:assetCollection.assetCollectionSubtype];
    
    [self configureImageViewForCell:cell atIndexPath:indexPath fetchResult:fetchResult];
}

- (void)configureImageViewForCell:(DBAssetGroupCell *)cell atIndexPath:(NSIndexPath *)indexPath fetchResult:(PHFetchResult *)fetchResult {
    cell.tag = indexPath.row;
    cell.imageViewBack.hidden = (fetchResult.count >= 1 && fetchResult.count <=2);
    cell.imageViewMid.hidden = (fetchResult.count == 1);
    
    PHImageManager *imageManager = [PHImageManager defaultManager];
    CGFloat scale = [UIScreen mainScreen].scale;
    CGSize size = CGSizeMake( kDefaultThumbnailSize.width * scale, kDefaultThumbnailSize.height * scale );
    PHImageContentMode contentMode = PHImageContentModeAspectFill;
    
    if (fetchResult.count >= 3) {
        [imageManager requestImageForAsset:fetchResult[fetchResult.count - 3] targetSize:size contentMode:contentMode options:nil resultHandler:^(UIImage *result, NSDictionary *info) {
            if (cell.tag == indexPath.row) {
                cell.imageViewBack.image = result;
            }
        }];
    }
    if (fetchResult.count >= 2) {
        [imageManager requestImageForAsset:fetchResult[fetchResult.count - 2] targetSize:size contentMode:contentMode options:nil resultHandler:^(UIImage *result, NSDictionary *info) {
            if (cell.tag == indexPath.row) {
                cell.imageViewMid.image = result;
            }
        }];
    }
    if (fetchResult.count >= 1) {
        [imageManager requestImageForAsset:fetchResult[fetchResult.count - 1] targetSize:size contentMode:contentMode options:nil resultHandler:^(UIImage *result, NSDictionary *info) {
            if (cell.tag == indexPath.row) {
                cell.imageViewFront.image = result;
            }
        }];
    }
    if (fetchResult.count == 0) {
        UIImage *placeholderImage = [UIImage placeholderImageWithSize:cell.imageViewFront.frame.size];
        cell.imageViewFront.image = placeholderImage;
        cell.imageViewMid.image = placeholderImage;
        cell.imageViewBack.image = placeholderImage;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if ([self.assetGroupsDelegate respondsToSelector:@selector(DBAssetGroupsViewController:didSelectAssetColoection:)]) {
        PHAssetCollection *assetCollection = self.assetCollections[indexPath.row];
        [self.assetGroupsDelegate DBAssetGroupsViewController:self didSelectAssetColoection:assetCollection];
    }
}

@end
