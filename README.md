![Logo](https://github.com/Stmol/vkphotos/blob/master/.readme/vk-photos-appstore-icon.jpg)

# VK Photos (formally Photos for VK)

![Swift 4.2](https://img.shields.io/badge/swift-4.2-orange.svg)
![Release Version](https://img.shields.io/badge/Release-1.1-blue.svg)
![GPL 3.0](https://img.shields.io/badge/license-GPL--3.0-lightgrey.svg)
[![App Store Available](https://img.shields.io/badge/app%20store-available-brightgreen.svg)](https://vk.cc/8xwT04)

VK Photos is an iOS app for manage albums and photos in social network VKontakte ([vk.com](https://vk.com))

## Screenshots

![Screenshot1](https://github.com/Stmol/vkphotos/blob/master/.readme/screen2.jpg)
![Screenshot2](https://github.com/Stmol/vkphotos/blob/master/.readme/screen1.jpg)
![Screenshot3](https://github.com/Stmol/vkphotos/blob/master/.readme/screen3.jpg)

## Disclaimer

- ⚠️ The repository contains tons of comments and todos in **Russian** language
- 🖼 I deleted all assets except App logo because the license agreements requires it
- 🔬 This source code is not for production and not for distribution. I shared it just for educational purposes

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
- You should add the compiled frameworks to your project manually
- Install Firebase SDK: [documentation](https://firebase.google.com/docs/ios/setup#frameworks) *(or just mute all Analytics calls, you probably dont need it)*
- Copy your `GoogleService-Info.plist` file to `VKPhotos/` source directory
- ...
- *and unfortunately no matter how perfect you are done you will not be able to run the application properly in the simulator*

## Why app doesn't display anything when running in simulator? (or just crash)

Because **VK Photos** app use many custom API calls.

To simplify the logic of the app in some places I wrote a lot of custom API methods using greate [execute](https://vk.com/dev/execute) method. These methods are stored on the VK API servers and accessible only to my VK application. For obvious reasons, these methods I can not disclose.

## TODO

- [ ] Describe the structure of the repository
- [ ] Add build scripts to installation instruction

## Credits

- [Serrata](https://github.com/horitaku46/Serrata) - Swift image gallery ([LICENSE](https://github.com/horitaku46/Serrata/blob/master/LICENSE))
- [Hydra](https://github.com/malcommac/Hydra) - Promises, Async & Await Library in Swift ([LICENSE](https://github.com/malcommac/Hydra/blob/master/LICENSE))
- [VK SDK](https://github.com/VKCOM/vk-ios-sdk) - iOS SDK for VK API ([LICENSE](https://github.com/VKCOM/vk-ios-sdk/blob/master/LICENSE))
- [RxSwift](https://github.com/ReactiveX/RxSwift) - Reactive Programming in Swift ([LICENSE](https://github.com/ReactiveX/RxSwift/blob/master/LICENSE.md))
- [Alamofire](https://github.com/Alamofire/Alamofire) - HTTP Networking in Swift ([LICENSE](https://github.com/Alamofire/Alamofire/blob/master/LICENSE))
- [DeepDiff](https://github.com/onmyway133/DeepDiff) - Diffing tool in Swift ([LICENSE](https://github.com/onmyway133/DeepDiff/blob/master/LICENSE.md))
- [UICircularProgressRing](https://github.com/luispadron/UICircularProgressRing) - Circular progress bar in Swift ([LICENSE](https://github.com/luispadron/UICircularProgressRing/blob/master/LICENSE))
- [SwifterSwift](https://github.com/SwifterSwift/SwifterSwift) -  Swift extensions to boost your productivity ([LICENSE](https://github.com/SwifterSwift/SwifterSwift/blob/master/LICENSE))
- [Kingfisher](https://github.com/onevcat/Kingfisher) - Downloading and caching images from the web ([LICENSE](https://github.com/onevcat/Kingfisher/blob/master/LICENSE))
- [Reachability](https://github.com/ashleymills/Reachability.swift) ([LICENSE](https://github.com/ashleymills/Reachability.swift/blob/master/LICENSE))
- [GSMessages](https://github.com/wxxsw/GSMessages) ([LICENSE](https://github.com/wxxsw/GSMessages/blob/master/LICENSE))
- [M13Checkbox](https://github.com/Marxon13/M13Checkbox) ([LICENSE](https://github.com/Marxon13/M13Checkbox/blob/master/LICENSE))
- [BEMCheckBox](https://github.com/Boris-Em/BEMCheckBox) ([LICENSE](https://github.com/Boris-Em/BEMCheckBox/blob/master/LICENSE))
- [PKHUD](https://github.com/pkluz/PKHUD) ([LICENSE](https://github.com/pkluz/PKHUD/blob/master/LICENSE))
- [STLoadingGroup](https://github.com/saitjr/STLoadingGroup) ([LICENSE](https://github.com/saitjr/STLoadingGroup/blob/master/LICENSE))
- [Spring](https://github.com/MengTo/Spring) ([LICENSE](https://github.com/MengTo/Spring/blob/master/LICENSE))

## Author

Developed by **Yury Smidovich**.

I'm independent iOS and backend developer. Feel free to [contact me](https://t.me/Deviant).

I will be glad to collaboration. Or you can [hire me](https://www.linkedin.com/in/yury-smidovich-339710103/).

## License

VK Photos is available under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for more info.
