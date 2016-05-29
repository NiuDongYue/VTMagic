//
//  VTContentView.m
//  VTMagicView
//
//  Created by tianzhuo on 14/12/29.
//  Copyright (c) 2014年 tianzhuo. All rights reserved.
//

#import "VTContentView.h"
#import "UIViewController+Magic.h"
#import "UIScrollView+Magic.h"

@interface VTContentView()

@property (nonatomic, strong) NSMutableDictionary *visibleDict; // 屏幕上可见的控制器
@property (nonatomic, strong) NSMutableArray *indexList; // 索引集合
@property (nonatomic, strong) NSMutableArray *frameList; // 控制器的坐标集合
@property (nonatomic, strong) NSString *identifier; // 重用标识符
@property (nonatomic, strong) NSCache *pageCache; // 缓存池

@end

@implementation VTContentView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _indexList = [[NSMutableArray alloc] init];
        _frameList = [[NSMutableArray alloc] init];
        _visibleDict = [[NSMutableDictionary alloc] init];
        _pageCache = [[NSCache alloc] init];
        _pageCache.name = @"com.tianzhuo.magic";
        _pageCache.countLimit = 10;
        
#if TARGET_OS_IPHONE
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clearMemoryCache)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
#endif
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (CGRectIsEmpty(self.frame)) return;
    CGFloat offset = self.contentOffset.x;
    CGFloat width = self.frame.size.width;
    BOOL isNotBorder = 0 != (int)offset%(int)width;
    NSInteger currentPage = offset/self.frame.size.width;
    if (_currentIndex == currentPage && isNotBorder) return;
    _currentIndex = currentPage;
    
    CGRect frame = CGRectZero;
    UIViewController *viewController = nil;
    NSArray *pathList = [_visibleDict allKeys];
    for (NSIndexPath *indexPath in pathList) {
        frame = [_frameList[indexPath.row] CGRectValue];
        viewController = _visibleDict[indexPath];
        // 控制器若移出屏幕则将其视图从父类中移除，并添加到缓存池中
        if (![self vtm_isNeedDisplayWithFrame:frame]) {
            [self moveViewControllerToCache:viewController];
            [_visibleDict removeObjectForKey:indexPath];
        } else {
            viewController.view.frame = frame;
        }
    }
    
    NSMutableArray *tempPaths = [_indexList mutableCopy];
    [tempPaths removeObjectsInArray:pathList];
    for (NSIndexPath *indexPath in tempPaths) {
        frame = [_frameList[indexPath.row] CGRectValue];
        if ([self vtm_isNeedDisplayWithFrame:frame]) {
            viewController = [_dataSource contentView:self viewControllerForIndex:indexPath.row];
            if (!viewController) continue;
            viewController.view.frame = frame;
            viewController.reuseIdentifier = _identifier;
            [self addSubview:viewController.view];
            [_visibleDict setObject:viewController forKey:indexPath];
        }
    }
}

#pragma mark - 加载数据
- (void)reloadData
{
    [self resetCacheData];
    [self resetFrames];
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

#pragma mark - 重置缓存信息
-(void)resetCacheData
{
    [_indexList removeAllObjects];
    for (NSInteger i = 0; i < _pageCount; i++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
        [_indexList addObject:indexPath];
    }
    
    // reload时清除所有页面
    NSArray *viewControllers = [_visibleDict allValues];
    for (UIViewController *viewController in viewControllers) {
        [self moveViewControllerToCache:viewController];
    }
    [_visibleDict removeAllObjects];
}

- (void)moveViewControllerToCache:(UIViewController *)viewController
{
    [viewController willMoveToParentViewController:nil];
    [viewController removeFromParentViewController];
    [viewController.view removeFromSuperview];
    
    // 添加到缓存池
    NSMutableSet *cacheSet = [_pageCache objectForKey:viewController.reuseIdentifier];
    if (!cacheSet) cacheSet = [[NSMutableSet alloc] init];
    [cacheSet addObject:viewController];
    [_pageCache setObject:cacheSet forKey:viewController.reuseIdentifier];
}

- (void)resetFrames
{
    [_frameList removeAllObjects];
    CGRect frame = self.bounds;
    for (NSIndexPath *indexPath in _indexList) {
        frame.origin.x = indexPath.row * frame.size.width;
        [_frameList addObject:[NSValue valueWithCGRect:frame]];
    }
    self.contentSize = CGSizeMake(CGRectGetMaxX(frame), 0);
    self.contentOffset = CGPointMake(CGRectGetWidth(frame)*_currentIndex, 0);
}

#pragma mark - accessors
- (NSArray *)visibleList
{
    return [_visibleDict allValues];
}

- (UIViewController *)viewControllerWithIndex:(NSUInteger)index
{
    return [self viewControllerWithIndex:index autoCreateForNil:NO];
}

- (UIViewController *)creatViewControllerWithIndex:(NSUInteger)index
{
    return [self viewControllerWithIndex:index autoCreateForNil:YES];
}

- (UIViewController *)viewControllerWithIndex:(NSUInteger)index autoCreateForNil:(BOOL)autoCreate
{
    if (_pageCount <= index) return nil;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
    UIViewController *viewController = [_visibleDict objectForKey:indexPath];
    if (!viewController && autoCreate) {
        viewController = [_dataSource contentView:self viewControllerForIndex:index];
        viewController.reuseIdentifier = _identifier;
        if (!viewController) return viewController;
        viewController.view.frame = [_frameList[index] CGRectValue];
        [self addSubview:viewController.view];
        [_visibleDict setObject:viewController forKey:indexPath];
    }
    
    return viewController;
}

#pragma mark - 根据缓存标识查询可重用的视图控制器
- (UIViewController *)dequeueReusableViewControllerWithIdentifier:(NSString *)identifier
{
    _identifier = identifier;
    NSMutableSet *cacheSet = [_pageCache objectForKey:identifier];
    UIViewController *viewController = [cacheSet anyObject];
    if (viewController) {
        [cacheSet removeObject:viewController];
        [_pageCache setObject:cacheSet forKey:identifier];
    }
    return viewController;
}

#pragma mark - 清除缓存
- (void)clearMemoryCache
{
    [_pageCache removeAllObjects];
}

@end