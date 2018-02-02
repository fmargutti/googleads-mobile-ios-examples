// Copyright (C) 2015 Google, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "ViewController.h"

// Native Advanced ad unit ID for testing.
static NSString *const TestAdUnit = @"ca-app-pub-3940256099942544/3986624511";

@interface ViewController () <GADUnifiedNativeAdLoaderDelegate, GADVideoControllerDelegate>

/// You must keep a strong reference to the GADAdLoader during the ad loading
/// process.
@property(nonatomic, strong) GADAdLoader *adLoader;

/// The native ad view that is being presented.
@property(nonatomic, strong) GADUnifiedNativeAdView *nativeAdView;

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.versionLabel.text = [GADRequest sdkVersion];

  NSArray *nibObjects =
      [[NSBundle mainBundle] loadNibNamed:@"UnifiedNativeAdView" owner:nil options:nil];
  [self setAdView:[nibObjects firstObject]];
  [self refreshAd:nil];
}

- (IBAction)refreshAd:(id)sender {
  // Loads an ad for unified native ad.
  self.refreshButton.enabled = NO;

  GADVideoOptions *videoOptions = [[GADVideoOptions alloc] init];
  videoOptions.startMuted = self.startMutedSwitch.on;

  self.adLoader = [[GADAdLoader alloc] initWithAdUnitID:TestAdUnit
                                     rootViewController:self
                                                adTypes:@[ kGADAdLoaderAdTypeUnifiedNative ]
                                                options:@[ videoOptions ]];
  self.adLoader.delegate = self;
  [self.adLoader loadRequest:[GADRequest request]];
  self.videoStatusLabel.text = @"";
}

- (void)setAdView:(UIView *)view {
  // Remove previous ad view.
  [self.nativeAdView removeFromSuperview];
  self.nativeAdView = view;

  // Add new ad view and set constraints to fill its container.
  [self.nativeAdPlaceholder addSubview:view];
  [self.nativeAdView setTranslatesAutoresizingMaskIntoConstraints:NO];

  NSDictionary *viewDictionary = NSDictionaryOfVariableBindings(_nativeAdView);
  [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_nativeAdView]|"
                                                                    options:0
                                                                    metrics:nil
                                                                      views:viewDictionary]];
  [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_nativeAdView]|"
                                                                    options:0
                                                                    metrics:nil
                                                                      views:viewDictionary]];
}

/// Gets an image representing the number of stars. Returns nil if rating is
/// less than 3.5 stars.
- (UIImage *)imageForStars:(NSDecimalNumber *)numberOfStars {
  double starRating = numberOfStars.doubleValue;
  if (starRating >= 5) {
    return [UIImage imageNamed:@"stars_5"];
  } else if (starRating >= 4.5) {
    return [UIImage imageNamed:@"stars_4_5"];
  } else if (starRating >= 4) {
    return [UIImage imageNamed:@"stars_4"];
  } else if (starRating >= 3.5) {
    return [UIImage imageNamed:@"stars_3_5"];
  } else {
    return nil;
  }
}

#pragma mark GADAdLoaderDelegate implementation

- (void)adLoader:(GADAdLoader *)adLoader didFailToReceiveAdWithError:(GADRequestError *)error {
  NSLog(@"%@ failed with error: %@", adLoader, error);
  self.refreshButton.enabled = YES;
}

#pragma mark GADUnifiedNativeAdLoaderDelegate implementation

- (void)adLoader:(GADAdLoader *)adLoader didReceiveUnifiedNativeAd:(GADUnifiedNativeAd *)nativeAd {
  self.refreshButton.enabled = YES;

  GADUnifiedNativeAdView *nativeAdView = self.nativeAdView;
  nativeAdView.nativeAd = nativeAd;

  // Populate the native ad view with the native ad assets.
  // Some assets are guaranteed to be present in every native ad.
  ((UILabel *)nativeAdView.headlineView).text = nativeAd.headline;
  ((UILabel *)nativeAdView.bodyView).text = nativeAd.body;
  [((UIButton *)nativeAdView.callToActionView)setTitle:nativeAd.callToAction
                                              forState:UIControlStateNormal];

  // Some native ads will include a video asset, while others do not. Apps can
  // use the GADVideoController's hasVideoContent property to determine if one
  // is present, and adjust their UI accordingly.

  // The UI for this controller constrains the image view's height to match the
  // media view's height, so by changing the one here, the height of both views
  // are being adjusted.
  if (nativeAd.videoController.hasVideoContent) {
    // The video controller has content. Show the media view.
    nativeAdView.mediaView.hidden = NO;
    nativeAdView.imageView.hidden = YES;

    // This app uses a fixed width for the GADMediaView and changes its height
    // to match the aspect ratio of the video it displays.
    NSLayoutConstraint *heightConstraint =
        [NSLayoutConstraint constraintWithItem:nativeAdView.mediaView
                                     attribute:NSLayoutAttributeHeight
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:nativeAdView.mediaView
                                     attribute:NSLayoutAttributeWidth
                                    multiplier:(1 / nativeAd.videoController.aspectRatio)
                                      constant:0];
    heightConstraint.active = YES;

    // By acting as the delegate to the GADVideoController, this ViewController
    // receives messages about events in the video lifecycle.
    nativeAd.videoController.delegate = self;

    self.videoStatusLabel.text = @"Ad contains a video asset.";
  } else {
    // If the ad doesn't contain a video asset, the first image asset is shown
    // in the image view. The existing lower priority height constraint is used.
    nativeAdView.mediaView.hidden = YES;
    nativeAdView.imageView.hidden = NO;

    GADNativeAdImage *firstImage = nativeAd.images.firstObject;
    ((UIImageView *)nativeAdView.imageView).image = firstImage.image;

    self.videoStatusLabel.text = @"Ad does not contain a video.";
  }

  // These assets are not guaranteed to be present, and should be checked first.
  ((UIImageView *)nativeAdView.iconView).image = nativeAd.icon.image;
  if (nativeAd.icon != nil) {
    nativeAdView.iconView.hidden = NO;
  } else {
    nativeAdView.iconView.hidden = YES;
  }

  ((UIImageView *)nativeAdView.starRatingView).image = [self imageForStars:nativeAd.starRating];
  if (nativeAd.starRating) {
    nativeAdView.starRatingView.hidden = NO;
  } else {
    nativeAdView.starRatingView.hidden = YES;
  }

  ((UILabel *)nativeAdView.storeView).text = nativeAd.store;
  if (nativeAd.store) {
    nativeAdView.storeView.hidden = NO;
  } else {
    nativeAdView.storeView.hidden = YES;
  }

  ((UILabel *)nativeAdView.priceView).text = nativeAd.price;
  if (nativeAd.price) {
    nativeAdView.priceView.hidden = NO;
  } else {
    nativeAdView.priceView.hidden = YES;
  }

  ((UILabel *)nativeAdView.advertiserView).text = nativeAd.advertiser;
  if (nativeAd.advertiser) {
    nativeAdView.advertiserView.hidden = NO;
  } else {
    nativeAdView.advertiserView.hidden = YES;
  }

  // In order for the SDK to process touch events properly, user interaction
  // should be disabled.
  nativeAdView.callToActionView.userInteractionEnabled = NO;
}

#pragma mark GADVideoControllerDelegate implementation

- (void)videoControllerDidEndVideoPlayback:(GADVideoController *)videoController {
  self.videoStatusLabel.text = @"Video playback has ended.";
}

@end
