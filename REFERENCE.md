# Reference
This provides a reference for all of the Approov related methods defined in the plugin. These are available if you import:

```Typescript
import { HTTP } from '@awesome-cordova-plugins/approov-advanced-http';
```

or for Angular:

```Typescript
import { HTTP } from '@awesome-cordova-plugins/approov-advanced-http/ngx';
```

It is assumed a local instance of `HTTP` is defined in the component with:

```Typescript
private http = HTTP;
```

Many of the methods execute asynchronously and return a `Promise`. This is resolved to indicate success, or rejected with an `error` otherwise. The `error` is a map that provides:

* `message`: A descriptive error message.
* `type`: Type of the error which may be `general`, `network` or `rejection`. If the type is `network` then this indicates that the error was caused by a temporary networking issue, so an option should be provided to the user to retry.
* `rejectionARC`: Only provided for a `rejection` error type. Provides the [Attestation Response Code](https://approov.io/docs/latest/approov-usage-documentation/#attestation-response-code), which could be provided to the user for communication with your app support to determine the reason for failure, without this being revealed to the end user.
* `rejectionReasons`: Only provided for a `rejection` error type. If the [Rejection Reasons](https://approov.io/docs/latest/approov-usage-documentation/#rejection-reasons) feature is enabled, this provides a comma separated list of reasons why the app attestation was rejected.

## Initialize
Initializes the Approov SDK and thus enables the Approov features. The `config` will have been provided in the initial onboarding or email or can be [obtained](https://approov.io/docs/latest/approov-usage-documentation/#getting-the-initial-sdk-configuration) using the Approov CLI. This will generate an error if a second attempt is made at initialization with a different `config`.

```Javascript
http.approovInitialize(config: string): Promise<void>;
```

Note that the initialization should be performed as soon as the app starts, and before any network requests that require Approov protection. The returned `Promise` is resolved when the initialization is complete, and rejected if there was a problem with initialization.

## SetProceedOnNetworkFail
Indicates that the network interceptor should proceed anyway if it is not possible to obtain an Approov token due to a networking failure. If this is called then the backend API can receive calls without the expected Approov token header being added, or without header/query parameter substitutions being made. This should only ever be used if there is some particular reason, perhaps due to local network conditions, that you believe that traffic to the Approov cloud service will be particularly problematic.

```Javascript
http.approovSetProceedOnNetworkFail(): void;
```

Note that this should be used with *CAUTION* because it may allow a connection to be established before any dynamic pins have been received via Approov, thus potentially opening the channel to a MitM.

## setDevKey
[Sets a development key](https://approov.io/docs/latest/approov-usage-documentation/#using-a-development-key) in order to force an app to be passed. This can be used if the app has to be resigned in a test environment and would thus fail attestation otherwise.

```Javascript
http.approovSetDevKey(devKey: string): void;
```

## SetTokenHeader
Sets the header that the Approov token is added on, as well as an optional prefix String (such as "`Bearer `"). Pass in an empty string if you do not wish to have a prefix. By default the token is provided on `Approov-Token` with no prefix.

```Javascript
http.approovSetTokenHeader(header: string, prefix: string): void;
```

## SetBindingHeader
Sets a binding `header` that may be present on requests being made. This is for the [token binding](https://approov.io/docs/latest/approov-usage-documentation/#token-binding) feature. A header should be chosen whose value is unchanging for most requests (such as an Authorization header). If the `header` is present, then a hash of the `header` value is included in the issued Approov tokens to bind them to the value. This may then be verified by the backend API integration.

```Javascript
http.approovSetBindingHeader(header: string): void;
```

## AddSubstitutionHeader
Adds the name of a `header` which should be subject to [secure strings](https://approov.io/docs/latest/approov-usage-documentation/#secure-strings) substitution. This means that if the `header` is present then the value will be used as a key to look up a secure string value which will be substituted into the `header` value instead. This allows easy migration to the use of secure strings. A `requiredPrefix` may be specified to deal with cases such as the use of "`Bearer `" prefixed before values in an authorization header. If this is not required then simply use an empty string.

```Javascript
http.approovAddSubstitutionHeader(header: string, requiredPrefix: string): void;
```

## RemoveSubstitutionHeader
Removes a `header` previously added using `approovAddSubstitutionHeader`.

```Javascript
http.approovRemoveSubstitutionHeader(header: string): void;
```

## AddSubstitutionQueryParam
Adds a `key` name for a query parameter that should be subject to [secure strings](https://approov.io/docs/latest/approov-usage-documentation/#secure-strings) substitution. This means that if the query parameter is present in a URL then the value will be used as a key to look up a secure string value which will be substituted as the query parameter value instead. This allows easy migration to the use of secure strings.

```Javascript
http.approovAddSubstitutionQueryParam(key: string): void;
```

## RemoveSubstitutionQueryParam
Removes a query parameter `key` name previously added using `approovAddSubstitutionQueryParam`.

```Javascript
http.approovRemoveSubstitutionQueryParam(key: string): void;
```

## AddExclusionURLRegex
Adds an exclusion URL [regular expression](https://regex101.com/) via the `urlRegex` parameter. If a URL for a request matches this regular expression then it will not be subject to any Approov protection.

```Javascript
http.approovAddExclusionURLRegex(urlRegex: string): void;
```

Note that this facility must be used with *EXTREME CAUTION* due to the impact of dynamic pinning. Pinning may be applied to all domains added using Approov, and updates to the pins are received when an Approov fetch is performed. If you exclude some URLs on domains that are protected with Approov, then these will be protected with Approov pins but without a path to update the pins until a URL is used that is not excluded. Thus you are responsible for ensuring that there is always a possibility of calling a non-excluded URL, or you should make an explicit call to fetchToken if there are persistent pinning failures. Conversely, use of those option may allow a connection to be established before any dynamic pins have been received via Approov, thus potentially opening the channel to a MitM.

## RemoveExclusionURLRegex
Removes an exclusion URL regular expression `urlRegex` previously added using `approovAddExclusionURLRegex`.

```Javascript
http.approovRemoveExclusionURLRegex(urlRegex: string): void;
```

## Prefetch
Performs a background fetch to lower the effective latency of a subsequent token fetch or secure string fetch by starting the operation earlier so the subsequent fetch may be able to use cached data.

```Javascript
http.prefetch(): Promise<void>;
```

The returned `Promise` is rejected if the `prefetch` failed.

## Precheck
Performs a precheck to determine if the app will pass attestation. This requires [secure strings](https://approov.io/docs/latest/approov-usage-documentation/#secure-strings) to be enabled for the account, although no strings need to be set up. This will likely require network access so may take some time to complete.

```Javascript
http.approovPrecheck(): Promise<void>;
```

The returned `Promise` is rejected if the `precheck` failed.

## GetDeviceID
Gets the [device ID](https://approov.io/docs/latest/approov-usage-documentation/#extracting-the-device-id) used by Approov to identify the particular device that the SDK is running on. Note that different Approov apps on the same device will return a different ID. Moreover, the ID may be changed by an uninstall and reinstall of the app.

```Javascript
http.approovGetDeviceID(): Promise<String>;
```

## SetDataHashInToken
Directly sets the [token binding](https://approov.io/docs/latest/approov-usage-documentation/#token-binding) hash from the given `data` to be included in subsequently fetched Approov tokens. If the hash is different from any previously set value then this will cause the next token fetch operation to fetch a new token with the correct payload data hash. The hash appears in the `pay` claim of the Approov token as a base64 encoded string of the SHA256 hash of the data. Note that the data is hashed locally and never sent to the Approov cloud service. This is an alternative to using `SetBindingHeader` and you should not use both methods at the same time.

```Javascript
http.approovSetDataHashInToken(data: string): Promise<void>;
```

## FetchToken
Performs an Approov token fetch for the given `url`. This should be used in situations where it is not possible to use the networking interception to add the token. This will likely require network access so may take some time to complete.

```Javascript
http.approovFetchToken(url: string): Promise<String>;
```

The returned `Promise` is rejected if there was a problem fetching the token.

## GetMessageSignature
Gets the [message signature](https://approov.io/docs/latest/approov-usage-documentation/#message-signing) for the given `message`. This uses an account specific message signing key that is transmitted to the SDK after a successful fetch if the facility is enabled for the account. Note that if the attestation failed then the signing key provided is actually random so that the signature will be incorrect. An Approov token should always be included in the message being signed and sent alongside this signature to prevent replay attacks.

```Javascript
http.approovGetMessageSignature(message: string): Promise<String>;
```

The returned `Promise` may be rejected if no previous Approov token has been fetched.

## FetchSecureString
Fetches a [secure string](https://approov.io/docs/latest/approov-usage-documentation/#secure-strings) with the given `key`. If `newDef` is not `null` then a secure string for the particular app instance may be defined. In this case the new value is returned as the secure string. Use of an empty string for `newDef` removes the string entry. Note that the returned string should NEVER be cached by your app, you should call this function when it is needed.

```Javascript
http.approovFetchSecureString(key: string, newDef: string): Promise<String>;
```

The returned `Promise` may provide a resolved `null` if the `key` is not defined. The returned `Promise` is rejected if the device fails attestation.

## FetchCustomJWT
Fetches a [custom JWT](https://approov.io/docs/latest/approov-usage-documentation/#custom-jwts) with the given marshaled JSON `payload`.

```Javascript
http.approovFetchCustomJWT(payloa: string): Promise<String>;
```

The returned `Promise` is rejected if the device fails attestation.
