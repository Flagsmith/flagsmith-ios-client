<img width="100%" src="https://raw.githubusercontent.com/SolidStateGroup/bullet-train-frontend/master/hero.png"/>

# Bullet Train SDK for iOS

> Bullet Train allows you to manage feature flags and remote config across multiple projects, environments and organisations.

The SDK for iOS applications for [https://bullet-train.io/](https://bullet-train.io/)

## Getting Started

## Quick Setup

The client library is available from the CocoaPods. Add the dependency to your `Podfile`:

```ruby
pod 'BulletTrainClient'
```

## Usage

**For full documentation visit [https://docs.bullet-train.io](https://docs.bullet-train.io)**

Sign Up and create account at [https://bullet-train.io/](https://www.bullet-train.io/)

Set your own API key in AppDelegate:

```swift
BulletTrain.shared.apiKey = "YOUR_API_KEY"
```

If you are using self-hosted solution also set your own URL:

 ```swift
BulletTrain.shared.baseURL = "https://domain.com/api/v1/"
```

**Retrieving feature flags for your project**

To check if feature flag exist and enabled:

```swift
BulletTrain.shared.hasFeatureFlag(withID: "my_test_feature") { (result) in
  switch result {
  case .success(let featureEnabled):
    if featureEnabled {
      // run the code to execute if the feature is enabled
    } else {
      // run the code if the feature is disabled
    }
  case .failure(let error):
    // run the code to handle error
  }
}
```

To get configuration value for feature flag:

```swift
BulletTrain.shared.getFeatureValue(withID: "my_test_feature") { (result) in
  switch result {
  case .success(let featureValue):
    // run the code to use remote config value
  case .failure(let error):
    // run the code to handle error
  }
}
```

**Identifying users**

Identifying users allows you to target specific users from the [Bullet Train dashboard](https://www.bullet-train.io/).

To check if feature exist for given user context:

```swift
BulletTrain.shared.hasFeatureFlag(withID: "my_test_feature", forIdentity: "bullet_train_user") { (result) in
  switch result {
  case .success(let featureEnabled):
    if featureEnabled {
      // run the code if the feature is enabled
    } else {
      // run the code if the feature is disabled
    }
  case .failure(let error):
    // run the code to handle error
  }
}
```

To get configuration value for feature flag for given user context:

```swift
BulletTrain.shared.getFeatureValue(withID: "my_test_feature", forIdentity: "bullet_train_user") { (result) in
  switch result {
  case .success(let featureValue):
    // run the code to use remote config value
  case .failure(let error):
    // run the code to handle error
  }
}
```

To get user traits for given user context:

```swift
BulletTrain.shared.getTraits(forIdentity: "bullet_train_user") { (result) in
  switch result {
  case .success(let traits):
    //  run the code to use user traits
  case .failure(let error):
    // run the code to handle error
  }
}
```

To get user trait for given user context and specific key:

```swift
BulletTrain.shared.getTrait(withID: "trait_key", forIdentity: "bullet_train_user") { (result) in
  switch result {
  case .success(let trait):
    if let trait = trait {
      //  run the code to use user trait
    } else {
      //  run the code without user trait
    }
  case .failure(let error):
    // run the code to handle error
  }
}
```

Or get user traits for given user context and specific keys:

```swift
BulletTrain.shared.getTraits(withIDS: ["trait_key", "another_trait_key"], forIdentity: "bullet_train_user") { (result) in
  switch result {
  case .success(let traits):
    //  run the code to use user traits
  case .failure(let error):
    // run the code to handle error
  }
}
```

To set trait for given user context:

```swift
let trait = Trait(key: "trait_key", value: "trait_value")

BulletTrain.shared.setTrait(trait, forIdentity: "bullet_train_user") { (result) in
  switch result {
  case .success(let trait):
    //  run the code if trait was set
  case .failure(let error):
    // run the code to handle error
  }
}
```

To retrieve a user identity (both features and traits):

```swift
BulletTrain.shared.getIdentity("bullet_train_user") { (result) in
  switch result {
  case .success(let identity):
    //  run the code to use identity
  case .failure(let error):
    // run the code to handle error
  }
}
```

## Contributing

Please read [CONTRIBUTING.md](https://gist.github.com/kyle-ssg/c36a03aebe492e45cbd3eefb21cb0486) for details on our code of conduct, and the process for submitting pull requests to us.

## Getting Help

If you encounter a bug or feature request we would like to hear about it. Before you submit an issue please search existing issues in order to prevent duplicates. 

## Get in touch

If you have any questions about our projects you can email <a href="mailto:projects@solidstategroup.com">projects@solidstategroup.com</a>.
