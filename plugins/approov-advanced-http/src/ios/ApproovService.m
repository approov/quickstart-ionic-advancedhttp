/*
 * Copyright (c) 2018-2021 CriticalBlue Ltd.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
 * documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
 * WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
 * OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "ApproovService.h"
#import "SM_AFHTTPSessionManager.h"
#import "SM_AFSecurityPolicy.h"
#import "SM_AFURLSessionManager.h"
#import <Approov/Approov.h>
#import <CommonCrypto/CommonDigest.h>
#import "CordovaHttpPlugin.h"
#import <objc/runtime.h>
#import "TextResponseSerializer.h"


// Extend the SM_AFURLSessionManager interface so that the challenge block variables are accessible in order to perform the dynamic pinning
@interface SM_AFURLSessionManager(Protected)

typedef NSURLSessionAuthChallengeDisposition (^AFURLSessionDidReceiveAuthenticationChallengeBlock)(NSURLSession *session, NSURLAuthenticationChallenge *challenge, NSURLCredential **credential);
typedef NSURLSessionAuthChallengeDisposition (^AFURLSessionTaskDidReceiveAuthenticationChallengeBlock)(NSURLSession *session, NSURLSessionTask *task, NSURLAuthenticationChallenge *challenge, NSURLCredential **credential);

// Make SM_AFURLSessionManager's taskDidReceiveAuthenticationChallenge instance variable accessible
@property (readwrite, nonatomic, copy) AFURLSessionTaskDidReceiveAuthenticationChallengeBlock taskDidReceiveAuthenticationChallenge;

// Make SM_AFURLSessionManager's sessionDidReceiveAuthenticationChallenge instance variable accessible
@property (readwrite, nonatomic, copy) AFURLSessionDidReceiveAuthenticationChallengeBlock sessionDidReceiveAuthenticationChallenge;

- (AFURLSessionTaskDidReceiveAuthenticationChallengeBlock)getTaskDidReceiveAuthenticationChallengeBlock;
- (AFURLSessionDidReceiveAuthenticationChallengeBlock)getSessionDidReceiveAuthenticationChallengeBlock;

@end // interface SM_AFURLSessionManager(Protected)


// Extend the SM_AFURLSessionManager implementation so that the challenge block variables are accessible in order to perform the dynamic pinning
@implementation SM_AFURLSessionManager(Protected)

@dynamic taskDidReceiveAuthenticationChallenge;
@dynamic sessionDidReceiveAuthenticationChallenge;

- (AFURLSessionTaskDidReceiveAuthenticationChallengeBlock)getTaskDidReceiveAuthenticationChallengeBlock {
    return self.taskDidReceiveAuthenticationChallenge;
}

- (AFURLSessionDidReceiveAuthenticationChallengeBlock)getSessionDidReceiveAuthenticationChallengeBlock {
    return self.sessionDidReceiveAuthenticationChallenge;
}

@end // implementation SM_AFURLSessionManager(Protected)

// Data access object for providing Approov results, which may be a successful string result or provide error information
@implementation ApproovResult

/**
 * Constructs a successful result.
 * 
 * @param result is the result, which may be nil
 */
- (nullable instancetype)initWithResult:(nullable NSString *)result {
    self = [super init];
    if (self)
    { 
        _result = result;
    }
    return self;
}

/**
 * Construct an error Approov result.
 * 
 * @param errorMessage the descriptive error message
 * @param isNetworkError is true for a network, as opposed to general, error type
 */
- (nullable instancetype)initWithErrorMessage:(nonnull NSString *)errorMessage isNetworkError:(BOOL)isNetworkError {
    self = [super init];
    if (self)
    { 
        _errorType = @"general";
        if (isNetworkError)
            _errorType = @"network";
        _errorMessage = errorMessage;
    }
    return self;
}

/**
 * Construct a rejection Approov error result.
 * 
 * @param errorMessage the descriptive rejection error message
 * @param rejectionARC the ARC or empty string if not enabled
 * @param rejectionReasons the rejection reasons or empty string if not enabled
 */
- (nullable instancetype)initWithRejectionErrorMessage:(nonnull NSString *)errorMessage rejectionARC:(nonnull NSString *)rejectionARC
    rejectionReasons:(nonnull NSString *)rejectionReasons {
    self = [super init];
    if (self)
    { 
        _errorType = @"rejection";
        _errorMessage = errorMessage;
        _rejectionARC = rejectionARC;
        _rejectionReasons = rejectionReasons;
    }
    return self;
}

@end


// ApproovService provides a mediation layer to the Approov SDK itself
@implementation ApproovService

// tag for logging
static NSString *TAG = @"ApproovService";

// lock object used during initialization
id initializerLock = nil;

// keeps track of whether Approov is initialized to avoid initialization on every view appearance
BOOL isInitialized = NO;

// original config string used during initialization
NSString* initialConfigString = nil;

// true if the interceptor should proceed on network failures and not add an Approov token
BOOL proceedOnNetworkFail = NO;

// header that will be added to Approov enabled requests
NSString *approovTokenHeader = @"Approov-Token";

// any prefix to be added before the Approov token, such as "Bearer "
NSString *approovTokenPrefix = @"";

// any header to be used for binding in Approov tokens or empty string if not set
NSString *bindingHeader = @"";

// map of headers that should have their values substituted for secure strings, mapped to their required prefixes
NSMutableDictionary<NSString *, NSString *> *substitutionHeaders = nil;

// set of query parameter keys whose values may be substituted for secure strings
NSMutableSet<NSString *> *substitutionQueryParams = nil;

// set of URL regular expressions that should be excluded from Approov protection
NSMutableSet<NSString *> *exclusionURLRegexs = nil;

/*
 * Initializes the ApproovService with the provided configuration string. The call is ignored if the
 * ApproovService has already been initialized with the same configuration string.
 *
 * @param config is the string to be used for initialization, or empty string for no initialization
 * @return ApproovResult showing if the initialization was successful, or provides an error otherwise
 */
- (ApproovResult *)initialize:(NSString *)config {
    @synchronized(initializerLock) {
        if (isInitialized) {
            // if the SDK is previously initialized then check the config string is the same
            if (![initialConfigString isEqualToString:config]) {
                return [[ApproovResult alloc] initWithErrorMessage:@"attempt to reinitialize Approov SDK with a different config" isNetworkError:NO];
            }
        }
        else {
            // initialize the Approov SDK
            if ([config length] != 0) {
                NSError *initializationError = nil;
                [Approov initialize:config updateConfig:@"auto" comment:nil error:&initializationError];
                if (initializationError) {
                    NSLog(@"%@: initialization failed: %@", TAG, [initializationError localizedDescription]);
                    return [[ApproovResult alloc] initWithErrorMessage:[initializationError localizedDescription] isNetworkError:NO];
                }
                [Approov setUserProperty:@"approov-advanced-http"];
            }

            // setup the state for the ApproovService
            substitutionHeaders = [[NSMutableDictionary alloc] init];
            substitutionQueryParams = [[NSMutableSet alloc] init];
            exclusionURLRegexs = [[NSMutableSet alloc] init];
            [ApproovService initializePublicKeyHeaders];
            initialConfigString = config;
            isInitialized = YES;
            NSLog(@"%@: initialized on device %@", TAG, [Approov getDeviceID]);
        }
    }
    return [[ApproovResult alloc] initWithResult:nil];
}

/**
 * Indicates that requests should proceed anyway if it is not possible to obtain an Approov token
 * due to a networking failure. If this is called then the backend API can receive calls without the
 * expected Approov token header being added, or without header/query parameter substitutions being
 * made. Note that this should be used with caution because it may allow a connection to be established
 * before any dynamic pins have been received via Approov, thus potentially opening the channel to a MitM.
 */
- (void)setProceedOnNetworkFail {
    // no need to synchronize on this
    proceedOnNetworkFail = YES;
    NSLog(@"%@: proceedOnNetworkFail", TAG);
}

/**
 * Sets the header that the Approov token is added on, as well as an optional
 * prefix String (such as "Bearer "). By default the token is provided on
 * "Approov-Token" with no prefix.
 *
 * @param header is the header to place the Approov token on
 * @param prefix is any prefix String for the Approov token header
 */
- (void)setTokenHeader:(NSString *_Nonnull)header prefix:(NSString *_Nonnull)prefix {
    @synchronized(approovTokenHeader) {
        approovTokenHeader = header;
    }
    @synchronized(approovTokenPrefix) {
        approovTokenPrefix = prefix;
    }
    NSLog(@"%@: setTokenHeader %@, %@", TAG, header, prefix);
}

/**
 * Sets a binding header that may be present on requests being made. A header should be
 * chosen whose value is unchanging for most requests (such as an Authorization header).
 * If the header is present, then a hash of the header value is included in the issued Approov
 * tokens to bind them to the value. This may then be verified by the backend API integration.
 *
 * @param header is the header to use for Approov token binding
 */
- (void)setBindingHeader:(NSString *)header {
    @synchronized(bindingHeader) {
        bindingHeader = header;
    }
    NSLog(@"%@: setBindingHeader %@", TAG, header);
}

/*
 * Adds the name of a header which should be subject to secure strings substitution. This
 * means that if the header is present then the value will be used as a key to look up a
 * secure string value which will be substituted into the header value instead. This allows
 * easy migration to the use of secure strings. A required prefix may be specified to deal
 * with cases such as the use of "Bearer " prefixed before values in an authorization header.
 *
 * @param header is the header to be marked for substitution
 * @param requiredPrefix is any required prefix to the value being substituted or nil if not required
 */
- (void)addSubstitutionHeader:(NSString *)header requiredPrefix:(NSString *)requiredPrefix {
    if (requiredPrefix == nil) {
        @synchronized(substitutionHeaders) {
            if (substitutionHeaders != nil)
                [substitutionHeaders setValue:@"" forKey:header];
        }
        NSLog(@"%@: addSubstitutionHeader %@", TAG, header);
    } else {
        @synchronized(substitutionHeaders) {
            if (substitutionHeaders != nil)
                [substitutionHeaders setValue:requiredPrefix forKey:header];
        }
        NSLog(@"%@: addSubstitutionHeader %@, %@", TAG, header, requiredPrefix);
    }
}

/*
 * Removes a header previously added using addSubstitutionHeader.
 *
 * @param header is the header to be removed for substitution
 */
- (void)removeSubstitutionHeader:(NSString *)header {
    @synchronized(substitutionHeaders) {
        if (substitutionHeaders != nil)
            [substitutionHeaders removeObjectForKey:header];
    }
    NSLog(@"%@: removeSubstitutionHeader %@", TAG, header);
}

/**
 * Adds a key name for a query parameter that should be subject to secure strings substitution.
 * This means that if the query parameter is present in a URL then the value will be used as a
 * key to look up a secure string value which will be substituted as the query parameter value
 * instead. This allows easy migration to the use of secure strings.
 *
 * @param key is the query parameter key name to be added for substitution
 */
- (void)addSubstitutionQueryParam:(NSString *)key {
    @synchronized(substitutionQueryParams) {
        if (substitutionQueryParams != nil)
            [substitutionQueryParams addObject:key];
    }
    NSLog(@"%@: addSubstitutionQueryParam %@", TAG, key);
}

/**
 * Removes a query parameter key name previously added using addSubstitutionQueryParam.
 *
 * @param key is the query parameter key name to be removed for substitution
 */
- (void)removeSubstitutionQueryParam:(NSString *)key {
    @synchronized(substitutionQueryParams) {
        if (substitutionQueryParams != nil)
            [substitutionQueryParams removeObject:key];
    }
    NSLog(@"%@: removeSubstitutionQueryParam %@", TAG, key);
}

/**
 * Adds an exclusion URL regular expression. If a URL for a request matches this regular expression
 * then it will not be subject to any Approov protection. Note that this facility must be used with
 * EXTREME CAUTION due to the impact of dynamic pinning. Pinning may be applied to all domains added
 * using Approov, and updates to the pins are received when an Approov fetch is performed. If you
 * exclude some URLs on domains that are protected with Approov, then these will be protected with
 * Approov pins but without a path to update the pins until a URL is used that is not excluded. Thus
 * you are responsible for ensuring that there is always a possibility of calling a non-excluded
 * URL, or you should make an explicit call to fetchToken if there are persistent pinning failures.
 * Conversely, use of those option may allow a connection to be established before any dynamic pins
 * have been received via Approov, thus potentially opening the channel to a MitM.
 *
 * @param urlRegex is the regular expression that will be compared against URLs to exclude them
 */
- (void)addExclusionURLRegex:(NSString *)urlRegex {
    @synchronized(exclusionURLRegexs) {
        if (exclusionURLRegexs != nil)
            [exclusionURLRegexs addObject:urlRegex];
    }
    NSLog(@"%@: addExclusionURLRegex %@", TAG, urlRegex);
}

/**
 * Removes an exclusion URL regular expression previously added using addExclusionURLRegex.
 *
 * @param urlRegex is the regular expression that will be compared against URLs to exclude them
 */
- (void)removeExclusionURLRegex:(NSString *)urlRegex {
    @synchronized(exclusionURLRegexs) {
        if (exclusionURLRegexs != nil)
            [exclusionURLRegexs removeObject:urlRegex];
    }
    NSLog(@"%@: removeExclusionURLRegex %@", TAG, urlRegex);
}

/**
 * Prefetches to lower the effective latency of a subsequent token or secure string fetch by
 * starting the operation earlier so the subsequent fetch may be able to use cached data.
 *
 * @return ApproovResult showing if the prefetch completed okay or not
 */
- (ApproovResult *)prefetch {
    ApproovTokenFetchResult *approovResult = [Approov fetchApproovTokenAndWait:@"approov.io"];
    NSLog(@"%@: prefetch: %@", TAG, [Approov stringFromApproovTokenFetchStatus:approovResult.status]);
    if ((approovResult.status == ApproovTokenFetchStatusSuccess) || (approovResult.status == ApproovTokenFetchStatusUnknownURL)) {
         return [[ApproovResult alloc] initWithResult:nil];
    } else if ((approovResult.status == ApproovTokenFetchStatusNoNetwork) ||
               (approovResult.status == ApproovTokenFetchStatusPoorNetwork) ||
               (approovResult.status == ApproovTokenFetchStatusMITMDetected)) {
        NSString* details = [NSString stringWithFormat:@"Network error: %@", [Approov stringFromApproovTokenFetchStatus:approovResult.status]];
        return [[ApproovResult alloc] initWithErrorMessage:details isNetworkError:YES];
    }
    else {
        NSString* details = [NSString stringWithFormat:@"Error: %@", [Approov stringFromApproovTokenFetchStatus:approovResult.status]];
        return [[ApproovResult alloc] initWithErrorMessage:details isNetworkError:NO];
    }
}

/*
 * Performs a precheck to determine if the app will pass attestation. This requires secure
 * strings to be enabled for the account, although no strings need to be set up. This will
 * likely require network access so may take some time to complete. It may return an error
 * if the precheck fails or if there is some other problem.
 *
 * @return ApproovResult providing the result of the precheck
 */
- (ApproovResult *)precheck  {
    // try to fetch a non-existent secure string in order to check for a rejection
    ApproovTokenFetchResult *approovResult = [Approov fetchSecureStringAndWait:@"precheck-dummy-key" :nil];
    NSLog(@"%@: precheck: %@", TAG, [Approov stringFromApproovTokenFetchStatus:approovResult.status]);

    // process the returned Approov status
    if (approovResult.status == ApproovTokenFetchStatusRejected){
        NSString* details = [NSString stringWithFormat:@"Rejected %@ %@", approovResult.ARC, approovResult.rejectionReasons];
        return [[ApproovResult alloc] initWithRejectionErrorMessage:details rejectionARC: approovResult.ARC
                rejectionReasons:approovResult.rejectionReasons];
    } else if ((approovResult.status == ApproovTokenFetchStatusNoNetwork) ||
               (approovResult.status == ApproovTokenFetchStatusPoorNetwork) ||
               (approovResult.status == ApproovTokenFetchStatusMITMDetected)) {
        NSString* details = [NSString stringWithFormat:@"Network error: %@", [Approov stringFromApproovTokenFetchStatus:approovResult.status]];
        return [[ApproovResult alloc] initWithErrorMessage:details isNetworkError:YES];
    } else if ((approovResult.status != ApproovTokenFetchStatusSuccess) && (approovResult.status != ApproovTokenFetchStatusUnknownKey)) {
        NSString* details = [NSString stringWithFormat:@"Error: %@", [Approov stringFromApproovTokenFetchStatus:approovResult.status]];
        return [[ApproovResult alloc] initWithErrorMessage:details isNetworkError:NO];
    }
    return [[ApproovResult alloc] initWithResult:nil];
}

/**
 * Gets the device ID used by Approov to identify the particular device that the SDK is running on. Note
 * that different Approov apps on the same device will return a different ID. Moreover, the ID may be
 * changed by an uninstall and reinstall of the app.
 * 
 * @return ApproovResult with the device ID or any error
 */
- (ApproovResult *)getDeviceID {
    NSString *deviceID = [Approov getDeviceID];
    NSLog(@"%@: getDeviceID: %@", TAG, deviceID);
    return [[ApproovResult alloc] initWithResult:deviceID];
}

/**
 * Directly sets the data hash to be included in subsequently fetched Approov tokens. If the hash is
 * different from any previously set value then this will cause the next token fetch operation to
 * fetch a new token with the correct payload data hash. The hash appears in the
 * 'pay' claim of the Approov token as a base64 encoded string of the SHA256 hash of the
 * data. Note that the data is hashed locally and never sent to the Approov cloud service.
 * 
 * @param data is the data to be hashed and set in the token
 * @return ApproovResult to indicate any errors
 */
- (ApproovResult *)setDataHashInToken:(NSString *)data {
    NSLog(@"%@: setDataHashInToken", TAG);
    [Approov setDataHashInToken:data];
    return [[ApproovResult alloc] initWithResult:nil];
}

/**
 * Performs an Approov token fetch for the given URL. This should be used in situations where it
 * is not possible to use the networking interception to add the token. This will
 * likely require network access so may take some time to complete. It may return an error
 * if there is some problem. The error type "network" is for networking issues where a
 * user initiated retry of the operation should be allowed.
 * 
 * @param url is the URL giving the domain for the token fetch
 * @return ApproovResult providing the token or showing if there was a problem
 */
- (ApproovResult *)fetchToken:(NSString *)url {
    // fetch the Approov token
    ApproovTokenFetchResult *approovResult = [Approov fetchApproovTokenAndWait:url];
    NSLog(@"%@: fetchToken %@: %@", TAG, url, [Approov stringFromApproovTokenFetchStatus:approovResult.status]);

    // process the returned Approov status
    if ((approovResult.status == ApproovTokenFetchStatusNoNetwork) ||
        (approovResult.status == ApproovTokenFetchStatusPoorNetwork) ||
        (approovResult.status == ApproovTokenFetchStatusMITMDetected)) {
        NSString* details = [NSString stringWithFormat:@"Network error: %@", [Approov stringFromApproovTokenFetchStatus:approovResult.status]];
        return [[ApproovResult alloc] initWithErrorMessage:details isNetworkError:YES];
    } else if (approovResult.status != ApproovTokenFetchStatusSuccess) {
        NSString* details = [NSString stringWithFormat:@"Error: %@", [Approov stringFromApproovTokenFetchStatus:approovResult.status]];
        return [[ApproovResult alloc] initWithErrorMessage:details isNetworkError:NO];
    }
    return [[ApproovResult alloc] initWithResult:approovResult.token];
}

/**
 * Gets the signature for the given message. This uses an account specific message signing key that is
 * transmitted to the SDK after a successful fetch if the facility is enabled for the account. Note
 * that if the attestation failed then the signing key provided is actually random so that the
 * signature will be incorrect. An Approov token should always be included in the message
 * being signed and sent alongside this signature to prevent replay attacks.
 *
 * @param message is the message whose content is to be signed
 * @return ApproovResult with base64 encoded signature of the message, or an error otherwise
 */
- (ApproovResult *)getMessageSignature:(NSString *)message {
    NSLog(@"%@: getMessageSignature", TAG);
    NSString *signature = [Approov getMessageSignature:message];
    if (signature == nil)
        return [[ApproovResult alloc] initWithErrorMessage:@"no signature available" isNetworkError:NO];
    else
        return [[ApproovResult alloc] initWithResult:signature];
}

/*
 * Fetches a secure string with the given key. If newDef is not nil then a
 * secure string for the particular app instance may be defined. In this case the
 * new value is returned as the secure string. Use of an empty string for newDef removes
 * the string entry. Note that this call may require network transaction and thus may block
 * for some time. If the attestation fails for any reason then an error is provided in the
 * returned result.
 *
 * @param key is the secure string key to be looked up
 * @param newDef is any new definition for the secure string, or nil for lookup only
 * @return ApproovResult holding the secure string (should not be cached by your app) or any error instead
 */
- (ApproovResult *)fetchSecureString:(NSString*)key newDef:(NSString*)newDef  {
    // determine the type of operation as the values themselves cannot be logged
    NSString *type = @"lookup";
    if (newDef != nil)
        type = @"definition";
    
    // fetch any secure string keyed by the value
    ApproovTokenFetchResult *approovResult = [Approov fetchSecureStringAndWait:key :newDef];
    NSLog(@"%@: fetchSecureString %@ for %@: %@", TAG, type, key, [Approov stringFromApproovTokenFetchStatus:approovResult.status]);

    // process the returned Approov status
    if (approovResult.status == ApproovTokenFetchStatusRejected) {
        NSString* details = [NSString stringWithFormat:@"Rejected %@ %@", approovResult.ARC, approovResult.rejectionReasons];
        return [[ApproovResult alloc] initWithRejectionErrorMessage:details rejectionARC: approovResult.ARC
                rejectionReasons:approovResult.rejectionReasons];
    } else if ((approovResult.status == ApproovTokenFetchStatusNoNetwork) ||
               (approovResult.status == ApproovTokenFetchStatusPoorNetwork) ||
               (approovResult.status == ApproovTokenFetchStatusMITMDetected)) {
        NSString* details = [NSString stringWithFormat:@"Network error: %@", [Approov stringFromApproovTokenFetchStatus:approovResult.status]];
        return [[ApproovResult alloc] initWithErrorMessage:details isNetworkError:YES];
    } else if ((approovResult.status != ApproovTokenFetchStatusSuccess) && (approovResult.status != ApproovTokenFetchStatusUnknownKey)) {
        NSString* details = [NSString stringWithFormat:@"Error: %@", [Approov stringFromApproovTokenFetchStatus:approovResult.status]];
        return [[ApproovResult alloc] initWithErrorMessage:details isNetworkError:NO];
    }
    return [[ApproovResult alloc] initWithResult:approovResult.secureString];
}

/*
 * Fetches a custom JWT with the given payload. Note that this call will require network
 * transaction and thus will block for some time. If the fetch fails for any reason then
 * an error is provided in the returned result.
 *
 * @param payload is the marshaled JSON object for the claims to be included
 * @return ApproovResult holding the custom JWT or information about any error
 */
- (ApproovResult *)fetchCustomJWT:(NSString*)payload {
    // fetch the custom JWT
    ApproovTokenFetchResult *approovResult = [Approov fetchCustomJWTAndWait:payload];
    NSLog(@"%@: fetchCustomJWT %@", TAG, [Approov stringFromApproovTokenFetchStatus:approovResult.status]);

    // process the returned Approov status
    if (approovResult.status == ApproovTokenFetchStatusRejected) {
        NSString* details = [NSString stringWithFormat:@"Rejected %@ %@", approovResult.ARC, approovResult.rejectionReasons];
        return [[ApproovResult alloc] initWithRejectionErrorMessage:details rejectionARC: approovResult.ARC
                rejectionReasons:approovResult.rejectionReasons];
    } else if ((approovResult.status == ApproovTokenFetchStatusNoNetwork) ||
               (approovResult.status == ApproovTokenFetchStatusPoorNetwork) ||
               (approovResult.status == ApproovTokenFetchStatusMITMDetected)) {
        NSString* details = [NSString stringWithFormat:@"Network error: %@", [Approov stringFromApproovTokenFetchStatus:approovResult.status]];
        return [[ApproovResult alloc] initWithErrorMessage:details isNetworkError:YES];
    } else if (approovResult.status != ApproovTokenFetchStatusSuccess) {
        NSString* details = [NSString stringWithFormat:@"Error: %@", [Approov stringFromApproovTokenFetchStatus:approovResult.status]];
        return [[ApproovResult alloc] initWithErrorMessage:details isNetworkError:NO];
    }
    return [[ApproovResult alloc] initWithResult:approovResult.token];
}

/**
 * Adds Approov to a request being handled by the given session manager. This involves fetching an
 * Approov token for the domain being accessed and adding an Approov token to the outgoing header. This
 * may also update the token if token binding is being used. Header or query parameter values may also
 * be substituted if this feature is enabled.
 *
 * @param manager is the session manager for the request
 * @param url is the URL of the request being made
 * @return the potentially updated URL to include query parameter substitution
 * @throws NSException if there was an issue communicating with Approov, or a rejection for secure strings
 */
- (NSString *)addApproovToSessionManager:(SM_AFHTTPSessionManager *)manager URL:(NSString *)url {
    // if the Approov SDK is not initialized then we just return immediately without making any changes
    if (!isInitialized) {
        NSLog(@"%@: uninitialized forwarded: %@", TAG, url);
        return url;
    }

    // we always allow requests to "localhost" without Approov protection as can be used for obtaining resources
    // during development
    NSString *host = [[NSURL URLWithString:url] host];
    if ([host isEqualToString:@"localhost"]) {
        NSLog(@"%@: localhost forwarded: %@", TAG, url);
        return url;
    }

    // ensure the connection is pinned if the domain is added using Approov - we must do this even for potentially
    // excluded URLs because if they are on the same domain as an Approov protected URL then the TLS connection might
    // remain live from an initial excluded URL connection event
    [ApproovService setupApproovPublicKeyPinning:manager];

    // obtain a copy of the exclusion URL regular expressions in a thread safe way
    NSSet<NSString *> *exclusionURLs;
    @synchronized(exclusionURLRegexs) {
        exclusionURLs = [[NSSet alloc] initWithSet:exclusionURLRegexs copyItems:NO];
    }

    // we just return with the existing URL if it matches any of the exclusion URL regular expressions provided
    for (NSString *exclusionURL in exclusionURLs) {
        NSError *error = nil;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:exclusionURL options:0 error:&error];
        if (!error) {
            NSTextCheckingResult *match = [regex firstMatchInString:url options:0 range:NSMakeRange(0, [url length])];
            if (match) {
                NSLog(@"%@: excluded url: %@", TAG, url);
                return url;
            }
        }
    }

    // update the data hash based on any token binding header
    @synchronized(bindingHeader) {
        if (![bindingHeader isEqualToString:@""]) {
            NSString *headerValue = [manager.requestSerializer valueForHTTPHeaderField:bindingHeader];
            if (headerValue != nil)
                [Approov setDataHashInToken:headerValue];
        }
    }

    // fetch the Approov token and log the result
    ApproovTokenFetchResult *approovResult = [Approov fetchApproovTokenAndWait:url];
    NSLog(@"%@: token for %@: %@", TAG, host, [approovResult loggableToken]);

    // log if a configuration update is received and call fetchConfig to clear the update state
    if (approovResult.isConfigChanged) {
        [Approov fetchConfig];
        NSLog(@"%@: dynamic configuration update received", TAG);
    }

    // process the token fetch result
    ApproovTokenFetchStatus approovStatus = [approovResult status];
    switch (approovStatus) {
        case ApproovTokenFetchStatusSuccess:
        {
            // add the Approov token to the required header
            NSString *tokenHeader;
            @synchronized(approovTokenHeader) {
                tokenHeader = approovTokenHeader;
            }
            NSString *tokenPrefix;
            @synchronized(approovTokenPrefix) {
                tokenPrefix = approovTokenPrefix;
            }
            [manager.requestSerializer setValue:[NSString stringWithFormat:@"%@%@", tokenPrefix, [approovResult token]]
                forHTTPHeaderField:tokenHeader];
            break;
        }
        case ApproovTokenFetchStatusUnknownURL:
        case ApproovTokenFetchStatusUnprotectedURL:
        case ApproovTokenFetchStatusNoApproovService:
            // in these cases we continue without adding an Approov token
            break;
        case ApproovTokenFetchStatusNoNetwork:
        case ApproovTokenFetchStatusPoorNetwork:
        case ApproovTokenFetchStatusMITMDetected:
            // unless we are proceeding on network fail, we throw an exception if we are unable to get
            // an Approov token due to network conditions
            if (!proceedOnNetworkFail)
                @throw [NSException exceptionWithName:@"ApproovError" reason:@"Approov error"
                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"Approov token fetch network error: %@", [Approov stringFromApproovTokenFetchStatus:approovStatus]]}];
        default:
            // we have a more permanent error from the Approov SDK
            @throw [NSException exceptionWithName:@"ApproovError" reason:@"Approov error"
                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"Approov token fetch error: %@", [Approov stringFromApproovTokenFetchStatus:approovStatus]]}];
    }

    // we just return early with anything other than a success or unprotected URL - this is to ensure we don't
    // make further Approov fetches if there has been a problem and also that we don't do header or query
    // parameter substitutions in domains not known to Approov (which therefore might not be pinned)
    if ((approovResult.status != ApproovTokenFetchStatusSuccess) &&
        (approovResult.status != ApproovTokenFetchStatusUnprotectedURL))
        return url;

    // obtain a copy of the substitution headers in a thread safe way
    NSDictionary<NSString *, NSString *> *subsHeaders;
    @synchronized(substitutionHeaders) {
        subsHeaders = [[NSDictionary alloc] initWithDictionary:substitutionHeaders copyItems:NO];
    }

    // we now deal with any header substitutions, which may require further fetches but these
    // should be using cached results
    for (NSString *header in subsHeaders) {
        NSString *prefix = [substitutionHeaders objectForKey:header];
        NSString *value = [manager.requestSerializer valueForHTTPHeaderField:header];
        if ((value != nil) && (prefix != nil) && (value.length > prefix.length) &&
            (([prefix length] == 0) || [value hasPrefix:prefix])) {
            // the request contains the header we want to replace
            approovResult = [Approov fetchSecureStringAndWait:[value substringFromIndex:prefix.length] :nil];
            NSLog(@"%@: substituting header %@: %@", TAG, header, [Approov stringFromApproovTokenFetchStatus:approovResult.status]);
            if (approovResult.status == ApproovTokenFetchStatusSuccess) {
                // update the header value with the actual secret
                [manager.requestSerializer setValue:[NSString stringWithFormat:@"%@%@", prefix, approovResult.secureString] forHTTPHeaderField:header];
            } else if (approovResult.status == ApproovTokenFetchStatusRejected) {
                // the attestation has been rejected so provide additional information in the message
                @throw [NSException exceptionWithName:@"ApproovError" reason:@"Approov error"
                        userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:
                        @"Approov header substitution rejection %@ %@", approovResult.ARC, approovResult.rejectionReasons]}];
            } else if ((approovResult.status == ApproovTokenFetchStatusNoNetwork) ||
                       (approovResult.status == ApproovTokenFetchStatusPoorNetwork) ||
                       (approovResult.status == ApproovTokenFetchStatusMITMDetected)) {
                // we are unable to get the secure string due to network conditions so the request can
                // be retried by the user later - unless overridden
                if (!proceedOnNetworkFail)
                    @throw [NSException exceptionWithName:@"ApproovError" reason:@"Approov error"
                        userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:
                        @"Approov header substitution network error: %@", [Approov stringFromApproovTokenFetchStatus:approovStatus]]}];
            } else if (approovResult.status != ApproovTokenFetchStatusUnknownKey) {
                // we have failed to get a secure string with a more serious permanent error
                @throw [NSException exceptionWithName:@"ApproovError" reason:@"Approov error"
                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"Approov header substitution error: %@", [Approov stringFromApproovTokenFetchStatus:approovStatus]]}];
            }
        }
    }

    // obtain a copy of the substitution query parameter in a thread safe way
    NSSet<NSString *> *subsQueryParams;
    @synchronized(substitutionQueryParams) {
        subsQueryParams = [[NSSet alloc] initWithSet:substitutionQueryParams copyItems:NO];
    }

    // we now deal with any query parameter substitutions, which may require further fetches but these
    // should be using cached results
    for (NSString *key in subsQueryParams) {
        NSString *pattern = [NSString stringWithFormat:@"[\\?&]%@=([^&;]+)", key];
        NSError *error = nil;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
        if (error) {
            @throw [NSException exceptionWithName:@"ApproovError" reason:@"Approov error"
                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"Approov query parameter substitution regex error: %@", [error localizedDescription]]}];
        }
        NSTextCheckingResult *match = [regex firstMatchInString:url options:0 range:NSMakeRange(0, [url length])];
        if (match) {
            // the request contains the query parameter we want to replace
            NSString *matchText = [url substringWithRange:[match rangeAtIndex:1]];
            approovResult = [Approov fetchSecureStringAndWait:matchText :nil];
            NSLog(@"%@: substituting query parameter %@: %@", TAG, key, [Approov stringFromApproovTokenFetchStatus:approovResult.status]);
            if (approovResult.status == ApproovTokenFetchStatusSuccess) {
                // update the URL with the actual secret
                url = [url stringByReplacingCharactersInRange:[match rangeAtIndex:1] withString:approovResult.secureString];
            } else if (approovResult.status == ApproovTokenFetchStatusRejected) {
                // the attestation has been rejected so provide additional information in the message
                @throw [NSException exceptionWithName:@"ApproovError" reason:@"Approov error"
                        userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:
                        @"Approov query parameter substitution rejection %@ %@", approovResult.ARC, approovResult.rejectionReasons]}];
            } else if ((approovResult.status == ApproovTokenFetchStatusNoNetwork) ||
                       (approovResult.status == ApproovTokenFetchStatusPoorNetwork) ||
                       (approovResult.status == ApproovTokenFetchStatusMITMDetected)) {
                // we are unable to get the secure string due to network conditions so the request can
                // be retried by the user later - unless overridden
                if (!proceedOnNetworkFail)
                    @throw [NSException exceptionWithName:@"ApproovError" reason:@"Approov error"
                        userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:
                        @"Approov query parameter substitution network error: %@", [Approov stringFromApproovTokenFetchStatus:approovStatus]]}];
            } else if (approovResult.status != ApproovTokenFetchStatusUnknownKey) {
                // we have failed to get a secure string with a more serious permanent error
                @throw [NSException exceptionWithName:@"ApproovError" reason:@"Approov error"
                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"Approov query parameter substitution error: %@", [Approov stringFromApproovTokenFetchStatus:approovStatus]]}];
            }
        }
    }

    // provide the updated URL
    return url;
}

/**
 * Set up Approov certificate public key pinning for the given session manager.
 *
 * @param manager is the session manager for which Approov dynamic pinning must be set
 */
+ (void)setupApproovPublicKeyPinning:(SM_AFURLSessionManager *)manager {
    static char approovAuthenticationChallengeBlockKey;
    @synchronized(manager) {
        SM_AFURLSessionManager* __weak weakManager = manager;
        AFURLSessionDidReceiveAuthenticationChallengeBlock sessionDidReceiveAuthenticationChallengeBlock =
            [manager getSessionDidReceiveAuthenticationChallengeBlock];
        AFURLSessionDidReceiveAuthenticationChallengeBlock approovAuthenticationChallengeBlock =
            (AFURLSessionDidReceiveAuthenticationChallengeBlock)objc_getAssociatedObject(
                manager, &approovAuthenticationChallengeBlockKey);
        if (!sessionDidReceiveAuthenticationChallengeBlock
            || sessionDidReceiveAuthenticationChallengeBlock != approovAuthenticationChallengeBlock) {
            // define the authentication challenge block for the Approov pinning check
            AFURLSessionDidReceiveAuthenticationChallengeBlock approovVerifyPinning =
                ^NSURLSessionAuthChallengeDisposition(NSURLSession * _Nonnull session,
                     NSURLAuthenticationChallenge * _Nonnull challenge,
                     NSURLCredential * _Nullable * _Nullable credential) {
                @synchronized(manager) {
                    __block NSURLCredential *credentialResult;
                    __block NSURLSessionAuthChallengeDisposition dispositionResult =
                        NSURLSessionAuthChallengePerformDefaultHandling;
                    // completion handler for call of URLSession:didReceiveChallenge:completionHandler: method,
                    // defined by the NSURLSessionTaskDelegate protocol
                    void (^completionHandler)(NSURLSessionAuthChallengeDisposition, NSURLCredential *) = ^(NSURLSessionAuthChallengeDisposition challengeDisposition, NSURLCredential *credential) {
                            credentialResult = credential;
                            dispositionResult = challengeDisposition;
                        };

                    // perform AFURLSessionManager's original verification
                    if (sessionDidReceiveAuthenticationChallengeBlock == nil) {
                        // call AFURLSessionManager's NSURLSessionDelegate method, but first reset AFURLSessionManager's
                        // authentication challenge block to nil, otherwise approovVerifyPinning will be called
                        // recursively from AFURLSessionManager's URLSession:didReceiveChallenge:completionHandler:
                        // method
                        AFURLSessionDidReceiveAuthenticationChallengeBlock approovAuthenticationChallengeBlock =
                            [weakManager getSessionDidReceiveAuthenticationChallengeBlock];
                        [weakManager setSessionDidReceiveAuthenticationChallengeBlock:nil];

                        // call AFURLSessionManager's original URLSession:didReceiveChallenge:completionHandler:
                        // method
                        [weakManager URLSession:session didReceiveChallenge:challenge completionHandler:completionHandler];

                        // restore AFURLSessionManager's sessionDidReceiveAuthenticationChallenge block back to the
                        // Approov pinning check
                        [weakManager setSessionDidReceiveAuthenticationChallengeBlock:approovAuthenticationChallengeBlock];
                    }
                    else {
                        // call AFURLSessionManager's original sessionDidReceiveAuthenticationChallenge block
                        dispositionResult = sessionDidReceiveAuthenticationChallengeBlock(session, challenge, &credentialResult);
                    }

                    // if the challenge failed AFURLSessionManager's original verification, return
                    if (dispositionResult != NSURLSessionAuthChallengeUseCredential
                        && dispositionResult != NSURLSessionAuthChallengePerformDefaultHandling) {
                        *credential = credentialResult;
                        return dispositionResult;
                    }

                    // otherwise also check Approov pinning
                    [ApproovService URLSession:session didReceiveChallenge:challenge completionHandler:completionHandler];
                    *credential = credentialResult;
                    return dispositionResult;
                }
            };

            // set the sessionDidReceiveAuthenticationChallenge block for the Approov pinning check
            [manager setSessionDidReceiveAuthenticationChallengeBlock:approovVerifyPinning];

            // Associate approovVerifyPinning with the manager so we can check whether Approov pinning is already
            // set up by checking that the manager's sessionDidReceiveAuthenticationChallenge block is equal to the
            // approovVerifyPinning block associated with the manager
            // see https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjectiveC/Chapters/ocAssociativeReferences.html#//apple_ref/doc/uid/TP30001163-CH24
            objc_setAssociatedObject(manager, &approovAuthenticationChallengeBlockKey, approovVerifyPinning,
                                     OBJC_ASSOCIATION_RETAIN);
        }
        // otherwise taskDidReceiveAuthenticationChallenge block for the Approov pinning check already set and
        // up-to-date
    }
}

// Subject public key info (SPKI) headers for public keys' type and size. Only RSA-2048, RSA-4096, EC-256 and EC-384
// are supported.
static NSDictionary<NSString *, NSDictionary<NSNumber *, NSData *> *> *spkiHeaders;

/**
 * Initialize the SPKI header constants.
 */
+ (void)initializePublicKeyHeaders {
    const unsigned char rsa2048SPKIHeader[] = {
        0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05,
        0x00, 0x03, 0x82, 0x01, 0x0f, 0x00
    };
    const unsigned char rsa4096SPKIHeader[] = {
        0x30, 0x82, 0x02, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05,
        0x00, 0x03, 0x82, 0x02, 0x0f, 0x00
    };
    const unsigned char ecdsaSecp256r1SPKIHeader[] = {
        0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a, 0x86, 0x48,
        0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00
    };
    const unsigned char ecdsaSecp384r1SPKIHeader[] = {
        0x30, 0x76, 0x30, 0x10, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x05, 0x2b, 0x81, 0x04,
        0x00, 0x22, 0x03, 0x62, 0x00
    };
    spkiHeaders = @{
        (NSString *)kSecAttrKeyTypeRSA : @{
            @2048 : [NSData dataWithBytes:rsa2048SPKIHeader length:sizeof(rsa2048SPKIHeader)],
            @4096 : [NSData dataWithBytes:rsa4096SPKIHeader length:sizeof(rsa4096SPKIHeader)]
        },
        (NSString *)kSecAttrKeyTypeECSECPrimeRandom : @{
            @256 : [NSData dataWithBytes:ecdsaSecp256r1SPKIHeader length:sizeof(ecdsaSecp256r1SPKIHeader)],
            @384 : [NSData dataWithBytes:ecdsaSecp384r1SPKIHeader length:sizeof(ecdsaSecp384r1SPKIHeader)]
        }
    };
}

/**
 * Custom certificate check provided for NSURLSessionDelegate protocol to implement Approov pinning.
 * 
 * @param session is the session containing the task whose request requires authentication
 * @param challenge is an object that contains the request for authentication
 * @param completionHandler is a handler that your delegate method must call to provide the result 
 */
+ (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
    completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
    // ignore any requests that are not related to server trust
    if (![challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        return;
    }

    // check we have a server trust
    SecTrustRef serverTrust = challenge.protectionSpace.serverTrust;
    if (!serverTrust) {
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        return;
    }

    // check the validity of the server trust
    SecTrustResultType result;
    OSStatus status = SecTrustEvaluate(serverTrust, &result);
    if (errSecSuccess != status) {
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
        return;
    }

    // get the Approov pins for the domain
    NSDictionary<NSString *, NSArray<NSString *> *> *approovPins = [Approov getPins:@"public-key-sha256"];
    NSString *domain = challenge.protectionSpace.host;
    NSArray<NSString *> *pinsForDomain = approovPins[domain];

    // if there are no pins for the domain (but the domain is present) then use any managed trust roots instead
    if ((pinsForDomain != nil) && [pinsForDomain count] == 0)
        pinsForDomain = approovPins[@"*"];

    // if we are not pinning then we consider this level of trust to be acceptable
    if ((pinsForDomain == nil) || [pinsForDomain count] == 0) {
        completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:serverTrust]);
        return;
    }

    // check public key hash of all certificates in the chain, leaf certificate first
    for (int certIndex = 0; certIndex < SecTrustGetCertificateCount(serverTrust); certIndex += 1) {
        // get the certificate
        SecCertificateRef serverCert = SecTrustGetCertificateAtIndex(serverTrust, certIndex);
        if (!serverCert) {
            completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
            return;
        }

        // get the subject public key info from the certificate
        NSData *publicKeyInfo = [ApproovService publicKeyInfoOfCertificate:serverCert];
        if (!publicKeyInfo) {
            completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
            return;
        }

        // compute the SHA-256 hash of the public key info
        NSData *publicKeyInfoHash = [ApproovService sha256:publicKeyInfo];
        NSString *publicKeyInfoHashB64 = [publicKeyInfoHash base64EncodedStringWithOptions:0];

        // check that the hash is the same as at least one of the pins
        for (NSString* pinHashB64 in pinsForDomain) {
            if ([publicKeyInfoHashB64 isEqual:pinHashB64]) {
                completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:serverTrust]);
                return;
            }
        }
    }

    // the presented public key did not match any of the pins
    completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
}

/**
 * Gets the subject public key info (SPKI) header depending on a public key's type and size.
 * 
 * @param publicKey is the public key being analyzed
 * @return NSData* of the coresponding SPKI header that will be used
 */
+ (NSData *)publicKeyInfoHeaderForKey:(SecKeyRef)publicKey {
    CFDictionaryRef publicKeyAttributes = SecKeyCopyAttributes(publicKey);
    NSString *keyType = CFDictionaryGetValue(publicKeyAttributes, kSecAttrKeyType);
    NSNumber *keyLength = CFDictionaryGetValue(publicKeyAttributes, kSecAttrKeySizeInBits);
    NSData *spkiHeader = spkiHeaders[keyType][keyLength];
    CFRelease(publicKeyAttributes);
    return spkiHeader;
}

/**
 * Gets a certificate's Subject Public Key Info (SPKI).
 *
 * @param certificate is the certificate being analyzed
 * @return NSData* of the SPKI certificate information
 */
+ (NSData *)publicKeyInfoOfCertificate:(SecCertificateRef)certificate {
    // get the public key from the certificate
    SecKeyRef publicKey;
    if (@available(iOS 12.0, *)) {
        // direct OS function is available in later releases
        publicKey = SecCertificateCopyKey(certificate);
    }
    else {
        // from TrustKit https://github.com/datatheorem/TrustKit/blob/master/TrustKit/Pinning/TSKSPKIHashCache.m lines
        // 221-234:
        // Create an X509 trust using the certificate
        SecTrustRef trust;
        SecPolicyRef policy = SecPolicyCreateBasicX509();
        OSStatus status = SecTrustCreateWithCertificates(certificate, policy, &trust);
        if (status != errSecSuccess) {
            CFRelease(policy);
            CFRelease(trust);
            return nil;
        }

        // get a public key reference for the certificate from the trust
        SecTrustResultType result;
        status = SecTrustEvaluate(trust, &result);
        if (status != errSecSuccess) {
            CFRelease(policy);
            CFRelease(trust);
            return nil;
        }
        publicKey = SecTrustCopyPublicKey(trust);
        CFRelease(policy);
        CFRelease(trust);
    }

    // exit early if no public key was obtained
    if (!publicKey)
        return nil;

    // get the SPKI header depending on the public key's type and size
    NSData *spkiHeader = [ApproovService publicKeyInfoHeaderForKey:publicKey];
    if (!spkiHeader) {
        CFRelease(publicKey);
        return nil;
    }

    // combine the public key header and the public key data to form the public key info
    NSData *publicKeyData = (NSData*)CFBridgingRelease(SecKeyCopyExternalRepresentation(publicKey, NULL));
    CFRelease(publicKey);
    if (!publicKeyData)
        return nil;
    NSMutableData *publicKeyInfo = [NSMutableData dataWithData:spkiHeader];
    [publicKeyInfo appendData:publicKeyData];
    return publicKeyInfo;
}

/**
 * Compute a 32-byte SHA-256 hash of the data.
 *
 * @param data is the data to compute the hash from
 * @return the 32-byte hash
 */
+ (NSData *)sha256:(NSData *)data {
    CC_SHA256_CTX sha256Ctx;
    CC_SHA256_Init(&sha256Ctx);
    CC_SHA256_Update(&sha256Ctx, data.bytes, (CC_LONG)data.length);
    NSMutableData *hash = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(hash.mutableBytes, &sha256Ctx);
    return hash;
}

@end
