![Logo](https://github.com/Stmol/vkphotos/blob/master/.readme/vk-photos-appstore-icon.jpg)

# VK Photos (formally Photos for VK)

![Swift 4.2](https://img.shields.io/badge/swift-4.2-orange.svg)
![Release Version](https://img.shields.io/badge/Release-1.1-blue.svg)
[![App Store Available](https://img.shields.io/badge/app%20store-available-brightgreen.svg)](https://vk.cc/8xwT04)

VK Photos is an iOS app for manage albums and photos in social network VKontakte (vk.com).

## Screenshots

![Screenshot1](https://github.com/Stmol/vkphotos/blob/master/.readme/screen2.jpg)
![Screenshot2](https://github.com/Stmol/vkphotos/blob/master/.readme/screen1.jpg)
![Screenshot3](https://github.com/Stmol/vkphotos/blob/master/.readme/screen3.jpg)

## Disclaimer

- ⚠️  The repository contains tons of comments and todos in **Russian** language
- 🚫  I deleted all assets except App logo because the license requires it
- 🔬  This source code is not for production and not for distribution. I made it just for educational purposes

## Requirements

- Xcode 9 and later
- iOS 11 and later
- Swift 4 and later
- [Carthage](https://github.com/Carthage/Carthage)

## Try App

You can try **VK Photos** by downloading the app to your iPhone from App Store. It's **free** (*iOS 11+ required*)

[![AppStore Link](https://github.com/Stmol/vkphotos/blob/master/.readme/app-store-badge.jpg)](https://vk.cc/8xwT04)

## Installation

- Create VK application: [vk.com](https://vk.com/editapp?act=create)
- Obtain your VK app ID and insert it into `AppDelegate.swift`
- Run Carthage: ```$ carthage update --platform ios```
- Install Firebase SDK: [documentation](https://firebase.google.com/docs/ios/setup#frameworks) *(or just mute all Analytics calls, you probably dont need it)*
- ...
- *and unfortunately no matter how perfect you are all done you will not be able to run the application in the simulator*

## Why app doesn't display anything when running in simulator? (or just crash)

Because **VK Photos** app use many custom API calls.

To simplify the logic of the app in some places I wrote a lot of custom API using greate [execute](https://vk.com/dev/execute) method. These methods are stored on the VK API servers and accessible only to my VK application. For obvious reasons, these methods I can not disclose.

## Author

Developed by Yury Smidovich.

## License

VK Photos is available under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for more info.