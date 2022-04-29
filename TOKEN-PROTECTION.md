# Token Protection
You should use this option if you wish to protect access to your APIs using an Approov token. We recommend this approach where it is possible to modify the backend API implementation to perform the token verification. Various [Backend API Quickstarts](https://approov.io/docs/latest/approov-integration-examples/backend-api/) are available to suit your particular situation depending on the backend technology used. You will need to implement this in addition to the steps in this frontend guide.

These steps require access to the [Approov CLI](https://approov.io/docs/latest/approov-cli-tool-reference/), please follow the [Installation](https://approov.io/docs/latest/approov-installation/) instructions.

## ADDING API DOMAINS
In order for Approov tokens to be added by the interceptor for particular API domains it is necessary to inform Approov about them. Execute the following command:

```
approov api -add <your-domain>
```
Approov tokens will then be added automatically to any requests to that domain (using the `Approov-Token` header, by default).

Note that this will also add a public key certicate pin for connections to the domain to ensure that no Man-in-the-Middle attacks on your app's communication are possible. Please read [Managing Pins](https://approov.io/docs/latest/approov-usage-documentation/#public-key-pinning-configuration) to understand this in more detail.

## REGISTERING APPS
In order for Approov to recognize the app as being valid it needs to be registered with the service. Change the directory to the top level of your app project and then register the app with Approov:

For Android:

```
cordova build android
approov registration -add platforms/android/app/build/outputs/apk/debug/app-debug.apk
```

Note, on Windows you need to substitute \ for / in the above commands.

For iOS:

```
cordova build ios
approov registration -add platforms/ios/build/device/CordovaApproovShapes.ipa -bitcode
```

Note, the `-bitcode` option must be used because the Cordova plugin uses the bitcode variant of the Approov SDK. If you are building and running on an iOS simulator then there will be no `.ipa` file and you must ensure the app [always passes](https://approov.io/docs/latest/approov-usage-documentation/#adding-a-device-security-policy) on your simulator without needing to perform a registration.

> **IMPORTANT:** The registration takes up to 30 seconds to propagate across the Approov Cloud Infrastructure, therefore don't try to run the app again before this time has elapsed. During development of your app you can ensure it [always passes](https://approov.io/docs/latest/approov-usage-documentation/#adding-a-device-security-policy) on your device to not have to register the app each time you modify it.

[Managing Registrations](https://approov.io/docs/latest/approov-usage-documentation/#managing-registrations) provides more details for app registrations, especially for releases to the Play Store. Note that you may also need to apply specific [Android Obfuscation](https://approov.io/docs/latest/approov-usage-documentation/#android-obfuscation) rules for your app when releasing it.

## FURTHER OPTIONS

See [Getting Started With Approov](https://approov.io/docs/latest/approov-usage-documentation/#getting-started-with-approov) for information about additional Approov features you may wish to try.

The quickstart also provides the following additional methods:

### Changing Approov Token Header Name
The default header name of `Approov-Token` can be changed as follows:

```Javascript
cordova.plugin.http.approovSetTokenHeader("Authorization", "Bearer ")
```

The first parameter is the new header name and the second a prefix to be added to the Approov token. This is primarily for integrations where the Approov Token JWT might need to be prefixed with `Bearer` and passed in the `Authorization` header.

### Token Binding
If want to use [Token Binding](https://approov.io/docs/latest/approov-usage-documentation/#token-binding) then set the header holding the value to be used for binding as follows:

```Javascript
cordova.plugin.http.approovSetBindingHeader("Authorization")
```

In this case it means that the value of `Authorization` holds the token value to be bound. This only needs to be called once. On subsequent requests the value of the specified header is read and its value set as the token binding value. Note that you should select a header whose value does not typically change from request to request, as each change requires a new Approov token to be fetched.

### Prefetching
If you wish to reduce the latency associated with fetching the first Approov token, then make this call immediately after initializing Approov in the plugin:

```Javascript
cordova.plugin.http.approovPrefetch(
    () => {
        // success function
    },
    (err) -> {
        // failure function
    }
```

This initiates the process of fetching an Approov token in the background, so that a cached token is available immediately when subsequently needed, or at least the fetch time is reduced. When the prefetch is finished then either the provided success or failure function will be called, depending upon the result. Note that there is no point in performing a prefetch if you are using token binding.

### Prechecking
You may wish to do an early check in your to present a warning to the user if the app is not going to be able to obtain valid Approov tokens because it fails the attestation process. To do this you first need to enable the [Secure Strings](https://approov.io/docs/latest/approov-usage-documentation/#secure-strings) feature:

```
approov secstrings -setEnabled
```

> Note that this command requires an [admin role](https://approov.io/docs/latest/approov-usage-documentation/#account-access-roles).

Here is an example of calling the appropriate method:

```Javascript
cordova.plugin.http.approovPrecheck(
    () => {
        // success function - the precheck completed okay
    },
    (err) -> {
        if (err.type == "rejection")
            // failure due to the attestation being rejected, err.rejectionARC and err.rejectionReasons may be used to present information to the user
            // (note err.rejectionReasons is only available if the feature is enabled, otherwise it is always an empty string)
        else if (err.type == "network")
            // failure due to a potentially temporary networking issue, allow for a user initiated retry
        else
            // a more permanent error, see err.message
    }
```

This performs the operation in the backgrouund, and then either the provided success or failure function will be called.

> Note you should NEVER use this as the only form of protection in your app, this is simply to provide an early indication of failure to your users as a convenience. You must always also have APIs protected with Approov tokens that are essential to the operation of your app. This is because, although the Approov attestation itself is heavily secured, it may be possible for an attacker to bypass its result or prevent it being called at all. When the app is dependent Approov protected APIs they can never be accessed without passing the attestation, since it is not possible for an attacker to create a validly signed Approov token.

If you wish to provide more direct feedback with the [Rejection Reasons](https://approov.io/docs/latest/approov-usage-documentation/#rejection-reasons) feature use:

```
approov policy -setRejectionReasons on
```

> Note that this command requires an [admin role](https://approov.io/docs/latest/approov-usage-documentation/#account-access-roles).