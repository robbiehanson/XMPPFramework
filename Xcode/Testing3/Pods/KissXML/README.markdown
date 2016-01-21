KissXML provides a drop-in replacement for Apple's NSXML class culster in environments without NSXML (e.g. iOS).

It is implemented atop the defacto libxml2 C library, which comes pre-installed on Mac & iOS.
But it shields you from all the nasty low-level C pointers and malloc's, and provides an easy-to-use Objective-C library.

It is designed for speed and reliability, so it's read-access thread-safe and will "just-work".
That is, KissXML provides an API that follows "what-you-would-expect" rules from an Objective-C library.
So feel free to do things like parallel processing of an xml document using blocks.
It will "just work" so you can get back to designing the rest of your app.

KissXML is a mature library used in thousands of products. It's also used in other libraries, such as [XMPPFramework](http://code.google.com/p/xmppframework/) (an objective-c library for real-time xml streaming). It's even used in hospital applications.

KissXML was inspired by the TouchXML project, but was created to add full support for generating XML as well as supporting the entire NSXML API.

**[Get started using KissXML](https://github.com/robbiehanson/KissXML/wiki/GettingStarted)**<br/>
**[Learn more about KissXML](https://github.com/robbiehanson/KissXML/wiki)**<br/>

<br/>
Can't find the answer to your question in any of the [wiki](https://github.com/robbiehanson/KissXML/wiki) articles? Try the **[mailing list](http://groups.google.com/group/kissxml)**.
<br/>
<br/>
Love the project? Wanna buy me a coffee? (or a beer :D) [![donation](http://www.paypal.com/en_US/i/btn/btn_donate_SM.gif)](https://www.paypal.com/us/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=9404739)
