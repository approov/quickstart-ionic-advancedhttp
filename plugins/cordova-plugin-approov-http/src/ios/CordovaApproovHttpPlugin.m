/*
 * Copyright (c) 2018-2020 CriticalBlue Ltd.
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

#import "CordovaApproovHttpPlugin.h"

#import "AFHTTPSessionManager.h"
#import "AFSecurityPolicy.h"
#import "AFURLSessionManager.h"
#import <Approov/Approov.h>
#import "CDVFile.h"
#import <CommonCrypto/CommonDigest.h>
#import "CordovaHttpPlugin.h"
#import <objc/runtime.h>
#import "TextResponseSerializer.h"


@interface AFURLSessionManager(Protected)

typedef NSURLSessionAuthChallengeDisposition (^AFURLSessionDidReceiveAuthenticationChallengeBlock)(NSURLSession *session, NSURLAuthenticationChallenge *challenge, NSURLCredential **credential);

typedef NSURLSessionAuthChallengeDisposition (^AFURLSessionTaskDidReceiveAuthenticationChallengeBlock)(NSURLSession *session, NSURLSessionTask *task, NSURLAuthenticationChallenge *challenge, NSURLCredential **credential);

// Make AFURLSessionManager's taskDidReceiveAuthenticationChallenge instance variable accessible
@property (readwrite, nonatomic, copy) AFURLSessionTaskDidReceiveAuthenticationChallengeBlock taskDidReceiveAuthenticationChallenge;

// Make AFURLSessionManager's sessionDidReceiveAuthenticationChallenge instance variable accessible
@property (readwrite, nonatomic, copy) AFURLSessionDidReceiveAuthenticationChallengeBlock sessionDidReceiveAuthenticationChallenge;

- (AFURLSessionTaskDidReceiveAuthenticationChallengeBlock)getTaskDidReceiveAuthenticationChallengeBlock;

- (AFURLSessionDidReceiveAuthenticationChallengeBlock)getSessionDidReceiveAuthenticationChallengeBlock;

@end // interface AFURLSessionManager(Protected)


@implementation AFURLSessionManager(Protected)

@dynamic taskDidReceiveAuthenticationChallenge;
@dynamic sessionDidReceiveAuthenticationChallenge;

- (AFURLSessionTaskDidReceiveAuthenticationChallengeBlock)getTaskDidReceiveAuthenticationChallengeBlock {
    return self.taskDidReceiveAuthenticationChallenge;
}

- (AFURLSessionDidReceiveAuthenticationChallengeBlock)getSessionDidReceiveAuthenticationChallengeBlock {
    return self.sessionDidReceiveAuthenticationChallenge;
}

@end // implementation AFURLSessionManager(Protected)


@interface CordovaHttpPlugin(Protected)

typedef void (^RequestInterceptor)(AFHTTPSessionManager *manager, NSString *urlString);

+ (void)addRequestInterceptor:(RequestInterceptor)requestInterceptor;

@end // interface CordovaHttpPlugin(Protected)


// Tag for logging
static NSString *TAG = @"CordovaApproovHttpPlugin";

// Keeps track of whether Approov is initialized to avoid initialization on every view appearance
static BOOL isApproovInitialized = NO;

// header that will be added to Approov enabled requests
static NSString *APPROOV_HEADER = @"Approov-Token";

// any prefix to be added before the Approov token, such as "Bearer "
static NSString *APPROOV_TOKEN_PREFIX = @"";

// any header to be used for binding in Approov tokens or empty string if not set
static NSString *bindingHeader = @"";

@implementation CordovaApproovHttpPlugin {

    // Request interceptor for setting up Approov protection
    RequestInterceptor approovProtect;

}

// Ensure the Approov library has been initialized
+ (void)ensureApproovInitialized:(NSError **)error {
    if (!isApproovInitialized) {
        // Initialize Approov
        // Read the initial configuration for the Approov SDK
        NSURL *initialConfigURL = [[NSBundle mainBundle] URLForResource:@"approov-initial" withExtension:@"config"];
        if (!initialConfigURL) {
            // It is fatal if the SDK cannot read an initial configuration
            if (error)
                *error = [NSError errorWithDomain:TAG code:0
                    userInfo:@{NSLocalizedDescriptionKey : @"Approov initial configuration not found"}];
            return;
        }
        NSError *readError = nil;
        NSString *initialConfig = [NSString stringWithContentsOfURL:initialConfigURL encoding:NSUTF8StringEncoding error:&readError];
        if (readError) {
            // It is fatal if the SDK cannot read an initial configuration
            if (error)
                *error = [NSError errorWithDomain:TAG code:0
                    userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@%@",
                        @"Approov initial configuration read failed: ", [readError localizedDescription]]}];
            return;
        }

        // Read any dynamic configuration for the Approov SDK
        NSString *updateConfig = [CordovaApproovHttpPlugin loadApproovConfigUpdate];

        // Initialize the Approov SDK
        NSError *initializationError = nil;
        [Approov initialize:initialConfig updateConfig:updateConfig comment:nil error:&initializationError];
        if (initializationError) {
            // It is fatal if the Approov SDK cannot be initialized as all subsequent attempts to use the SDK will fail
            if (error)
                *error = [NSError errorWithDomain:TAG code:0
                    userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@%@",
                        @"Approov initialization failed: ", [initializationError localizedDescription]]}];
            return;
        }
        isApproovInitialized = YES;

        // If we don't have an update configuration then we fetch one and write it to local storage
        if (!updateConfig) {
            [CordovaApproovHttpPlugin saveApproovConfigUpdate];
        }
    }
}

// Set up Approov certificate public key pinning
+ (void)setupApproovPublicKeyPinning:(AFURLSessionManager *)manager {
    static char approovAuthenticationChallengeBlockKey;
    @synchronized(manager) {
        AFURLSessionManager* __weak weakManager = manager;
        AFURLSessionDidReceiveAuthenticationChallengeBlock sessionDidReceiveAuthenticationChallengeBlock =
            [manager getSessionDidReceiveAuthenticationChallengeBlock];
        AFURLSessionDidReceiveAuthenticationChallengeBlock approovAuthenticationChallengeBlock =
            (AFURLSessionDidReceiveAuthenticationChallengeBlock)objc_getAssociatedObject(
                manager, &approovAuthenticationChallengeBlockKey);

        if (!sessionDidReceiveAuthenticationChallengeBlock
            || sessionDidReceiveAuthenticationChallengeBlock != approovAuthenticationChallengeBlock) {
            // Define the authentication challenge block for the Approov pinning check
            AFURLSessionDidReceiveAuthenticationChallengeBlock approovVerifyPinning =
                ^NSURLSessionAuthChallengeDisposition(NSURLSession * _Nonnull session,
                     NSURLAuthenticationChallenge * _Nonnull challenge,
                     NSURLCredential * _Nullable * _Nullable credential) {
                @synchronized(manager) {
                    __block NSURLCredential *credentialResult;
                    __block NSURLSessionAuthChallengeDisposition dispositionResult =
                        NSURLSessionAuthChallengePerformDefaultHandling;
                    // Completion handler for call of URLSession:didReceiveChallenge:completionHandler: method,
                    // defined by the NSURLSessionTaskDelegate protocol
                    void (^completionHandler)(NSURLSessionAuthChallengeDisposition, NSURLCredential *) = ^(NSURLSessionAuthChallengeDisposition challengeDisposition, NSURLCredential *credential) {
                            credentialResult = credential;
                            dispositionResult = challengeDisposition;
                        };
                    // Perform AFURLSessionManager's original verification
                    if (sessionDidReceiveAuthenticationChallengeBlock == nil) {
                        // Call AFURLSessionManager's NSURLSessionDelegate method, but first reset AFURLSessionManager's
                        // authentication challenge block to nil, otherwise approovVerifyPinning will be called
                        // recursively from AFURLSessionManager's URLSession:didReceiveChallenge:completionHandler:
                        // method
                        AFURLSessionDidReceiveAuthenticationChallengeBlock approovAuthenticationChallengeBlock =
                            [weakManager getSessionDidReceiveAuthenticationChallengeBlock];
                        [weakManager setSessionDidReceiveAuthenticationChallengeBlock:nil];
                        // Call AFURLSessionManager's original URLSession:didReceiveChallenge:completionHandler:
                        // method
                        [weakManager URLSession:session didReceiveChallenge:challenge
                            completionHandler:completionHandler];
                        // Restore AFURLSessionManager's sessionDidReceiveAuthenticationChallenge block back to the
                        // Approov pinning check
                        [weakManager
                            setSessionDidReceiveAuthenticationChallengeBlock:approovAuthenticationChallengeBlock];
                    }
                    else {
                        // Call AFURLSessionManager's original sessionDidReceiveAuthenticationChallenge block
                        dispositionResult =
                            sessionDidReceiveAuthenticationChallengeBlock(session, challenge, &credentialResult);
                    }
                    // If the challenge failed AFURLSessionManager's original verification, return
                    if (dispositionResult != NSURLSessionAuthChallengeUseCredential
                        && dispositionResult != NSURLSessionAuthChallengePerformDefaultHandling) {
                        *credential = credentialResult;
                        return dispositionResult;
                    }
                    // Otherwise also check Approov pinning
                    [CordovaApproovHttpPlugin URLSession:session didReceiveChallenge:challenge
                        completionHandler:completionHandler];
                    *credential = credentialResult;
                    return dispositionResult;
                }
            };
            // Set the sessionDidReceiveAuthenticationChallenge block for the Approov pinning check
            [manager setSessionDidReceiveAuthenticationChallengeBlock:approovVerifyPinning];
            // Associate approovVerifyPinning with the manager so we can check whether Approov pinning is already
            // set up by checking that the manager's sessionDidReceiveAuthenticationChallenge block is equal to the
            // approovVerifyPinning block associated with the manager
            // see https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjectiveC/Chapters/ocAssociativeReferences.html#//apple_ref/doc/uid/TP30001163-CH24
            objc_setAssociatedObject(manager, &approovAuthenticationChallengeBlockKey, approovVerifyPinning,
                                     OBJC_ASSOCIATION_RETAIN);
        }
        // Otherwise taskDidReceiveAuthenticationChallenge block for the Approov pinning check already set and
        // up-to-date
    }
}

- (void)pluginInitialize {
    [super pluginInitialize];
    NSError *error = nil;
    [CordovaApproovHttpPlugin ensureApproovInitialized:&error];
    if (error) {
        // A fatal error occurred during Approov initialization
        NSException* approovInitializationException = [NSException exceptionWithName:@"ApproovInitializationException"
            reason:@"A fatal error occurred during Approov initialization" userInfo:error.userInfo];
        @throw approovInitializationException;
    }
    approovProtect = ^(AFHTTPSessionManager *manager, NSString *urlString) {
        // update the data hash based on any token binding header
        if (![bindingHeader isEqualToString:@""]) {
            @synchronized(bindingHeader) {
                NSString *headerValue = [manager.requestSerializer valueForHTTPHeaderField: bindingHeader];
                if (headerValue == nil) {
                    NSException* approovMissingBindingHeaderException =
                        [NSException exceptionWithName:@"ApproovMissingBindingHeaderException"
                            reason:@"Request is missing the Approov binding header"
                            userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@%@",
                                @"Request is missing the Approov binding header: ", bindingHeader]}];
                    @throw approovMissingBindingHeaderException;
                }
                [Approov setDataHashInToken:headerValue];
            }
        }
        // Fetch the Approov token
        ApproovTokenFetchResult *approovResult = [Approov fetchApproovTokenAndWait:urlString];

        // provide information about the obtained token or error (note "approov token -check" can
        // be used to check the validity of the token and if you use token annotations they
        // will appear here to determine why a request is being rejected)
        NSURL *url = [NSURL URLWithString:urlString];
        NSLog(@"%@: Approov Token for %@: %@", TAG, [url host], [approovResult loggableToken]);

        // update any dynamic configuration
        if ([approovResult isConfigChanged]) {
            // Save the updated Approov configuration
            [CordovaApproovHttpPlugin saveApproovConfigUpdate];
        }
        NSString *approovToken = [approovResult token];
        ApproovTokenFetchStatus approovStatus = [approovResult status];
        switch (approovStatus) {
        case ApproovTokenFetchStatusSuccess:
        {
            // Token was successfully received
            // Add Approov header containing the token
            [manager.requestSerializer setValue:[NSString stringWithFormat:@"%@%@", APPROOV_TOKEN_PREFIX, approovToken]
                forHTTPHeaderField:APPROOV_HEADER];
            break;
        }
        case ApproovTokenFetchStatusUnknownURL:
            // Provided URL is a for a domain that has not been set up in the Approov Service
            break;
        case ApproovTokenFetchStatusUnprotectedURL:
            // Provided URL does not need an Approov token
            break;
        case ApproovTokenFetchStatusNoApproovService:
            // No token could be obtained, perhaps because Approov services are down
            break;
        default:
        {
            // A fail here means that the SDK could not get an Approov token. Throw an exception containing the
            // state error
            NSException* approovTokenFetchFailedException =
                [NSException exceptionWithName:@"ApproovTokenFetchFailedException"
                    reason:@"Approov could not fetch an Approov token. The unprotected HTTP request must not proceed"
                    userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"%@%@%@",
                        @"Approov could not fetch an Approov token. Status: ",
                        [Approov stringFromApproovTokenFetchStatus:approovStatus],
                        @". The unprotected HTTP request must not proceed"]}];
            @throw approovTokenFetchFailedException;
            // Alternatively invalidate the session
            // [manager invalidateSessionCancelingTasks:YES];
            break;
        }}
        [CordovaApproovHttpPlugin setupApproovPublicKeyPinning:manager];
    };
    [CordovaHttpPlugin addRequestInterceptor:approovProtect];
}

// Report success back to the plugin's JavaScript layer
- (void)reportSuccessForCommand:(CDVInvokedUrlCommand*)command {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dictionary];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// Report failure, including an error description, back to the plugin's JavaScript layer
- (void)reportError:(NSError*)error forCommand:(CDVInvokedUrlCommand*)command {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setObject:[NSNumber numberWithInt:-1] forKey:@"status"];
    [dictionary setObject:[error localizedDescription] forKey:@"error"];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dictionary];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

/**
 * Sets a hash of the given data value into any future Approov tokens obtained in the 'pay'
 * claim. If the data values is transmitted to the API backend along with the
 * Approov token then this allows the backend to check that the data value was indeed
 * known to the app at the time of the token fetch and hasn't been spoofed. If the
 * data is the same as any previous one set then the token does not need to be updated.
 * Otherwise the next token fetch causes a new attestation to fetch a new token. Note that
 * this should not be done frequently due to the additional latency on token fetching that
 * will be caused. The hash appears in the 'pay' claim of the Approov token as a base64
 * encoded string of the SHA256 hash of the data. Note that the data is hashed locally and
 * never sent to the Approov cloud service.
 *
 * @param data is the data whose SHA256 hash is to be included in future Approov tokens
 */
- (void)approovSetDataHashInToken:(CDVInvokedUrlCommand*)command {
    NSString *data = [command.arguments objectAtIndex:0];
    if (data) {
        [Approov setDataHashInToken:data];
        // Report success
        [self reportSuccessForCommand:command];
    } else {
        NSError *error = [NSError errorWithDomain:TAG code:0
            userInfo:@{NSLocalizedDescriptionKey : @"approovSetDataHashInToken data must not be nil"}];
        // Report error
        [self reportError:error forCommand:command];
    }
}

/**
 * Sets a binding header that must be present on all requests using the Approov service. A
 * header should be chosen whose value is unchanging for most requests (such as an
 * Authorization header). A hash of the header value is included in the issued Approov tokens
 * to bind them to the value. This may then be verified by the backend API integration. This
 * method should typically only be called once.
 *
 * @param header is the header to use for Approov token binding
 */
- (void)approovSetBindingHeader:(CDVInvokedUrlCommand*)command {
    NSString *header = [command.arguments objectAtIndex:0];
    if (header) {
        @synchronized(bindingHeader) {
            bindingHeader = header;
        }
        // Report success
        [self reportSuccessForCommand:command];
    } else {
        NSError *error = [NSError errorWithDomain:TAG code:0
            userInfo:@{NSLocalizedDescriptionKey : @"setBindingHeader header must not be nil"}];
        // Report error
        [self reportError:error forCommand:command];
    }
}

// Subject public key info (SPKI) headers for public keys' type and size. Only RSA-2048, RSA-4096, EC-256 and EC-384
// are supported.
static NSDictionary<NSString *, NSDictionary<NSNumber *, NSData *> *> *spkiHeaders;

+ (void)initialize {
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

/* certificate check provided for NSURLSessionDelegate protocol */
+ (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
    completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
{
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

    // Get the Approov pins
    NSDictionary<NSString *, NSArray<NSString *> *> *approovPins = [Approov getPins:@"public-key-sha256"];
    NSString *domain = challenge.protectionSpace.host;
    NSArray<NSString *> *pinsForDomain = approovPins[domain];

    // if we are not pinning then we consider this level of trust to be acceptable
    if (pinsForDomain == nil || [pinsForDomain count] == 0) {
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
        NSData *publicKeyInfo = [CordovaApproovHttpPlugin publicKeyInfoOfCertificate:serverCert];
        if (!publicKeyInfo) {
            completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
            return;
        }

        // compute the SHA-256 hash of the public key info
        NSData *publicKeyInfoHash = [CordovaApproovHttpPlugin sha256:publicKeyInfo];
        NSString *publicKeyInfoHashB64 = [publicKeyInfoHash base64EncodedStringWithOptions:0];

        // check that the hash is the same as at least one of the pins
        for (NSString* pinHashB64 in pinsForDomain) {
            if ([publicKeyInfoHashB64 isEqual:pinHashB64]) {
                completionHandler(NSURLSessionAuthChallengeUseCredential,
                    [NSURLCredential credentialForTrust:serverTrust]);
                return;
            }
        }
    }

    // the presented public key did not match any of the pins
    completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
}

/*
 * gets the subject public key info (SPKI) header depending on a public key's type and size
 */
+ (NSData *)publicKeyInfoHeaderForKey:(SecKeyRef)publicKey {
    // get the SPKI header depending on the key's type and size
    CFDictionaryRef publicKeyAttributes = SecKeyCopyAttributes(publicKey);
    NSString *keyType = CFDictionaryGetValue(publicKeyAttributes, kSecAttrKeyType);
    NSNumber *keyLength = CFDictionaryGetValue(publicKeyAttributes, kSecAttrKeySizeInBits);
    NSData *spkiHeader = spkiHeaders[keyType][keyLength];
    CFRelease(publicKeyAttributes);
    return spkiHeader;
}

/*
 * gets a certificate's subject public key info (SPKI)
 */
+ (NSData *)publicKeyInfoOfCertificate:(SecCertificateRef)certificate
{
    // get the public key from the certificate
    SecKeyRef publicKey;
    if (@available(iOS 12.0, *)) {
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
    if (!publicKey)
        return nil;

    // get the SPKI header depending on the public key's type and size
    NSData *spkiHeader = [CordovaApproovHttpPlugin publicKeyInfoHeaderForKey:publicKey];
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
 * Saves a dynamic update to the Approov configuration. This should be called after every Approov
 * token fetch where isConfigChanged() is set. It saves a new configuration received from the
 * Approov server to the local app storage so that it is available on app startup on the next launch.
 *
 * NOTE: The new configuration may change the results from getPins if new certificate pins
 * have been transmitted to the app from the Approov cloud. If the config is simply saved then
 * these updated pins will not be made available to the app until the next time it is restarted
 * and the Approov SDK is initialized. Where possible you should also update the pins immediately
 * here on the http clients being used by the app.
 */
+ (void)saveApproovConfigUpdate {
    NSString *updateConfig = [Approov fetchConfig];
    if (!updateConfig)
        NSLog(@"%@: Could not get Approov dynamic configuration", TAG);
    else {
        @synchronized(self) {
            NSArray<NSURL *> *URLs = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                inDomains:NSUserDomainMask];
            if (!URLs || [URLs count] == 0) {
                return;
            }
            NSURL *updateConfigURL = [[URLs objectAtIndex:0] URLByAppendingPathComponent:@"approov-update.config"];
            NSError* error = nil;
            [updateConfig writeToURL:updateConfigURL atomically:YES encoding:NSUTF8StringEncoding error:&error];
            if (error) {
                // this is not fatal as the app will receive a new update if the stored one is corrupted in some way
                NSLog(@"%@: Cannot write Approov dynamic configuration: %@", TAG, [error localizedDescription]);
            }
            else {
                NSLog(@"%@: Wrote Approov dynamic configuration", TAG);
            }
        }
    }
}

/**
 * Loads a previously saved dynamic configuration for the Approov SDK. This should be called before initializing the
 * Approov SDK at app startup and the result passed to the Approov initialization call as the updateConfig argument.
 *
 * @return the saved update configuration as a string, or nil if there is no saved update configuration
 */
+ (NSString *)loadApproovConfigUpdate {
    NSArray<NSURL *> *URLs =
        [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    if (!URLs || [URLs count] == 0) {
        return nil;
    }
    NSURL *updateConfigURL = [[URLs objectAtIndex:0] URLByAppendingPathComponent:@"approov-update.config"];
    NSError *error;
    NSString *updateConfig =
        [NSString stringWithContentsOfURL:updateConfigURL encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        // this is not fatal as the app will receive a new update if the stored one is corrupted in some way
        return nil;
    }
    return updateConfig;
}

/**
 * Compute a 32-byte SHA-256 hash of the data.
 *
 * @param data is the data to compute the hash from
 * @return the 32-byte hash or nil for nil input data
 */
+ (NSData *)sha256:(NSData *)data {
    if (!data)
        return nil;

    CC_SHA256_CTX sha256Ctx;
    CC_SHA256_Init(&sha256Ctx);
    CC_SHA256_Update(&sha256Ctx, data.bytes, (CC_LONG)data.length);
    NSMutableData *hash = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(hash.mutableBytes, &sha256Ctx);
    return hash;
}

@end

