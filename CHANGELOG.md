Changelog
=========

**Version 0.12.0 - Feb 2, 2014**

Renamed twitter-related signup methods. The class formerly called `BBTwitterLoginViewController` is now `BBTwitterSignupViewController`. The method to create such controller is now named `[Backbeam twitterSignupViewController]` and the view controller no longer uses a .xib file under the hood.

The `BBTwitterProgress` enumeration and its values have also been renamed.

* `BBTwitterProgress` to `BBSocialSignupProgress`
* `BBTwitterProgressLoadingAuthorizationPage` to `BBSocialSignupProgressLoadingAuthorizationPage`.
* `BBTwitterProgressLoadedAuthorizationPage` to `BBSocialSignupProgressLoadedAuthorizationPage`.
* `BBSocialSignupProgressAuthorizating` to `BBSocialSignupProgressRedirecting`.

Additionally new authentication methods have been added: LinkedIn and GitHub. So there are two new UIWebView-based ViewControllers like the Twitter and `BBObject` has new methods to read profile information of users who sign up with these new authentication mehtods.
