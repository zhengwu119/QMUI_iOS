//
//  QMUIToastView.m
//  qmui
//
//  Created by zhoonchen on 2016/12/11.
//  Copyright © 2016年 QMUI Team. All rights reserved.
//

#import "QMUIToastView.h"
#import "QMUICore.h"
#import "QMUIToastAnimator.h"
#import "QMUIToastContentView.h"
#import "QMUIToastBackgroundView.h"
#import "QMUIKeyboardManager.h"
#import "UIView+QMUI.h"

@interface QMUIToastView ()

@property(nonatomic, weak) NSTimer *hideDelayTimer;

@end

@implementation QMUIToastView

#pragma mark - 初始化

- (instancetype)initWithFrame:(CGRect)frame {
    NSAssert(NO, @"请使用initWithView:初始化");
    return [self initWithView:nil];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    NSAssert(NO, @"请使用initWithView:初始化");
    return [self initWithView:nil];
}

- (instancetype)initWithView:(UIView *)view {
    NSAssert(view, @"view不能为空");
    if (self = [super initWithFrame:view.bounds]) {
        _parentView = view;
        [self didInitialize];
    }
    return self;
}

- (void)dealloc {
    [self removeNotifications];
}

- (void)didInitialize {
    
    self.tintColor = UIColorWhite;
    
    self.toastPosition = QMUIToastViewPositionCenter;
    
    // 顺序不能乱，先添加backgroundView再添加contentView
    self.backgroundView = [self defaultBackgrondView];
    self.contentView = [self defaultContentView];
    
    self.opaque = NO;
    self.alpha = 0.0;
    self.backgroundColor = UIColorClear;
    self.layer.allowsGroupOpacity = NO;
    
    _maskView = [[UIView alloc] init];
    self.maskView.backgroundColor = UIColorClear;
    [self addSubview:self.maskView];
    
    [self registerNotifications];
}

- (QMUIToastAnimator *)defaultAnimator {
    QMUIToastAnimator *toastAnimator = [[QMUIToastAnimator alloc] initWithToastView:self];
    return toastAnimator;
}

- (UIView *)defaultBackgrondView {
    QMUIToastBackgroundView *backgroundView = [[QMUIToastBackgroundView alloc] init];
    return backgroundView;
}

- (UIView *)defaultContentView {
    QMUIToastContentView *contentView = [[QMUIToastContentView alloc] init];
    return contentView;
}

- (void)removeFromSuperview {
    [super removeFromSuperview];
    _parentView = nil;
}

- (void)setBackgroundView:(UIView *)backgroundView {
    if (self.backgroundView) {
        [self.backgroundView removeFromSuperview];
        _backgroundView = nil;
    }
    _backgroundView = backgroundView;
    self.backgroundView.alpha = 0.0;
    [self addSubview:self.backgroundView];
    [self setNeedsLayout];
}

- (void)setContentView:(UIView *)contentView {
    if (self.contentView) {
        [self.contentView removeFromSuperview];
        _contentView = nil;
    }
    _contentView = contentView;
    self.contentView.alpha = 0.0;
    [self addSubview:self.contentView];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.frame = self.parentView.bounds;
    self.maskView.frame = self.bounds;
    
    CGFloat contentWidth = CGRectGetWidth(self.parentView.bounds);
    CGFloat contentHeight = CGRectGetHeight(self.parentView.bounds);
    
    UIEdgeInsets marginInsets = UIEdgeInsetsConcat(self.marginInsets, self.parentView.qmui_safeAreaInsets);
    
    CGFloat limitWidth = contentWidth - UIEdgeInsetsGetHorizontalValue(marginInsets);
    CGFloat limitHeight = contentHeight - UIEdgeInsetsGetVerticalValue(marginInsets);
    
    if ([QMUIKeyboardManager isKeyboardVisible]) {
        // 处理键盘相关逻辑，当键盘在显示的时候，内容高度会减去键盘的高度以使 Toast 居中
        CGRect keyboardFrame = [QMUIKeyboardManager currentKeyboardFrame];
        CGRect parentViewRect = [[QMUIKeyboardManager keyboardWindow] convertRect:self.parentView.frame fromView:self.parentView.superview];
        CGRect intersectionRect = CGRectIntersection(keyboardFrame, parentViewRect);
        CGRect overlapRect = CGRectIsValidated(intersectionRect) ? CGRectFlatted(intersectionRect) : CGRectZero;
        contentHeight -= CGRectGetHeight(overlapRect);
    }
    
    if (self.contentView) {
        
        CGSize contentViewSize = [self.contentView sizeThatFits:CGSizeMake(limitWidth, limitHeight)];
        contentViewSize.width = MIN(contentViewSize.width, limitWidth);
        contentViewSize.height = MIN(contentViewSize.height, limitHeight);
        CGFloat contentViewX = MAX(marginInsets.left, (contentWidth - contentViewSize.width) / 2) + self.offset.x;
        CGFloat contentViewY = MAX(marginInsets.top, (contentHeight - contentViewSize.height) / 2) + self.offset.y;
        
        if (self.toastPosition == QMUIToastViewPositionTop) {
            contentViewY = marginInsets.top + self.offset.y;
        } else if (self.toastPosition == QMUIToastViewPositionBottom) {
            contentViewY = contentHeight - contentViewSize.height - marginInsets.bottom + self.offset.y;
        }
        
        CGRect contentRect = CGRectFlatMake(contentViewX, contentViewY, contentViewSize.width, contentViewSize.height);
        self.contentView.frame = CGRectApplyAffineTransform(contentRect, self.contentView.transform);
    }
    if (self.backgroundView) {
        // backgroundView的frame跟contentView一样，contentView里面的subviews如果需要在视觉上跟backgroundView有个padding，那么就自己在自定义的contentView里面做。
        self.backgroundView.frame = self.contentView.frame;
    }
}

#pragma mark - 横竖屏

- (void)registerNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarOrientationDidChange:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
}

- (void)removeNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
}

- (void)statusBarOrientationDidChange:(NSNotification *)notification {
    if (!self.parentView) {
        return;
    }
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

#pragma mark - Show and Hide

- (void)showAnimated:(BOOL)animated {
    
    // show之前需要layout以下，防止同一个tip切换不同的状态导致layout没更新
    [self setNeedsLayout];
    
    [self.hideDelayTimer invalidate];
    self.alpha = 1.0;
    
    if (self.willShowBlock) {
        self.willShowBlock(self.parentView, animated);
    }
    
    if (animated) {
        if (!self.toastAnimator) {
            self.toastAnimator = [self defaultAnimator];
        }
        if (self.toastAnimator) {
            __weak __typeof(self)weakSelf = self;
            [self.toastAnimator showWithCompletion:^(BOOL finished) {
                if (weakSelf.didShowBlock) {
                    weakSelf.didShowBlock(weakSelf.parentView, animated);
                }
            }];
        }
    } else {
        self.backgroundView.alpha = 1.0;
        self.contentView.alpha = 1.0;
        if (self.didShowBlock) {
            self.didShowBlock(self.parentView, animated);
        }
    }
}

- (void)hideAnimated:(BOOL)animated {
    
    if (self.willHideBlock) {
        self.willHideBlock(self.parentView, animated);
    }
    
    if (animated) {
        if (!self.toastAnimator) {
            self.toastAnimator = [self defaultAnimator];
        }
        if (self.toastAnimator) {
            __weak __typeof(self)weakSelf = self;
            [self.toastAnimator hideWithCompletion:^(BOOL finished) {
                [weakSelf didHideWithAnimated:animated];
            }];
        }
    } else {
        self.backgroundView.alpha = 0.0;
        self.contentView.alpha = 0.0;
        [self didHideWithAnimated:animated];
    }
}

- (void)didHideWithAnimated:(BOOL)animated {
    
    if (self.didHideBlock) {
        self.didHideBlock(self.parentView, animated);
    }
    
    [self.hideDelayTimer invalidate];
    self.alpha = 0.0;
    if (self.removeFromSuperViewWhenHide) {
        [self removeFromSuperview];
    }
}

- (void)hideAnimated:(BOOL)animated afterDelay:(NSTimeInterval)delay {
    NSTimer *timer = [NSTimer timerWithTimeInterval:delay target:self selector:@selector(handleHideTimer:) userInfo:@(animated) repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.hideDelayTimer = timer;
}

- (void)handleHideTimer:(NSTimer *)timer {
    [self hideAnimated:[timer.userInfo boolValue]];
}

#pragma mark - UIAppearance

- (void)setOffset:(CGPoint)offset {
    _offset = offset;
    [self setNeedsLayout];
}

- (void)setMarginInsets:(UIEdgeInsets)marginInsets {
    _marginInsets = marginInsets;
    [self setNeedsLayout];
}

@end


@interface QMUIToastView (UIAppearance)

@end

@implementation QMUIToastView (UIAppearance)

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self setDefaultAppearance];
    });
}

+ (void)setDefaultAppearance {
    QMUIToastView *appearance = [QMUIToastView appearance];
    appearance.offset = CGPointZero;
    appearance.marginInsets = UIEdgeInsetsMake(20, 20, 20, 20);
}

@end

@implementation QMUIToastView (ToastTool)

+ (BOOL)hideAllToastInView:(UIView *)view animated:(BOOL)animated {
    NSArray *toastViews = [self allToastInView:view];
    BOOL returnFlag = NO;
    for (QMUIToastView *toastView in toastViews) {
        if (toastView) {
            toastView.removeFromSuperViewWhenHide = YES;
            [toastView hideAnimated:animated];
            returnFlag = YES;
        }
    }
    return returnFlag;
}

+ (instancetype)toastInView:(UIView *)view {
    NSEnumerator *subviewsEnum = [view.subviews reverseObjectEnumerator];
    for (UIView *subview in subviewsEnum) {
        if ([subview isKindOfClass:self]) {
            return (QMUIToastView *)subview;
        }
    }
    return nil;
}

+ (NSArray <QMUIToastView *> *)allToastInView:(UIView *)view {
    NSMutableArray *toastViews = [[NSMutableArray alloc] init];
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:self]) {
            [toastViews addObject:subview];
        }
    }
    return toastViews;
}

@end
