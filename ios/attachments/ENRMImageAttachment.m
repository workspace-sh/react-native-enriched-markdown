#import "ENRMImageAttachment.h"
#import "ENRMImageDownloader.h"
#import "ENRMUIKit.h"
#import "RuntimeKeys.h"
#import "StyleConfig.h"
#import <objc/runtime.h>

#define CACHE_KEY_PROCESSED(url, w, h, r) [NSString stringWithFormat:@"%@_w%.1f_h%.1f_r%.1f", url, w, h, r]

static inline NSUInteger ENRMImageByteCost(RCTUIImage *image)
{
  CGImageRef cgImage = image.CGImage;
  if (!cgImage)
    return 0;
  return CGImageGetBytesPerRow(cgImage) * CGImageGetHeight(cgImage);
}

static NSCache<NSString *, RCTUIImage *> *_originalImageCache;
static NSCache<NSString *, RCTUIImage *> *_processedImageCache;
static NSMapTable<NSString *, ENRMImageAttachment *> *_attachmentRegistry;

@interface ENRMImageAttachment ()

@property (nonatomic, copy) NSString *imageURL;
@property (nonatomic, assign) BOOL isInline;
@property (nonatomic, assign) CGFloat cachedHeight;
@property (nonatomic, assign) CGFloat cachedBorderRadius;
@property (nonatomic, assign) CGFloat explicitWidth;
@property (nonatomic, assign) CGFloat explicitHeight;
@property (nonatomic, assign) BOOL responsive;
@property (nonatomic, assign) CGFloat naturalWidth;
@property (nonatomic, assign) CGFloat naturalHeight;
/// Clean URL with __enrm fragment stripped (used for downloading/caching)
@property (nonatomic, copy) NSString *downloadURL;
@property (nonatomic, weak) NSTextContainer *textContainer;
@property (nonatomic, weak) ENRMPlatformTextView *textView;
@property (nonatomic, strong) RCTUIImage *originalImage;
@property (nonatomic, strong) RCTUIImage *loadedImage;
@property (nonatomic, copy) NSString *lastProcessedKey;

@end

@implementation ENRMImageAttachment

+ (NSCache<NSString *, RCTUIImage *> *)originalImageCache
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _originalImageCache = [[NSCache alloc] init];
    _originalImageCache.countLimit = 50;
    _originalImageCache.totalCostLimit = 1024 * 1024 * 20; // 20 MB
  });
  return _originalImageCache;
}

+ (NSCache<NSString *, RCTUIImage *> *)processedImageCache
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _processedImageCache = [[NSCache alloc] init];
    _processedImageCache.countLimit = 100;
    _processedImageCache.totalCostLimit = 1024 * 1024 * 30; // 30 MB
  });
  return _processedImageCache;
}

+ (NSMapTable<NSString *, ENRMImageAttachment *> *)attachmentRegistry
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{ _attachmentRegistry = [NSMapTable strongToWeakObjectsMapTable]; });
  return _attachmentRegistry;
}

+ (instancetype)attachmentForURL:(NSString *)imageURL config:(StyleConfig *)config isInline:(BOOL)isInline
{
  // Use full URL (with fragment) as registry key so different dimensions produce different attachments
  NSString *key = [NSString stringWithFormat:@"%@_%d", imageURL, isInline];
  ENRMImageAttachment *existing = [[self attachmentRegistry] objectForKey:key];
  if (existing && existing.originalImage) {
    return existing;
  }
  ENRMImageAttachment *attachment = [[self alloc] initWithImageURL:imageURL config:config isInline:isInline];
  [[self attachmentRegistry] setObject:attachment forKey:key];
  return attachment;
}

+ (void)clearAttachmentRegistry
{
  [[self attachmentRegistry] removeAllObjects];
}

/**
 * Parse __enrm dimension hints from a URL fragment.
 * Fragment format: #__enrm_w=120&__enrm_h=80
 * Returns the clean URL (fragment stripped) via outCleanURL.
 */
static void parseEnrmFragment(NSString *url, NSString **outCleanURL, CGFloat *outWidth, CGFloat *outHeight)
{
  *outWidth = 0;
  *outHeight = 0;
  *outCleanURL = url;

  NSRange hashRange = [url rangeOfString:@"#__enrm_"];
  if (hashRange.location == NSNotFound)
    return;

  NSString *fragment = [url substringFromIndex:hashRange.location + 1];
  *outCleanURL = [url substringToIndex:hashRange.location];

  for (NSString *param in [fragment componentsSeparatedByString:@"&"]) {
    if ([param hasPrefix:@"__enrm_w="]) {
      *outWidth = [[param substringFromIndex:9] doubleValue];
    } else if ([param hasPrefix:@"__enrm_h="]) {
      *outHeight = [[param substringFromIndex:9] doubleValue];
    }
  }
}

- (instancetype)initWithImageURL:(NSString *)imageURL config:(StyleConfig *)config isInline:(BOOL)isInline
{
  self = [super init];
  if (self) {
    // Parse dimension hints from URL fragment
    NSString *cleanURL;
    CGFloat explicitW, explicitH;
    parseEnrmFragment(imageURL, &cleanURL, &explicitW, &explicitH);

    _imageURL = imageURL;
    _downloadURL = cleanURL;
    _isInline = isInline;
    _explicitWidth = explicitW;
    _explicitHeight = explicitH;
    _responsive = [config imageResponsive];

    if (explicitH > 0) {
      _cachedHeight = explicitH;
    } else if (explicitW > 0) {
      // Use explicit width as initial height (square placeholder) until image loads
      // and we can calculate proper aspect ratio
      _cachedHeight = explicitW;
    } else {
      _cachedHeight = isInline ? [config inlineImageSize] : [config imageHeight];
    }
    _cachedBorderRadius = [config imageBorderRadius];

    [self setupPlaceholder];
    [self startDownloadingImage];
  }
  return self;
}

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer
                      proposedLineFragment:(CGRect)lineFragment
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)characterIndex
{
  CGFloat height = self.cachedHeight;
  CGFloat width;

  if (self.isInline) {
    width = self.explicitWidth > 0 ? self.explicitWidth : height;
  } else if (self.explicitWidth > 0) {
    width = self.explicitWidth;
  } else if (self.naturalWidth > 0) {
    // Natural image dimensions known — use them, clamped to container
    CGFloat containerWidth = lineFragment.size.width > 0 ? lineFragment.size.width : self.naturalWidth;
    if (self.naturalWidth <= containerWidth) {
      // Small image: render at natural size
      width = self.naturalWidth;
      height = self.naturalHeight;
    } else {
      // Large image: clamp to container, preserve aspect ratio
      width = containerWidth;
      height = round(containerWidth * (self.naturalHeight / self.naturalWidth));
    }
  } else {
    width = lineFragment.size.width > 0 ? lineFragment.size.width : height;
  }

  if (self.isInline) {
    UIFont *appliedFont = nil;
    NSLayoutManager *layoutManager = textContainer.layoutManager;
    NSTextStorage *textStorage = layoutManager.textStorage;

    if (textStorage && characterIndex < textStorage.length) {
      appliedFont = [textStorage attribute:NSFontAttributeName atIndex:characterIndex effectiveRange:NULL];
    }

    CGFloat verticalOffset;
    if (appliedFont) {
      verticalOffset = (appliedFont.capHeight - height) / 2.0;
    } else {
      verticalOffset = (lineFragment.size.height - height) / 2.0;
    }

    return CGRectMake(0, verticalOffset, width, height);
  }

  if (!self.isInline) {
    NSLog(@"[ENRM-ATT] bounds called: natW=%.0f natH=%.0f lineW=%.0f -> w=%.0f h=%.0f (selfBounds=%.0fx%.0f)",
          self.naturalWidth, self.naturalHeight, lineFragment.size.width, width, height, self.bounds.size.width,
          self.bounds.size.height);
  }
  return CGRectMake(0, 0, width, height);
}

- (RCTUIImage *)imageForBounds:(CGRect)imageBounds
                 textContainer:(NSTextContainer *)textContainer
                characterIndex:(NSUInteger)characterIndex
{
  self.textContainer = textContainer;

  if (self.originalImage && imageBounds.size.width > 0) {
    // Only set bounds for inline images. Block images must keep bounds at
    // CGRectZero so NSLayoutManager calls attachmentBoundsForTextContainer:
    // on every layout pass (see setupPlaceholder comment).
    if (self.isInline) {
      self.bounds = imageBounds;
    }
    self.cachedHeight = imageBounds.size.height;
    CGFloat targetWidth = self.explicitWidth > 0 ? self.explicitWidth : imageBounds.size.width;

    // This method is called by NSTextKit during layout/draw. It MUST be
    // side-effect-free — calling refreshDisplay (which mutates textStorage)
    // from here causes re-entrant layout that corrupts glyph positions,
    // making subsequent text overlap the image.
    //
    // Instead, we check the processed cache directly and kick off async
    // processing if needed, without ever touching textStorage.
    NSString *processedKey =
        CACHE_KEY_PROCESSED(self.imageURL, targetWidth, self.cachedHeight, self.cachedBorderRadius);

    if (![processedKey isEqualToString:self.lastProcessedKey]) {
      RCTUIImage *cachedProcessed = [[ENRMImageAttachment processedImageCache] objectForKey:processedKey];

      if (cachedProcessed) {
        // Cache hit — apply image but do NOT call refreshDisplay.
        self.lastProcessedKey = processedKey;
        self.loadedImage = cachedProcessed;
        if (self.isInline)
          self.image = cachedProcessed;
      } else {
        // Cache miss — process on a background queue. The completion will
        // set loadedImage and call refreshDisplay on the next run loop,
        // safely outside the layout/draw pass.
        self.lastProcessedKey = processedKey;
        __weak typeof(self) weakSelf = self;
        RCTUIImage *original = self.originalImage;
        CGFloat height = self.cachedHeight;
        CGFloat radius = self.cachedBorderRadius;
        BOOL isInline = self.isInline;

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
          __strong typeof(weakSelf) strongSelf = weakSelf;
          if (!strongSelf)
            return;

          RCTUIImage *processedImage = [strongSelf createScaledImage:original
                                                             toWidth:targetWidth
                                                              height:height
                                                        borderRadius:radius];
          if (processedImage) {
            [[ENRMImageAttachment processedImageCache] setObject:processedImage
                                                          forKey:processedKey
                                                            cost:ENRMImageByteCost(processedImage)];
          }

          dispatch_async(dispatch_get_main_queue(), ^{
            strongSelf.loadedImage = processedImage;
            if (isInline) {
              strongSelf.image = processedImage;
              strongSelf.bounds = CGRectMake(0, 0, height, height);
            } else {
              strongSelf.image = original;
            }
            [strongSelf refreshDisplay];
          });
        });
      }
    }
  }

  return self.loadedImage ?: self.image;
}

- (void)handleLoadedImage:(RCTUIImage *)image
{
  if (!image)
    return;

  self.originalImage = image;

  if (image.size.width > 0 && image.size.height > 0) {
    self.naturalWidth = image.size.width;
    self.naturalHeight = image.size.height;

    if (self.explicitWidth > 0 && self.explicitHeight == 0) {
      // Explicit width without height — derive from aspect ratio
      CGFloat aspectRatio = image.size.height / image.size.width;
      self.cachedHeight = round(self.explicitWidth * aspectRatio);
    }
  }

  if (self.explicitWidth > 0) {
    // Explicit dimensions: process immediately
    [self processAndApplyImage:image withTargetWidth:self.explicitWidth];
  } else if (self.isInline) {
    // Inline without explicit dims: process at configured size
    [self processAndApplyImage:image withTargetWidth:self.cachedHeight];
  } else {
    // Block without explicit dims: defer to imageForBounds where container width is known.
    // refreshDisplay and the notification must run on the main thread because they
    // access layout managers and trigger UIKit/AppKit relayout. When images are served
    // from the in-memory cache, handleLoadedImage: runs on the background render queue.
    void (^notifyBlock)(void) = ^{
      [self refreshDisplay];
      [[NSNotificationCenter defaultCenter] postNotificationName:@"ENRMImageAttachmentDidLoad" object:nil];
    };
    if ([NSThread isMainThread]) {
      notifyBlock();
    } else {
      dispatch_async(dispatch_get_main_queue(), notifyBlock);
    }
  }
}

- (void)processAndApplyImage:(RCTUIImage *)image withTargetWidth:(CGFloat)targetWidth
{
  if (targetWidth <= 0)
    return;

  NSString *processedKey = CACHE_KEY_PROCESSED(self.imageURL, targetWidth, self.cachedHeight, self.cachedBorderRadius);

  if ([processedKey isEqualToString:self.lastProcessedKey])
    return;
  self.lastProcessedKey = processedKey;

  RCTUIImage *cachedProcessed = [[ENRMImageAttachment processedImageCache] objectForKey:processedKey];

  if (cachedProcessed) {
    self.loadedImage = cachedProcessed;
    if (self.isInline)
      self.image = cachedProcessed;
    [self refreshDisplay];
    return;
  }

  __weak typeof(self) weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (!strongSelf)
      return;

    RCTUIImage *processedImage = [strongSelf createScaledImage:image
                                                       toWidth:targetWidth
                                                        height:strongSelf.cachedHeight
                                                  borderRadius:strongSelf.cachedBorderRadius];

    if (processedImage) {
      [[ENRMImageAttachment processedImageCache] setObject:processedImage
                                                    forKey:processedKey
                                                      cost:ENRMImageByteCost(processedImage)];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      strongSelf.loadedImage = processedImage;
      if (strongSelf.isInline) {
        strongSelf.image = processedImage;
        strongSelf.bounds = CGRectMake(0, 0, strongSelf.cachedHeight, strongSelf.cachedHeight);
      } else {
        strongSelf.image = image; // Keep original for layout references
      }
      [strongSelf refreshDisplay];
    });
  });
}

- (RCTUIImage *)createScaledImage:(RCTUIImage *)image
                          toWidth:(CGFloat)targetWidth
                           height:(CGFloat)targetHeight
                     borderRadius:(CGFloat)radius
{
  CGFloat sourceWidth = image.size.width;
  CGFloat sourceHeight = image.size.height;
  if (sourceWidth <= 0 || sourceHeight <= 0)
    return nil;

  CGFloat drawingWidth, drawingHeight;

  if (!self.isInline) {
    CGFloat aspectRatioScale = targetWidth / sourceWidth;
    drawingWidth = targetWidth;
    drawingHeight = sourceHeight * aspectRatioScale;
  } else {
    drawingWidth = targetWidth;
    drawingHeight = targetHeight;
  }

  CGRect drawingRect =
      CGRectMake((targetWidth - drawingWidth) / 2.0, (targetHeight - drawingHeight) / 2.0, drawingWidth, drawingHeight);

  RCTUIGraphicsImageRenderer *renderer = ImageRendererForSize(CGSizeMake(targetWidth, targetHeight));

  return [renderer imageWithActions:^(RCTUIGraphicsImageRendererContext *context) {
    if (radius > 0) {
      CGRect clippingRect = CGRectIntersection(CGRectMake(0, 0, targetWidth, targetHeight), drawingRect);
      UIBezierPath *path = UIBezierPathWithRoundedRect(clippingRect, radius);
      [path addClip];
    }
    [image drawInRect:drawingRect];
  }];
}

- (void)startDownloadingImage
{
  if (self.downloadURL.length == 0)
    return;

  __weak typeof(self) weakSelf = self;
  [[ENRMImageDownloader shared] downloadURL:self.downloadURL
                                 completion:^(RCTUIImage *image) { [weakSelf handleLoadedImage:image]; }];
}

- (void)refreshDisplay
{
  ENRMPlatformTextView *textView = [self fetchAssociatedTextView];
  if (!textView)
    return;

  // Replace the text storage content with a fresh copy. This is the most
  // aggressive invalidation possible — it forces NSTextKit to discard all
  // cached glyphs, line fragment rects, and attachment bounds, then rebuild
  // everything from scratch. Lighter approaches (edited:NSTextStorageEditedAttributes,
  // invalidateLayoutForCharacterRange:) were not sufficient on macOS because
  // NSTextKit can optimize away no-op attribute edits and skip re-querying
  // attachmentBoundsForTextContainer: for subsequent lines.
  NSTextStorage *storage = textView.textStorage;
  NSUInteger len = storage.length;
  if (len > 0) {
    NSAttributedString *fresh = [[NSAttributedString alloc] initWithAttributedString:storage];
    [storage setAttributedString:fresh];
  }
}

- (ENRMPlatformTextView *)fetchAssociatedTextView
{
  if (self.textView)
    return self.textView;
  if (!self.textContainer)
    return nil;
  self.textView = objc_getAssociatedObject(self.textContainer, kTextViewKey);
  return self.textView;
}

- (void)setupPlaceholder
{
  // For inline images, set bounds directly so NSTextKit can size them without
  // calling attachmentBoundsForTextContainer: (inline layout is simpler).
  // For block images, leave bounds at CGRectZero. This forces NSLayoutManager
  // to call our attachmentBoundsForTextContainer: override on EVERY layout pass,
  // where we return the correct size based on naturalWidth/naturalHeight.
  // Setting bounds to non-zero here would cause NSLayoutManager to use the
  // stale placeholder size directly, bypassing our override and producing
  // overlapping content when async-loaded images are taller than the placeholder.
  if (self.isInline) {
    CGFloat size = self.cachedHeight;
    self.bounds = CGRectMake(0, 0, size, size);
  }
  RCTUIGraphicsImageRenderer *renderer = [[RCTUIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(1, 1)];
  self.image = [renderer imageWithActions:^(RCTUIGraphicsImageRendererContext *ctx){}];
}

- (NSRange)findAttachmentRangeInText:(NSAttributedString *)attributedString
{
  __block NSRange foundRange = NSMakeRange(NSNotFound, 0);
  [attributedString enumerateAttribute:NSAttachmentAttributeName
                               inRange:NSMakeRange(0, attributedString.length)
                               options:0
                            usingBlock:^(id value, NSRange range, BOOL *stop) {
                              if (value == self) {
                                foundRange = range;
                                *stop = YES;
                              }
                            }];
  return foundRange;
}

@end