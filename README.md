<img width="100%" src="https://github.com/Flagsmith/flagsmith/raw/main/static-files/hero.png"/>

# Flagsmith iOS SDK

> Flagsmith allows you to manage feature flags and remote config across multiple projects, environments and organisations.

The SDK for iOS and Swift applications for [https://www.flagsmith.com/](https://www.flagsmith.com/).

## Adding to your project

Add the package in Xcode via *File > Add Package Dependencies*, or in `Package.swift`:

```swift
.package(url: "https://github.com/Flagsmith/flagsmith-ios-client.git", from: "3.13.0")
```

For full documentation visit [https://docs.flagsmith.com/clients/ios/](https://docs.flagsmith.com/clients/ios/)

### CocoaPods

CocoaPods is no longer supported. [CocoaPods trunk stopped accepting new versions on 2 December 2026](https://blog.cocoapods.org/CocoaPods-Specs-Repo/), so `FlagsmithClient` is frozen there at **3.13.0**.

Existing `pod install` and `pod update` runs will keep resolving 3.13.0 and earlier indefinitely, but no new releases will be published to trunk. Use Swift Package Manager to receive updates.

## Contributing

Please read [CONTRIBUTING.md](https://gist.github.com/kyle-ssg/c36a03aebe492e45cbd3eefb21cb0486) for details on our code of conduct, and the process for submitting pull requests.

We use [SwiftLint](https://github.com/realm/SwiftLint) and [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) to keep our code consistent.

To run `swiftformat` on the project run the following command:

    swift package plugin swiftformat

To run `swiftlint` on the project please check out the documentation above to install the linter with your preferred method of integration. The linter will run on the project when the PR is raised, so it's worth checking beforehand.

## Getting Help

If you encounter a bug or feature request we would like to hear about it. Before you submit an issue please search existing issues in order to prevent duplicates.

## Get in touch

If you have any questions about our projects you can email <a href="mailto:support@flagsmith.com">support@flagsmith.com</a>.

## Useful links

[Website](https://www.flagsmith.com/)

[Documentation](https://docs.flagsmith.com/)
