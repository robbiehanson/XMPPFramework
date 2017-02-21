
![XMPPFramework](xmppframework.png)

## XMPPFramework
[![Build Status](https://travis-ci.org/robbiehanson/XMPPFramework.svg?branch=master)](https://travis-ci.org/robbiehanson/XMPPFramework) [![Version Status](https://img.shields.io/cocoapods/v/XMPPFramework.svg?style=flat)](https://github.com/robbiehanson/XMPPFramework) [![Platform](https://img.shields.io/cocoapods/p/XMPPFramework.svg?style=flat)](https://cocoapods.org/?q=XMPPFramework) [![License (3-Clause BSD)](https://img.shields.io/badge/license-BSD%203--Clause-orange.svg?style=flat)](http://opensource.org/licenses/BSD-3-Clause)


An XMPP Framework in Objective-C for the Mac and iOS development community.

### Abstract
XMPPFramework provides a core implementation of RFC-3920 (the XMPP standard), along with the tools needed to read & write XML. It comes with multiple popular extensions (XEP's), all built atop a modular architecture, allowing you to plug-in any code needed for the job. Additionally the framework is massively parallel and thread-safe. Structured using GCD, this framework performs well regardless of whether it's being run on an old iPhone, or on a 12-core Mac Pro. (And it won't block the main thread... at all)

### Install

The minimum deployment target is iOS 8.0 / macOS 10.9.

#### CocoaPods

The easiest way to install XMPPFramework is using CocoaPods. Remember to add to the top of your `Podfile` the `use_frameworks!` line (even if you are not using swift):

This will install the whole framework with all the available extensions:

```ruby
use_frameworks!
pod 'XMPPFramework', '~> 3.7.0'
```

After `pod install` open the `.xcworkspace` and import:

```
import XMPPFramework      // swift
@import XMPPFramework;   //objective-c
```

#### Carthage

Carthage is currently not supported because it's blocking on the following dependencies:

* libidn: [Issue #3](https://github.com/chrisballinger/libidn-podspec/pull/3)

### Wiki:
For more info please take a look at the wiki.

- [Overview of the XMPP Framework](https://github.com/robbiehanson/XMPPFramework/wiki/IntroToFramework)
- [Getting started using XMPPFramework on Mac OS X](https://github.com/robbiehanson/XMPPFramework/wiki/GettingStarted_Mac)
- [Getting started using XMPPFramework on iOS](https://github.com/robbiehanson/XMPPFramework/wiki/GettingStarted_iOS)
- [XEPs supported by the XMPPFramework](https://github.com/robbiehanson/XMPPFramework/wiki/XEPs)
- [Learn more about XMPPFramework](https://github.com/robbiehanson/XMPPFramework/wiki)


Can't find the answer to your question in any of the [wiki](https://github.com/robbiehanson/XMPPFramework/wiki) articles? Try the [mailing list](http://groups.google.com/group/xmppframework). 

Love the project? Wanna buy me a ☕️? (or a 🍺 😀):

[![donation-bitcoin](https://bitpay.com/img/donate-sm.png)](https://onename.com/robbiehanson)
[![donation-paypal](https://www.paypal.com/en_US/i/btn/btn_donate_SM.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=CV6XGZTPQU9HY)

