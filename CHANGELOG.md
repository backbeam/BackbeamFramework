Changelog
=========

**Version 1.0.0 - May 11, 2014**

Added `BBFetchPolicyRemoteAndStore` to the list of available fetch policies. This new policy requests the data to the server and then updates the local cache.

Fixed a problem with `[BBObject imageWithSize:...]`

**Version 0.12.1 - Mar 3, 2014**

`AFNetworking` updated to 2.1.3. So iOS5 and OSX 10.7 are no longer supported.

**Version 0.12.0 - Feb 20, 2014**

Renamed twitter-related signup methods. The class formerly called `BBTwitterLoginViewController` is now `BBTwitterSignupViewController`. The method to create such controller is now named `[Backbeam twitterSignupViewController]` and the view controller no longer uses a .xib file under the hood.

The `BBTwitterProgress` enumeration and its values have also been renamed.

* `BBTwitterProgress` to `BBSocialSignupProgress`
* `BBTwitterProgressLoadingAuthorizationPage` to `BBSocialSignupProgressLoadingAuthorizationPage`.
* `BBTwitterProgressLoadedAuthorizationPage` to `BBSocialSignupProgressLoadedAuthorizationPage`.
* `BBSocialSignupProgressAuthorizating` to `BBSocialSignupProgressRedirecting`.

Additionally new authentication methods have been added: LinkedIn and GitHub. So there are two new UIWebView-based ViewControllers like the Twitter and `BBObject` has new methods to read profile information of users who sign up with these new authentication mehtods.
