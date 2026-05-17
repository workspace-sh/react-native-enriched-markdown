#import "EnrichedMarkdown.h"
#import "AccessibilityInfo.h"
#import "AttributedRenderer.h"
#import "ENRMImageAttachment.h"
#import "ENRMMarkdownParser.h"
#import "ENRMUIKit.h"
#import "EditMenuUtils.h"

#import "ENRMFeatureFlags.h"

#if ENRICHED_MARKDOWN_MATH
#import "ENRMMathContainerView.h"
#endif
#import "EnrichedMarkdownInternalText.h"
#import "FontScaleObserver.h"
#import "FontUtils.h"
#import "HeightUpdateUtils.h"
#import "InlineHTMLPostProcessor.h"
#import "LastElementUtils.h"
#import "LinkTapUtils.h"
#import "MarkdownASTNode.h"
#import "MarkdownAccessibilityElementBuilder.h"
#import "MarkdownExtractor.h"
#import "ParagraphStyleUtils.h"
#import "RenderContext.h"
#import "RuntimeKeys.h"
#import "StyleConfig.h"
#import "StylePropsUtils.h"
#import "TableContainerView.h"
#import "TaskListTapUtils.h"
#import "TextViewLayoutManager.h"
#import <React/RCTUtils.h>
#import <objc/runtime.h>

#import <ReactNativeEnrichedMarkdown/EnrichedMarkdownComponentDescriptor.h>
#import <ReactNativeEnrichedMarkdown/EventEmitters.h>
#import <ReactNativeEnrichedMarkdown/Props.h>
#import <ReactNativeEnrichedMarkdown/RCTComponentViewHelpers.h>

#include "MeasurementCache.h"

#import "RCTFabricComponentsPlugins.h"
#import <React/RCTConversions.h>
#import <React/RCTFont.h>
#import <react/utils/ManagedObjectWrapper.h>

using namespace facebook::react;

@interface EMTextSegment : NSObject
@property (nonatomic, strong) NSArray<MarkdownASTNode *> *nodes;
+ (instancetype)segmentWithNodes:(NSArray<MarkdownASTNode *> *)nodes;
@end

@implementation EMTextSegment
+ (instancetype)segmentWithNodes:(NSArray<MarkdownASTNode *> *)nodes
{
  EMTextSegment *segment = [[EMTextSegment alloc] init];
  segment.nodes = [nodes copy];
  return segment;
}
@end

@interface EMTableSegment : NSObject
@property (nonatomic, strong) MarkdownASTNode *tableNode;
+ (instancetype)segmentWithTableNode:(MarkdownASTNode *)node;
@end

@implementation EMTableSegment
+ (instancetype)segmentWithTableNode:(MarkdownASTNode *)node
{
  EMTableSegment *segment = [[EMTableSegment alloc] init];
  segment.tableNode = node;
  return segment;
}
@end

#if ENRICHED_MARKDOWN_MATH
@interface EMMathSegment : NSObject
@property (nonatomic, strong) NSString *latex;
+ (instancetype)segmentWithLatex:(NSString *)latex;
@end

@implementation EMMathSegment
+ (instancetype)segmentWithLatex:(NSString *)latex
{
  EMMathSegment *segment = [[EMMathSegment alloc] init];
  segment.latex = latex;
  return segment;
}
@end
#endif

@interface EMRenderedTextSegment : NSObject
@property (nonatomic, strong) NSMutableAttributedString *attributedText;
@property (nonatomic, strong) RenderContext *context;
@property (nonatomic, strong) AccessibilityInfo *accessibilityInfo;
@property (nonatomic, assign) CGFloat lastElementMarginBottom;
+ (instancetype)withAttributedText:(NSMutableAttributedString *)text
                           context:(RenderContext *)context
                 accessibilityInfo:(AccessibilityInfo *)info
           lastElementMarginBottom:(CGFloat)marginBottom;
@end

@implementation EMRenderedTextSegment
+ (instancetype)withAttributedText:(NSMutableAttributedString *)text
                           context:(RenderContext *)context
                 accessibilityInfo:(AccessibilityInfo *)info
           lastElementMarginBottom:(CGFloat)marginBottom
{
  EMRenderedTextSegment *segment = [[EMRenderedTextSegment alloc] init];
  segment.attributedText = text;
  segment.context = context;
  segment.accessibilityInfo = info;
  segment.lastElementMarginBottom = marginBottom;
  return segment;
}
@end

@interface EnrichedMarkdown () <RCTEnrichedMarkdownViewProtocol, UITextViewDelegate>
@end

#if TARGET_OS_OSX
@interface ENRMFlippedView : RCTUIView
@end
@implementation ENRMFlippedView
- (BOOL)isFlipped
{
  return YES;
}
@end
#endif

@implementation EnrichedMarkdown {
  ENRMMarkdownParser *_parser;
  StyleConfig *_config;
  ENRMMd4cFlags *_md4cFlags;
  NSString *_cachedMarkdown;
  NSString *_renderedMarkdown;
  NSMutableArray<RCTUIView *> *_segmentViews;

  dispatch_queue_t _renderQueue;
  NSUInteger _currentRenderId;
  BOOL _blockAsyncRender;

  EnrichedMarkdownShadowNode::ConcreteState::Shared _state;
  int _heightUpdateCounter;

  FontScaleObserver *_fontScaleObserver;
  CGFloat _maxFontSizeMultiplier;

  BOOL _allowTrailingMargin;
  BOOL _selectable;
  BOOL _enableLinkPreview;
#if TARGET_OS_OSX
  NSScrollView *_macScrollContainer;
  NSEdgeInsets _contentInset;
  ENRMFlippedView *_macDocumentView;
#endif
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<EnrichedMarkdownComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const EnrichedMarkdownProps>();
    _props = defaultProps;

    self.backgroundColor = [RCTUIColor clearColor];
    _parser = [[ENRMMarkdownParser alloc] init];
    _md4cFlags = [ENRMMd4cFlags defaultFlags];
    _segmentViews = [NSMutableArray array];

    _renderQueue = dispatch_queue_create("com.swmansion.enriched.markdown.container.render", DISPATCH_QUEUE_SERIAL);
    _currentRenderId = 0;

    _maxFontSizeMultiplier = 0;
    _allowTrailingMargin = NO;
    _selectable = YES;
    _enableLinkPreview = YES;

#if TARGET_OS_OSX
    _macScrollContainer = [[NSScrollView alloc] initWithFrame:self.bounds];
    _macScrollContainer.hasVerticalScroller = YES;
    _macScrollContainer.hasHorizontalScroller = NO;
    _macScrollContainer.drawsBackground = NO;
    _macScrollContainer.backgroundColor = [NSColor clearColor];
    _macScrollContainer.contentView.drawsBackground = NO;
    _macScrollContainer.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    _macDocumentView = [[ENRMFlippedView alloc] initWithFrame:self.bounds];
    _macDocumentView.autoresizesSubviews = NO;
    _macScrollContainer.documentView = _macDocumentView;

    [self addSubview:_macScrollContainer];
#endif

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleImageAttachmentDidLoad:)
                                                 name:@"ENRMImageAttachmentDidLoad"
                                               object:nil];

    _fontScaleObserver = [[FontScaleObserver alloc] init];
    __weak EnrichedMarkdown *weakSelf = self;
    _fontScaleObserver.onChange = ^{
      EnrichedMarkdown *strongSelf = weakSelf;
      if (!strongSelf)
        return;
      if (strongSelf->_config != nil) {
        [strongSelf->_config setFontScaleMultiplier:strongSelf->_fontScaleObserver.effectiveFontScale];
      }
      if (strongSelf->_cachedMarkdown != nil && strongSelf->_cachedMarkdown.length > 0) {
        [strongSelf renderMarkdownContent:strongSelf->_cachedMarkdown];
      }
    };
  }
  return self;
}

- (RCTUIView *)segmentContainer
{
#if TARGET_OS_OSX
  return _macDocumentView;
#else
  return self;
#endif
}

- (CGFloat)computeSegmentLayoutForWidth:(CGFloat)width applyFrames:(BOOL)applyFrames
{
  if (_segmentViews.count == 0)
    return 0.0;

#if TARGET_OS_OSX
  // Apply content inset via document view padding (not NSScrollView.contentInsets,
  // which gets reset by internal scroll view state management during anchor scrolls).
  CGFloat insetTop = _contentInset.top;
  CGFloat insetLeft = _contentInset.left;
  CGFloat insetRight = _contentInset.right;
  CGFloat insetBottom = _contentInset.bottom;
  CGFloat contentWidth = width - insetLeft - insetRight;
  if (contentWidth <= 0)
    contentWidth = width;
#else
  CGFloat insetTop = 0;
  CGFloat insetLeft = 0;
  CGFloat insetBottom = 0;
  CGFloat contentWidth = width;
#endif

  __block CGFloat yOffset = insetTop;
  const NSUInteger lastIndex = _segmentViews.count - 1;

  [_segmentViews enumerateObjectsUsingBlock:^(RCTUIView *segment, NSUInteger i, BOOL *stop) {
    const BOOL isLast = (i == lastIndex);
    const BOOL shouldAddBottomMargin = (!isLast || _allowTrailingMargin);

    CGFloat segmentHeight = 0;

    if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
      EnrichedMarkdownInternalText *textView = (EnrichedMarkdownInternalText *)segment;
      textView.allowTrailingMargin = shouldAddBottomMargin;
      segmentHeight = [textView measureHeight:contentWidth];

    } else if ([segment isKindOfClass:[TableContainerView class]]) {
      yOffset += _config.tableMarginTop;
      segmentHeight = [(TableContainerView *)segment measureHeight:contentWidth];
    }
#if ENRICHED_MARKDOWN_MATH
    else if ([segment isKindOfClass:[ENRMMathContainerView class]]) {
      yOffset += _config.mathMarginTop;
      segmentHeight = [(ENRMMathContainerView *)segment measureHeight:contentWidth];
    }
#endif

    if (applyFrames) {
      CGRect segmentFrame = CGRectMake(insetLeft, yOffset, contentWidth, segmentHeight);
      segment.frame = segmentFrame;
#if TARGET_OS_OSX
      NSLog(@"[ENRM-SEG] seg %lu: y=%.0f h=%.0f w=%.0f", (unsigned long)i, yOffset, segmentHeight, contentWidth);
      if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
        EnrichedMarkdownInternalText *textSeg = (EnrichedMarkdownInternalText *)segment;
        textSeg.textView.frame = segment.bounds;
        textSeg.textView.textContainer.size = CGSizeMake(contentWidth, CGFLOAT_MAX);
        [textSeg.textView.layoutManager ensureLayoutForTextContainer:textSeg.textView.textContainer];
        ENRMSetNeedsDisplay(textSeg.textView);
      }
#endif
    }

    yOffset += segmentHeight;

    if ([segment isKindOfClass:[TableContainerView class]] && shouldAddBottomMargin) {
      yOffset += _config.tableMarginBottom;
    }
#if ENRICHED_MARKDOWN_MATH
    else if ([segment isKindOfClass:[ENRMMathContainerView class]] && shouldAddBottomMargin) {
      yOffset += _config.mathMarginBottom;
    }
#endif
  }];

  return yOffset + insetBottom;
}

- (CGSize)measureSize:(CGFloat)maxWidth
{
  CGFloat defaultHeight = UIFontLineHeight([UIFont systemFontOfSize:16.0]);
  CGFloat totalHeight = [self computeSegmentLayoutForWidth:maxWidth applyFrames:NO];
  if (totalHeight == 0)
    return CGSizeMake(maxWidth, defaultHeight);

  // Round to pixel boundaries to match React Native's <Text> measurement
  CGFloat scale = RCTScreenScale();
  return CGSizeMake(maxWidth, ceil(totalHeight * scale) / scale);
}

- (BOOL)hasRenderedMarkdown:(NSString *)markdown
{
  return _renderedMarkdown != nil && [_renderedMarkdown isEqualToString:markdown];
}

- (void)updateState:(const facebook::react::State::Shared &)state
           oldState:(const facebook::react::State::Shared &)oldState
{
  _state = std::static_pointer_cast<const EnrichedMarkdownShadowNode::ConcreteState>(state);

  if (oldState == nullptr) {
    [self requestHeightUpdate];
  }
}

- (void)requestHeightUpdate
{
  if (_state == nullptr) {
    return;
  }

  // Always invalidate the measurement cache before pushing a state update.
  // Without this, Yoga's measureContent returns the stale cached height
  // (e.g. from before async images loaded) and never resizes the component.
  const auto &props = *std::static_pointer_cast<EnrichedMarkdownProps const>(_props);
  if (!props.markdown.empty()) {
    MeasurementCache::shared().invalidateForMarkdown(props.markdown);
  }

  _heightUpdateCounter++;
  auto selfRef = wrapManagedObjectWeakly(self);
  _state->updateState(EnrichedMarkdownState(_heightUpdateCounter, selfRef));
}

- (NSArray *)splitASTIntoSegments:(MarkdownASTNode *)root
{
  NSMutableArray *segments = [NSMutableArray array];
  NSMutableArray *currentTextNodes = [NSMutableArray array];

  for (MarkdownASTNode *child in root.children) {
    if (child.type == MarkdownNodeTypeTable) {
      if (currentTextNodes.count > 0) {
        [segments addObject:[EMTextSegment segmentWithNodes:[currentTextNodes copy]]];
        [currentTextNodes removeAllObjects];
      }
      [segments addObject:[EMTableSegment segmentWithTableNode:child]];
    }
#if ENRICHED_MARKDOWN_MATH
    else if (child.type == MarkdownNodeTypeLatexMathDisplay) {
#if !TARGET_OS_OSX
      if (currentTextNodes.count > 0) {
        [segments addObject:[EMTextSegment segmentWithNodes:[currentTextNodes copy]]];
        [currentTextNodes removeAllObjects];
      }
      NSString *latex = child.children.count > 0 ? child.children.firstObject.content : child.content;
      [segments addObject:[EMMathSegment segmentWithLatex:latex ?: @""]];
#else
      // TODO: Fix block math rendering on macOS. Adding ENRMMathContainerView (which
      // hosts MTMathUILabel) as a segment causes all preceding text segments to become
      // invisible. Likely related to MTMathUILabel.layer.geometryFlipped interacting
      // with NSTextView's coordinate system. Inline math ($...$) works.
#endif
    }
#endif
    else {
      [currentTextNodes addObject:child];
    }
  }

  if (currentTextNodes.count > 0) {
    [segments addObject:[EMTextSegment segmentWithNodes:currentTextNodes]];
  }

  return segments;
}

- (void)renderMarkdownContent:(NSString *)markdownString
{
  if (_blockAsyncRender) {
    return;
  }

  _cachedMarkdown = [markdownString copy];
  NSUInteger renderId = ++_currentRenderId;

  StyleConfig *config = [_config copy];
  ENRMMarkdownParser *parser = _parser;
  ENRMMd4cFlags *md4cFlags = [_md4cFlags copy];

  BOOL allowFontScaling = _fontScaleObserver.allowFontScaling;
  CGFloat maxFontSizeMultiplier = _maxFontSizeMultiplier;
  BOOL allowTrailingMargin = _allowTrailingMargin;

  dispatch_async(_renderQueue, ^{
    MarkdownASTNode *ast = [parser parseMarkdown:markdownString flags:md4cFlags];
    if (!ast) {
      return;
    }

    NSArray *segments = [self splitASTIntoSegments:ast];

    NSMutableArray *renderedSegments = [NSMutableArray array];

    for (id segment in segments) {
      if ([segment isKindOfClass:[EMTextSegment class]]) {
        EMRenderedTextSegment *rendered = [self renderTextSegment:(EMTextSegment *)segment
                                                           config:config
                                              allowTrailingMargin:allowTrailingMargin
                                                 allowFontScaling:allowFontScaling
                                            maxFontSizeMultiplier:maxFontSizeMultiplier];
        [renderedSegments addObject:rendered];
      } else if ([segment isKindOfClass:[EMTableSegment class]]) {
        [renderedSegments addObject:segment];
      }
#if ENRICHED_MARKDOWN_MATH
      else if ([segment isKindOfClass:[EMMathSegment class]]) {
        [renderedSegments addObject:segment];
      }
#endif
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      if (renderId != self->_currentRenderId) {
        return;
      }

      [self applyRenderedSegments:renderedSegments];
    });
  });
}

- (NSArray *)parseAndRenderSegments:(NSString *)markdownString
{
  MarkdownASTNode *ast = [_parser parseMarkdown:markdownString flags:_md4cFlags];
  if (!ast) {
    return nil;
  }

  NSArray *segments = [self splitASTIntoSegments:ast];
  NSMutableArray *renderedSegments = [NSMutableArray array];

  for (id segment in segments) {
    if ([segment isKindOfClass:[EMTextSegment class]]) {
      EMRenderedTextSegment *rendered = [self renderTextSegment:(EMTextSegment *)segment
                                                         config:_config
                                            allowTrailingMargin:_allowTrailingMargin
                                               allowFontScaling:_fontScaleObserver.allowFontScaling
                                          maxFontSizeMultiplier:_maxFontSizeMultiplier];
      [renderedSegments addObject:rendered];
    } else if ([segment isKindOfClass:[EMTableSegment class]]) {
      [renderedSegments addObject:segment];
    }
#if ENRICHED_MARKDOWN_MATH
    else if ([segment isKindOfClass:[EMMathSegment class]]) {
      [renderedSegments addObject:segment];
    }
#endif
  }

  return renderedSegments;
}

/// Synchronous rendering for mock view measurement (no UI updates needed).
- (void)renderMarkdownSynchronously:(NSString *)markdownString
{
  if (!markdownString || markdownString.length == 0) {
    return;
  }

  for (RCTUIView *view in _segmentViews) {
    [view removeFromSuperview];
  }
  [_segmentViews removeAllObjects];

  _blockAsyncRender = YES;
  _cachedMarkdown = [markdownString copy];
  _renderedMarkdown = [markdownString copy];

  NSArray *renderedSegments = [self parseAndRenderSegments:markdownString];
  if (!renderedSegments) {
    return;
  }

  for (id segment in renderedSegments) {
    if ([segment isKindOfClass:[EMRenderedTextSegment class]]) {
      EnrichedMarkdownInternalText *view = [self createTextViewForRenderedSegment:(EMRenderedTextSegment *)segment];
      [_segmentViews addObject:view];
      [[self segmentContainer] addSubview:view];
    } else if ([segment isKindOfClass:[EMTableSegment class]]) {
      TableContainerView *tableView = [self createTableViewForSegment:(EMTableSegment *)segment];
      [_segmentViews addObject:tableView];
      [[self segmentContainer] addSubview:tableView];
    }
#if ENRICHED_MARKDOWN_MATH
    else if ([segment isKindOfClass:[EMMathSegment class]]) {
      ENRMMathContainerView *mathView = [self createMathViewForSegment:(EMMathSegment *)segment];
      [_segmentViews addObject:mathView];
      [[self segmentContainer] addSubview:mathView];
    }
#endif
  }
}

- (void)applyRenderedSegments:(NSArray *)renderedSegments
{
  _renderedMarkdown = [_cachedMarkdown copy];

  for (RCTUIView *view in _segmentViews) {
    [view removeFromSuperview];
  }
  [_segmentViews removeAllObjects];

  for (id segment in renderedSegments) {
    if ([segment isKindOfClass:[EMRenderedTextSegment class]]) {
      EnrichedMarkdownInternalText *view = [self createTextViewForRenderedSegment:(EMRenderedTextSegment *)segment];
      [_segmentViews addObject:view];
      [[self segmentContainer] addSubview:view];
    } else if ([segment isKindOfClass:[EMTableSegment class]]) {
      EMTableSegment *tableSegment = (EMTableSegment *)segment;
      TableContainerView *tableView = [self createTableViewForSegment:tableSegment];
      [_segmentViews addObject:tableView];
      [[self segmentContainer] addSubview:tableView];
    }
#if ENRICHED_MARKDOWN_MATH
    else if ([segment isKindOfClass:[EMMathSegment class]]) {
      EMMathSegment *mathSegment = (EMMathSegment *)segment;
      ENRMMathContainerView *mathView = [self createMathViewForSegment:mathSegment];
      [_segmentViews addObject:mathView];
      [[self segmentContainer] addSubview:mathView];
    }
#endif
  }

  if (self.bounds.size.width > 0) {
    [self setNeedsLayout];

    CGSize measured = [self measureSize:self.bounds.size.width];
    if (needsHeightUpdate(measured, self.bounds)) {
      [self requestHeightUpdate];
    }
  }
}

- (EMRenderedTextSegment *)renderTextSegment:(EMTextSegment *)textSegment
                                      config:(StyleConfig *)config
                         allowTrailingMargin:(BOOL)allowTrailingMargin
                            allowFontScaling:(BOOL)allowFontScaling
                       maxFontSizeMultiplier:(CGFloat)maxFontSizeMultiplier
{
  MarkdownASTNode *temporaryRoot = [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeDocument];
  for (MarkdownASTNode *node in textSegment.nodes) {
    [temporaryRoot addChild:node];
  }

  AttributedRenderer *renderer = [[AttributedRenderer alloc] initWithConfig:config];
  [renderer setAllowTrailingMargin:allowTrailingMargin];
  RenderContext *context = [RenderContext new];
  context.allowFontScaling = allowFontScaling;
  context.maxFontSizeMultiplier = maxFontSizeMultiplier;
  NSMutableAttributedString *attributedText = [renderer renderRoot:temporaryRoot context:context];
  applyInlineHTMLPostProcessing(attributedText);

  CGFloat lastMarginBottom = [renderer getLastElementMarginBottom];
  AccessibilityInfo *accessibilityInfo = [AccessibilityInfo infoFromContext:context];

  return [EMRenderedTextSegment withAttributedText:attributedText
                                           context:context
                                 accessibilityInfo:accessibilityInfo
                           lastElementMarginBottom:lastMarginBottom];
}

- (EnrichedMarkdownInternalText *)createTextViewForRenderedSegment:(EMRenderedTextSegment *)segment
{
  EnrichedMarkdownInternalText *view = [[EnrichedMarkdownInternalText alloc] initWithConfig:_config];
  view.allowTrailingMargin = _allowTrailingMargin;
  view.lastElementMarginBottom = segment.lastElementMarginBottom;
  view.accessibilityInfo = segment.accessibilityInfo;
  view.textView.selectable = _selectable;
  [view applyAttributedText:segment.attributedText context:segment.context];

  ENRMTapRecognizer *tapRecognizer = [[ENRMTapRecognizer alloc] initWithTarget:self action:@selector(textTapped:)];
  [view.textView addGestureRecognizer:tapRecognizer];

#if !TARGET_OS_OSX
  view.textView.delegate = self;
#else
  __weak EnrichedMarkdown *weakSelf = self;
  [view setContextMenuProvider:^NSMenu *_Nullable(NSMenu *baseMenu, NSTextView *textView) {
    EnrichedMarkdown *strongSelf = weakSelf;
    if (!strongSelf) {
      return baseMenu;
    }
    NSString *segmentMarkdown = extractMarkdownFromAttributedString(textView.textStorage, textView.selectedRange);
    return buildEditMenuForSelection(textView.textStorage, textView.selectedRange, segmentMarkdown, strongSelf->_config,
                                     @[ baseMenu ]);
  }];

  ((ENRMContextMenuTextView *)view.textView).linkClickHandler = ^BOOL(NSString *url) {
    EnrichedMarkdown *strongSelf = weakSelf;
    if (!strongSelf)
      return NO;

    // Handle anchor links by scrolling natively
    if ([url hasPrefix:@"#"]) {
      [strongSelf scrollToAnchor:url];
    }

    // Emit to JS
    auto eventEmitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(strongSelf->_eventEmitter);
    if (eventEmitter) {
      eventEmitter->onLinkPress({.url = std::string([url UTF8String])});
    }

    return YES;
  };
#endif

  return view;
}

- (TableContainerView *)createTableViewForSegment:(EMTableSegment *)tableSegment
{
  TableContainerView *tableView = [[TableContainerView alloc] initWithConfig:_config];

  tableView.allowFontScaling = _fontScaleObserver.allowFontScaling;
  tableView.maxFontSizeMultiplier = _maxFontSizeMultiplier;
  tableView.enableLinkPreview = _enableLinkPreview;

  __weak EnrichedMarkdown *weakSelf = self;

  tableView.onLinkPress = ^(NSString *url) {
    EnrichedMarkdown *strongSelf = weakSelf;
    if (!strongSelf || !url)
      return;

    auto eventEmitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(strongSelf->_eventEmitter);
    if (eventEmitter) {
      eventEmitter->onLinkPress({.url = std::string([url UTF8String])});
    }
  };

  tableView.onLinkLongPress = ^(NSString *url) {
    EnrichedMarkdown *strongSelf = weakSelf;
    if (!strongSelf || !url)
      return;

    auto eventEmitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(strongSelf->_eventEmitter);
    if (eventEmitter) {
      eventEmitter->onLinkLongPress({.url = std::string([url UTF8String])});
    }
  };

  [tableView applyTableNode:tableSegment.tableNode];

  return tableView;
}

#if ENRICHED_MARKDOWN_MATH
- (ENRMMathContainerView *)createMathViewForSegment:(EMMathSegment *)mathSegment
{
  ENRMMathContainerView *mathView = [[ENRMMathContainerView alloc] initWithConfig:_config];
  [mathView applyLatex:mathSegment.latex];
  return mathView;
}
#endif

- (void)handleImageAttachmentDidLoad:(NSNotification *)notification
{
  // The notification may fire on a background thread (e.g. when an image is
  // served from the in-memory cache during the background render pass).
  // All UIKit/AppKit work must happen on the main thread.
  if (![NSThread isMainThread]) {
    dispatch_async(dispatch_get_main_queue(), ^{ [self handleImageAttachmentDidLoad:notification]; });
    return;
  }

  // Re-render the entire markdown from scratch. This creates fresh text views
  // whose layout managers have never seen the placeholder attachment bounds.
  // When NSTextKit does layout for the first time on these fresh views, it
  // queries attachmentBoundsForTextContainer: and gets the real natural
  // dimensions — no stale glyph position caching to fight.
  //
  // Previous approaches (replacing text storage content, invalidating layout
  // ranges) failed because NSTextKit on macOS aggressively caches line fragment
  // rects from the initial layout pass and doesn't reliably re-query attachment
  // bounds even after setAttributedString: replacement.
  //
  // The attachment registry ensures the same (already-loaded) attachment objects
  // are reused, so no new downloads are triggered. The _currentRenderId mechanism
  // in renderMarkdownContent: handles coalescing if multiple images load in
  // quick succession.
  if (_cachedMarkdown && _cachedMarkdown.length > 0) {
    const auto &props = *std::static_pointer_cast<EnrichedMarkdownProps const>(_props);
    if (!props.markdown.empty()) {
      MeasurementCache::shared().invalidateForMarkdown(props.markdown);
    }
    [self renderMarkdownContent:_cachedMarkdown];
  }
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self name:@"ENRMImageAttachmentDidLoad" object:nil];
}

- (void)layoutSubviews
{
  [super layoutSubviews];
#if TARGET_OS_OSX
  // Ensure scroll container is on top of Fabric's _containerView.
  // Use addSubview:positioned:relativeTo: to reorder in place — when the view
  // is already a subview this just adjusts z-order without removing it from
  // the window hierarchy, which previously caused NSTextView to lose layout
  // state computed by ensureLayoutForTextContainer:.
  if ([[self subviews] lastObject] != _macScrollContainer) {
    [self addSubview:_macScrollContainer positioned:NSWindowAbove relativeTo:nil];
  }
  _macScrollContainer.frame = self.bounds;
  CGFloat width = self.bounds.size.width;
  // computeSegmentLayoutForWidth applies contentInset padding to segments directly
  CGFloat totalHeight = [self computeSegmentLayoutForWidth:width applyFrames:YES];
  NSSize docSize = NSMakeSize(width, MAX(totalHeight, self.bounds.size.height));
  [_macDocumentView setFrameSize:docSize];
  [_macScrollContainer reflectScrolledClipView:_macScrollContainer.contentView];
#else
  [self computeSegmentLayoutForWidth:self.bounds.size.width applyFrames:YES];
#endif
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &oldViewProps = *std::static_pointer_cast<EnrichedMarkdownProps const>(_props);
  const auto &newViewProps = *std::static_pointer_cast<EnrichedMarkdownProps const>(props);

  BOOL stylePropChanged = NO;

  if (_config == nil) {
    _config = [[StyleConfig alloc] init];
    [_config setFontScaleMultiplier:_fontScaleObserver.effectiveFontScale];
  }

  stylePropChanged = applyMarkdownStyleToConfig(_config, newViewProps.markdownStyle, oldViewProps.markdownStyle);

  if (stylePropChanged) {
    [ENRMImageAttachment clearAttachmentRegistry];
  }

  _selectable = newViewProps.selectable;

  for (RCTUIView *segment in _segmentViews) {
    if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
      EnrichedMarkdownInternalText *textSegment = (EnrichedMarkdownInternalText *)segment;
      if (textSegment.textView.selectable != newViewProps.selectable) {
        textSegment.textView.selectable = newViewProps.selectable;
      }
    }
  }

  if (newViewProps.allowFontScaling != oldViewProps.allowFontScaling) {
    _fontScaleObserver.allowFontScaling = newViewProps.allowFontScaling;
    if (_config != nil) {
      [_config setFontScaleMultiplier:_fontScaleObserver.effectiveFontScale];
    }
    stylePropChanged = YES;
  }

  if (newViewProps.maxFontSizeMultiplier != oldViewProps.maxFontSizeMultiplier) {
    _maxFontSizeMultiplier = newViewProps.maxFontSizeMultiplier;
    if (_config != nil) {
      [_config setMaxFontSizeMultiplier:_maxFontSizeMultiplier];
    }
    stylePropChanged = YES;
  }

  if (newViewProps.allowTrailingMargin != oldViewProps.allowTrailingMargin) {
    _allowTrailingMargin = newViewProps.allowTrailingMargin;
  }

  BOOL md4cFlagsChanged = NO;
  if (newViewProps.md4cFlags.underline != oldViewProps.md4cFlags.underline) {
    _md4cFlags.underline = newViewProps.md4cFlags.underline;
    md4cFlagsChanged = YES;
  }
  if (newViewProps.md4cFlags.latexMath != oldViewProps.md4cFlags.latexMath) {
    _md4cFlags.latexMath = newViewProps.md4cFlags.latexMath;
    md4cFlagsChanged = YES;
  }

  BOOL markdownChanged = oldViewProps.markdown != newViewProps.markdown;
  BOOL allowTrailingMarginChanged = newViewProps.allowTrailingMargin != oldViewProps.allowTrailingMargin;

  _enableLinkPreview = newViewProps.enableLinkPreview;

#if TARGET_OS_OSX
  {
    const auto &inset = newViewProps.contentInset;
    NSEdgeInsets newInset = NSEdgeInsetsMake(inset.top, inset.left, inset.bottom, inset.right);
    BOOL insetChanged = (newInset.top != _contentInset.top || newInset.left != _contentInset.left ||
                         newInset.bottom != _contentInset.bottom || newInset.right != _contentInset.right);
    _contentInset = newInset;
    if (insetChanged) {
      [self setNeedsLayout];
    }
  }
#endif

  if (markdownChanged || stylePropChanged || md4cFlagsChanged || allowTrailingMarginChanged) {
    NSString *markdownString = [[NSString alloc] initWithUTF8String:newViewProps.markdown.c_str()];
    [self renderMarkdownContent:markdownString];
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)didMoveToWindow
{
  [super didMoveToWindow];

  if (self.window && _renderedMarkdown != nil) {
    for (RCTUIView *segment in _segmentViews) {
      if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
        EnrichedMarkdownInternalText *textSegment = (EnrichedMarkdownInternalText *)segment;
        ENRMRefreshTextViewAfterWindowAttach(textSegment.textView, textSegment.bounds);
      }
    }

    CGSize measured = [self measureSize:self.bounds.size.width];
    if (needsHeightUpdate(measured, self.bounds)) {
      [self requestHeightUpdate];
    }
  }
}

Class<RCTComponentViewProtocol> EnrichedMarkdownCls(void)
{
  return EnrichedMarkdown.class;
}

- (facebook::react::SharedTouchEventEmitter)touchEventEmitterAtPoint:(CGPoint)point
{
  for (RCTUIView *segment in _segmentViews) {
    if (![segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
      continue;
    }
    EnrichedMarkdownInternalText *textSegment = (EnrichedMarkdownInternalText *)segment;
    CGPoint segmentPoint = [self convertPoint:point toView:textSegment.textView];
#if !TARGET_OS_OSX
    BOOL isInsideView = [textSegment.textView pointInside:segmentPoint withEvent:nil];
#else
    BOOL isInsideView = CGRectContainsPoint(textSegment.textView.bounds, segmentPoint);
#endif
    if (isInsideView) {
      if (isPointOnInteractiveElement(textSegment.textView, segmentPoint)) {
        return nil;
      }
      break;
    }
  }

  return [super touchEventEmitterAtPoint:point];
}

#if TARGET_OS_OSX
- (void)mouseDown:(NSEvent *)event
{
  for (RCTUIView *segment in _segmentViews) {
    if (![segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
      continue;
    }
    ENRMPlatformTextView *tv = ((EnrichedMarkdownInternalText *)segment).textView;
    if (tv.selectedRange.length > 0) {
      tv.selectedRange = NSMakeRange(0, 0);
    }
  }
  [super mouseDown:event];
}
#endif

/// Convert heading text to a GitHub-style anchor slug
static NSString *slugifyHeadingEM(NSString *headingText)
{
  NSString *lower = [headingText lowercaseString];
  NSMutableString *slug = [NSMutableString string];
  for (NSUInteger i = 0; i < lower.length; i++) {
    unichar c = [lower characterAtIndex:i];
    if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-' || c == '_') {
      [slug appendFormat:@"%C", c];
    } else if (c == ' ') {
      [slug appendString:@"-"];
    }
  }
  return slug;
}

- (BOOL)scrollToAnchor:(NSString *)fragment
{
  NSString *anchor = fragment;
  if ([anchor hasPrefix:@"#"]) {
    anchor = [anchor substringFromIndex:1];
  }
  if (anchor.length == 0)
    return NO;

  // Search through all segment views for the heading
  for (RCTUIView *segmentView in _segmentViews) {
    if (![segmentView isKindOfClass:[EnrichedMarkdownInternalText class]])
      continue;

    EnrichedMarkdownInternalText *internalText = (EnrichedMarkdownInternalText *)segmentView;
    ENRMPlatformTextView *textView = internalText.textView;
    NSAttributedString *attrText = ENRMGetAttributedText(textView);
    if (!attrText || attrText.length == 0)
      continue;

    __block NSRange matchRange = NSMakeRange(NSNotFound, 0);

    [attrText enumerateAttribute:MarkdownTypeAttributeName
                         inRange:NSMakeRange(0, attrText.length)
                         options:0
                      usingBlock:^(id value, NSRange range, BOOL *stop) {
                        if (![value isKindOfClass:[NSString class]])
                          return;
                        NSString *type = (NSString *)value;
                        if (![type hasPrefix:@"heading-"])
                          return;

                        NSString *headingText = [[attrText attributedSubstringFromRange:range] string];
                        headingText = [headingText
                            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        NSString *slug = slugifyHeadingEM(headingText);

                        if ([slug isEqualToString:anchor]) {
                          matchRange = range;
                          *stop = YES;
                        }
                      }];

    if (matchRange.location == NSNotFound)
      continue;

    // Found the heading — get its rect within this text view
    NSLayoutManager *layoutManager = textView.layoutManager;
    NSTextContainer *textContainer = textView.textContainer;
    NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:matchRange actualCharacterRange:NULL];
    CGRect headingRect = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:textContainer];

#if TARGET_OS_OSX
    if (!_macScrollContainer || !_macDocumentView)
      return NO;

    // Convert to document view coordinates: segment frame origin + heading offset within the text view.
    // segmentView.frame.origin.y already includes the top inset padding (applied in computeSegmentLayoutForWidth).
    // Subtract the top inset so the heading sits at the visible top edge, not below the padding.
    CGFloat scrollY = segmentView.frame.origin.y + headingRect.origin.y;
    CGFloat adjustedY = MAX(0, scrollY - _contentInset.top);
    [_macScrollContainer.contentView scrollToPoint:NSMakePoint(0, adjustedY)];
    [_macScrollContainer reflectScrolledClipView:_macScrollContainer.contentView];
#else
    // On iOS, walk up the view hierarchy to find the parent UIScrollView
    // (typically a React Native ScrollView) and scroll it to the heading.
    CGFloat targetY = segmentView.frame.origin.y + headingRect.origin.y;

    UIScrollView *parentScroll = nil;
    UIView *current = self.superview;
    while (current) {
      if ([current isKindOfClass:[UIScrollView class]]) {
        parentScroll = (UIScrollView *)current;
        break;
      }
      current = current.superview;
    }
    if (!parentScroll)
      return NO;

    CGPoint pointInScroll = [self convertPoint:CGPointMake(0, targetY) toView:parentScroll];
    CGFloat maxOffsetY = parentScroll.contentSize.height - parentScroll.bounds.size.height;
    CGFloat clampedY = MIN(pointInScroll.y, MAX(maxOffsetY, 0));
    [parentScroll setContentOffset:CGPointMake(0, clampedY) animated:YES];
#endif

    return YES;
  }

  return NO;
}

- (void)textTapped:(ENRMTapRecognizer *)recognizer
{
  ENRMPlatformTextView *textView = (ENRMPlatformTextView *)recognizer.view;

  if (handleTaskListTapWithSharedLogic(
          textView, recognizer, &self->_cachedMarkdown, self->_config,
          ^(NSInteger index, BOOL checked, NSString *itemText) {
            auto eventEmitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(self->_eventEmitter);
            if (eventEmitter) {
              eventEmitter->onTaskListItemPress({
                  .index = (int)index,
                  .checked = checked,
                  .text = std::string([itemText UTF8String] ?: ""),
              });
            }
          },
          ^(NSString *updatedMarkdown) { [self renderMarkdownContent:updatedMarkdown]; })) {
    return;
  }

  NSString *url = linkURLAtTapLocation(textView, recognizer);
  if (url) {
    if ([url hasPrefix:@"#"] && [self scrollToAnchor:url]) {
      auto eventEmitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(_eventEmitter);
      if (eventEmitter) {
        eventEmitter->onLinkPress({.url = std::string([url UTF8String])});
      }
      return;
    }
    auto eventEmitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(_eventEmitter);
    if (eventEmitter) {
      eventEmitter->onLinkPress({.url = std::string([url UTF8String])});
    }
    return;
  }

  ENRMClearSelection(textView);
}

#if !TARGET_OS_OSX
- (UIMenu *)textView:(UITextView *)textView
    editMenuForTextInRange:(NSRange)range
          suggestedActions:(NSArray<UIMenuElement *> *)suggestedActions API_AVAILABLE(ios(16.0))
{
  NSString *segmentMarkdown = extractMarkdownFromAttributedString(textView.attributedText, range);
  return buildEditMenuForSelection(textView.attributedText, range, segmentMarkdown, _config, suggestedActions);
}

- (BOOL)textView:(UITextView *)textView
    shouldInteractWithURL:(NSURL *)URL
                  inRange:(NSRange)characterRange
              interaction:(UITextItemInteraction)interaction
{
  // Intercept anchor links and scroll to the heading instead of opening
  NSString *urlStr = URL.absoluteString;
  NSString *fragment = URL.fragment;
  if (fragment.length > 0 || [urlStr hasPrefix:@"#"]) {
    NSString *anchor = fragment.length > 0 ? [@"#" stringByAppendingString:fragment] : urlStr;
    if ([self scrollToAnchor:anchor]) {
      auto eventEmitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(_eventEmitter);
      if (eventEmitter) {
        eventEmitter->onLinkPress({.url = std::string([anchor UTF8String])});
      }
      return NO;
    }
  }

  if (interaction != UITextItemInteractionPresentActions) {
    return YES;
  }

  NSString *urlString = linkURLAtRange(textView, characterRange);

  if (!urlString || _enableLinkPreview) {
    return YES;
  }

  auto eventEmitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(_eventEmitter);
  if (eventEmitter) {
    eventEmitter->onLinkLongPress({.url = std::string([urlString UTF8String])});
  }
  return NO;
}
#endif

#if TARGET_OS_OSX
#pragma mark - NSTextViewDelegate (Link Clicks — macOS)

- (BOOL)textView:(NSTextView *)textView clickedOnLink:(id)link atIndex:(NSUInteger)charIndex
{
  NSString *urlString = nil;
  if ([link isKindOfClass:[NSURL class]]) {
    urlString = [(NSURL *)link absoluteString];
  } else if ([link isKindOfClass:[NSString class]]) {
    urlString = (NSString *)link;
  }

  if (!urlString)
    return NO;

  // Check custom "linkURL" attribute first
  NSAttributedString *attrText = ENRMGetAttributedText(textView);
  if (charIndex < attrText.length) {
    NSString *customURL = [attrText attribute:@"linkURL" atIndex:charIndex effectiveRange:NULL];
    if (customURL)
      urlString = customURL;
  }

  // Handle anchor links by scrolling natively
  if ([urlString hasPrefix:@"#"]) {
    [self scrollToAnchor:urlString];
  }

  // Emit to JS
  auto eventEmitter = std::static_pointer_cast<EnrichedMarkdownEventEmitter const>(_eventEmitter);
  if (eventEmitter) {
    eventEmitter->onLinkPress({.url = std::string([urlString UTF8String])});
  }

  return YES;
}
#endif

- (BOOL)isAccessibilityElement
{
  return NO;
}

- (NSArray *)accessibilityElements
{
  NSMutableArray *allElements = [NSMutableArray array];
  for (RCTUIView *segment in _segmentViews) {
    if ([segment isKindOfClass:[EnrichedMarkdownInternalText class]]) {
      NSArray *elements = [(EnrichedMarkdownInternalText *)segment accessibilityElements];
      if (elements) {
        [allElements addObjectsFromArray:elements];
      }
    } else if ([segment isKindOfClass:[TableContainerView class]]) {
      NSArray *elements = [(TableContainerView *)segment accessibilityElements];
      if (elements) {
        [allElements addObjectsFromArray:elements];
      }
    }
#if ENRICHED_MARKDOWN_MATH
    else if ([segment isKindOfClass:[ENRMMathContainerView class]]) {
      [allElements addObject:segment];
    }
#endif
  }
  return allElements;
}

- (NSInteger)accessibilityElementCount
{
  return [self accessibilityElements].count;
}

- (id)accessibilityElementAtIndex:(NSInteger)index
{
  NSArray *elements = [self accessibilityElements];
  if (index < 0 || index >= (NSInteger)elements.count) {
    return nil;
  }
  return elements[index];
}

- (NSInteger)indexOfAccessibilityElement:(id)element
{
  return [[self accessibilityElements] indexOfObject:element];
}

#if !TARGET_OS_OSX
- (NSArray<UIAccessibilityCustomRotor *> *)accessibilityCustomRotors
{
  return [MarkdownAccessibilityElementBuilder buildRotorsFromElements:[self accessibilityElements]];
}
#endif

@end
