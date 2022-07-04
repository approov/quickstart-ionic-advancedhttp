#import "CordovaHttpPlugin.h"
#import "BinaryRequestSerializer.h"
#import "BinaryResponseSerializer.h"
#import "TextResponseSerializer.h"
#import "TextRequestSerializer.h"
#import "SM_AFHTTPSessionManager.h"
#import "SDNetworkActivityIndicator.h"
#import "ApproovService.h"

// this definition should really come from CDVFile.h for the plugin:
//  https://cordova.apache.org/docs/en/11.x/reference/cordova-plugin-file/
// on which this plugin is dependent - however the header does not always seem to be
// visible so we explicitly declare the only method we need here
@interface CDVFile: CDVPlugin
- (NSDictionary *)getDirectoryEntry:(NSString *)target isDirectory:(BOOL)bDirRequest;
@end 

@interface CordovaHttpPlugin()

- (void)addRequest:(NSNumber*)reqId forTask:(NSURLSessionDataTask*)task;
- (void)removeRequest:(NSNumber*)reqId;
- (void)setRequestHeaders:(NSDictionary*)headers forManager:(SM_AFHTTPSessionManager*)manager;
- (void)handleSuccess:(NSMutableDictionary*)dictionary withResponse:(NSHTTPURLResponse*)response andData:(id)data;
- (void)handleError:(NSMutableDictionary*)dictionary withResponse:(NSHTTPURLResponse*)response error:(NSError*)error;
- (NSNumber*)getStatusCode:(NSError*) error;
- (NSMutableDictionary*)copyHeaderFields:(NSDictionary*)headerFields;
- (void)setTimeout:(NSTimeInterval)timeout forManager:(SM_AFHTTPSessionManager*)manager;
- (void)setRedirect:(bool)redirect forManager:(SM_AFHTTPSessionManager*)manager;

@end

@implementation CordovaHttpPlugin {
    SM_AFSecurityPolicy *securityPolicy;
    NSURLCredential *x509Credential;
    NSMutableDictionary *reqDict;
    ApproovService *approovService;
}

- (void)pluginInitialize {
    securityPolicy = [SM_AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    reqDict = [NSMutableDictionary dictionary];
    approovService = [[ApproovService alloc] init];
}

- (void) processApproovResult:(ApproovResult *)result command:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;
    if (result.errorType == nil) {
        if (result.result != nil)
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:result.result];
        else
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }
    else {
        NSMutableDictionary *error = [[NSMutableDictionary alloc] init];
        error[@"type"] = result.errorType;
        error[@"message"] = result.errorMessage;
        if (result.rejectionARC != nil)
            error[@"rejectionARC"] = result.rejectionARC;
        if (result.rejectionReasons != nil)
            error[@"rejectionReasons"] = result.rejectionReasons;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:error];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) approovInitialize:(CDVInvokedUrlCommand*)command {
    NSString *config = [command.arguments objectAtIndex:0];
    ApproovResult *result = [approovService initialize:config];
    [self processApproovResult:result command:command];
}

- (void) approovSetProceedOnNetworkFail:(CDVInvokedUrlCommand*)command {
    [approovService setProceedOnNetworkFail];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) approovSetTokenHeader:(CDVInvokedUrlCommand*)command {
    NSString *header = [command.arguments objectAtIndex:0];
    NSString *prefix = [command.arguments objectAtIndex:1];
    [approovService setTokenHeader:header prefix:prefix];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) approovSetBindingHeader:(CDVInvokedUrlCommand*)command {
    NSString *header = [command.arguments objectAtIndex:0];
    [approovService setBindingHeader:header];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) approovAddSubstitutionHeader:(CDVInvokedUrlCommand*)command {
    NSString *header = [command.arguments objectAtIndex:0];
    NSString *requiredPrefix = [command.arguments objectAtIndex:1];
    [approovService addSubstitutionHeader:header requiredPrefix:requiredPrefix];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) approovRemoveSubstitutionHeader:(CDVInvokedUrlCommand*)command {
    NSString *header = [command.arguments objectAtIndex:0];
    [approovService removeSubstitutionHeader:header];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) approovAddSubstitutionQueryParam:(CDVInvokedUrlCommand*)command {
    NSString *key = [command.arguments objectAtIndex:0];
    [approovService addSubstitutionQueryParam:key];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) approovRemoveSubstitutionQueryParam:(CDVInvokedUrlCommand*)command {
    NSString *key = [command.arguments objectAtIndex:0];
    [approovService removeSubstitutionQueryParam:key];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) approovAddExclusionURLRegex:(CDVInvokedUrlCommand*)command {
    NSString *urlRegex = [command.arguments objectAtIndex:0];
    [approovService addExclusionURLRegex:urlRegex];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) approovRemoveExclusionURLRegex:(CDVInvokedUrlCommand*)command {
    NSString *urlRegex = [command.arguments objectAtIndex:0];
    [approovService removeExclusionURLRegex:urlRegex];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) approovPrefetch:(CDVInvokedUrlCommand*)command {
    ApproovService *service = approovService;
    [self.commandDelegate runInBackground:^{
        ApproovResult *result = [service prefetch];
        [self processApproovResult:result command:command];
    }];
}

- (void) approovPrecheck:(CDVInvokedUrlCommand*)command {
    ApproovService *service = approovService;
    [self.commandDelegate runInBackground:^{
        ApproovResult *result = [service precheck];
        [self processApproovResult:result command:command];
    }];
}

- (void) approovGetDeviceID:(CDVInvokedUrlCommand*)command {
    ApproovResult *result = [approovService getDeviceID];
    [self processApproovResult:result command:command];
}

- (void) approovSetDataHashInToken:(CDVInvokedUrlCommand*)command {
    NSString *data = [command.arguments objectAtIndex:0];
    ApproovResult *result = [approovService setDataHashInToken:data];
    [self processApproovResult:result command:command];
}

- (void) approovFetchToken:(CDVInvokedUrlCommand*)command {
    ApproovService *service = approovService;
    NSString *url = [command.arguments objectAtIndex:0];
    [self.commandDelegate runInBackground:^{
        ApproovResult *result = [service fetchToken:url];
        [self processApproovResult:result command:command];
    }];
}

- (void) approovGetMessageSignature:(CDVInvokedUrlCommand*)command {
    NSString *message = [command.arguments objectAtIndex:0];
    ApproovResult *result = [approovService getMessageSignature:message];
    [self processApproovResult:result command:command];
}

- (void) approovFetchSecureString:(CDVInvokedUrlCommand*)command {
    ApproovService *service = approovService;
    NSString *key = [command.arguments objectAtIndex:0];
    NSString *newDef = [command.arguments objectAtIndex:1];
    if ([newDef isEqual:[NSNull null]])
        newDef = nil;
    [self.commandDelegate runInBackground:^{
        ApproovResult *result = [service fetchSecureString:key newDef:newDef];
        [self processApproovResult:result command:command];
    }];
}

- (void) approovFetchCustomJWT:(CDVInvokedUrlCommand*)command {
    ApproovService *service = approovService;
    NSString *payload = [command.arguments objectAtIndex:0];
    [self.commandDelegate runInBackground:^{
        ApproovResult *result = [service fetchCustomJWT:payload];
        [self processApproovResult:result command:command];
    }];
}

- (void)addRequest:(NSNumber*)reqId forTask:(NSURLSessionDataTask*)task {
    [reqDict setObject:task forKey:reqId];
}

- (void)removeRequest:(NSNumber*)reqId {
    [reqDict removeObjectForKey:reqId];
}

- (void)setRequestSerializer:(NSString*)serializerName forManager:(SM_AFHTTPSessionManager*)manager {
    if ([serializerName isEqualToString:@"json"]) {
        manager.requestSerializer = [SM_AFJSONRequestSerializer serializer];
    } else if ([serializerName isEqualToString:@"utf8"]) {
        manager.requestSerializer = [TextRequestSerializer serializer];
    } else if ([serializerName isEqualToString:@"raw"]) {
        manager.requestSerializer = [BinaryRequestSerializer serializer];
    } else {
        manager.requestSerializer = [SM_AFHTTPRequestSerializer serializer];
    }
}

- (void)setupAuthChallengeBlock:(SM_AFHTTPSessionManager*)manager {
    [manager setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(
        NSURLSession * _Nonnull session,
        NSURLAuthenticationChallenge * _Nonnull challenge,
        NSURLCredential * _Nullable __autoreleasing * _Nullable credential
    ) {
        if ([challenge.protectionSpace.authenticationMethod isEqualToString: NSURLAuthenticationMethodServerTrust]) {
            *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];

            if (![self->securityPolicy evaluateServerTrust:challenge.protectionSpace.serverTrust forDomain:challenge.protectionSpace.host]) {
                return NSURLSessionAuthChallengeRejectProtectionSpace;
            }

            if (credential) {
                return NSURLSessionAuthChallengeUseCredential;
            }
        }

        if ([challenge.protectionSpace.authenticationMethod isEqualToString: NSURLAuthenticationMethodClientCertificate] && self->x509Credential) {
            *credential = self->x509Credential;
            return NSURLSessionAuthChallengeUseCredential;
        }

        return NSURLSessionAuthChallengePerformDefaultHandling;
    }];
}

- (void)setRequestHeaders:(NSDictionary*)headers forManager:(SM_AFHTTPSessionManager*)manager {
    [headers enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [manager.requestSerializer setValue:obj forHTTPHeaderField:key];
    }];
}

- (void)setRedirect:(bool)followRedirect forManager:(SM_AFHTTPSessionManager*)manager {
    [manager setTaskWillPerformHTTPRedirectionBlock:^NSURLRequest * _Nonnull(NSURLSession * _Nonnull session,
        NSURLSessionTask * _Nonnull task, NSURLResponse * _Nonnull response, NSURLRequest * _Nonnull request) {

        if (followRedirect) {
            return request;
        } else {
            return nil;
        }
    }];
}

- (void)setTimeout:(NSTimeInterval)timeout forManager:(SM_AFHTTPSessionManager*)manager {
    [manager.requestSerializer setTimeoutInterval:timeout];
}

- (void)setResponseSerializer:(NSString*)responseType forManager:(SM_AFHTTPSessionManager*)manager {
    if ([responseType isEqualToString: @"text"] || [responseType isEqualToString: @"json"]) {
        manager.responseSerializer = [TextResponseSerializer serializer];
    } else {
        manager.responseSerializer = [BinaryResponseSerializer serializer];
    }
}


- (void)handleSuccess:(NSMutableDictionary*)dictionary withResponse:(NSHTTPURLResponse*)response andData:(id)data {
    if (response != nil) {
        [dictionary setValue:response.URL.absoluteString forKey:@"url"];
        [dictionary setObject:[NSNumber numberWithInt:(int)response.statusCode] forKey:@"status"];
        [dictionary setObject:[self copyHeaderFields:response.allHeaderFields] forKey:@"headers"];
    }

    if (data != nil) {
        [dictionary setObject:data forKey:@"data"];
    }
}

- (void)handleError:(NSMutableDictionary*)dictionary withResponse:(NSHTTPURLResponse*)response error:(NSError*)error {
    bool aborted = error.code == NSURLErrorCancelled;
    if(aborted){
        [dictionary setObject:[NSNumber numberWithInt:-8] forKey:@"status"];
        [dictionary setObject:@"Request was aborted" forKey:@"error"];
    }
    if (response != nil) {
        [dictionary setValue:response.URL.absoluteString forKey:@"url"];
        [dictionary setObject:[self copyHeaderFields:response.allHeaderFields] forKey:@"headers"];
        if(!aborted){
            [dictionary setObject:[NSNumber numberWithInt:(int)response.statusCode] forKey:@"status"];
            if (error.userInfo[SM_AFNetworkingOperationFailingURLResponseBodyErrorKey]) {
                [dictionary setObject:error.userInfo[SM_AFNetworkingOperationFailingURLResponseBodyErrorKey] forKey:@"error"];
            }
        }
    } else if(!aborted) {
        [dictionary setObject:[self getStatusCode:error] forKey:@"status"];
        [dictionary setObject:[error localizedDescription] forKey:@"error"];
    }
}

- (void)handleException:(NSException*)exception withCommand:(CDVInvokedUrlCommand*)command {
  CordovaHttpPlugin* __weak weakSelf = self;

  NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
  [dictionary setValue:exception.userInfo forKey:@"error"];
  // Approov change to use the localized description here if available to provide a direct
  // error message from an Approov generated exception
  NSString *errorDescription = [exception.userInfo valueForKey:NSLocalizedDescriptionKey];
  if (errorDescription != nil)
    [dictionary setValue:errorDescription forKey:@"error"];
  [dictionary setObject:[NSNumber numberWithInt:-1] forKey:@"status"];

  CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dictionary];
  [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (NSNumber*)getStatusCode:(NSError*) error {
    switch ([error code]) {
        case -1001:
            // timeout
            return [NSNumber numberWithInt:-4];
        case -1002:
            // unsupported URL
            return [NSNumber numberWithInt:-5];
        case -1003:
            // server not found
            return [NSNumber numberWithInt:-3];
        case -1009:
            // no connection
            return [NSNumber numberWithInt:-6];
        case -1200: // secure connection failed
        case -1201: // certificate has bad date
        case -1202: // certificate untrusted
        case -1203: // certificate has unknown root
        case -1204: // certificate is not yet valid
            // configuring SSL failed
            return [NSNumber numberWithInt:-2];
        default:
            return [NSNumber numberWithInt:-1];
    }
}

- (NSMutableDictionary*)copyHeaderFields:(NSDictionary *)headerFields {
    NSMutableDictionary *headerFieldsCopy = [[NSMutableDictionary alloc] initWithCapacity:headerFields.count];
    NSString *headerKeyCopy;

    for (NSString *headerKey in headerFields.allKeys) {
        headerKeyCopy = [[headerKey mutableCopy] lowercaseString];
        [headerFieldsCopy setValue:[headerFields objectForKey:headerKey] forKey:headerKeyCopy];
    }

    return headerFieldsCopy;
}

- (void)executeRequestWithoutData:(CDVInvokedUrlCommand*)command withMethod:(NSString*) method {
    SM_AFHTTPSessionManager *manager = [SM_AFHTTPSessionManager manager];

    NSString *url = [command.arguments objectAtIndex:0];
    NSDictionary *headers = [command.arguments objectAtIndex:1];
    NSTimeInterval connectTimeout = [[command.arguments objectAtIndex:2] doubleValue];
    NSTimeInterval readTimeout = [[command.arguments objectAtIndex:3] doubleValue];
    bool followRedirect = [[command.arguments objectAtIndex:4] boolValue];
    NSString *responseType = [command.arguments objectAtIndex:5];
    NSNumber *reqId = [command.arguments objectAtIndex:6];

    [self setRequestSerializer: @"default" forManager: manager];
    [self setupAuthChallengeBlock: manager];
    [self setRequestHeaders: headers forManager: manager];
    [self setTimeout:readTimeout forManager:manager];
    [self setRedirect:followRedirect forManager:manager];
    [self setResponseSerializer:responseType forManager:manager];

    CordovaHttpPlugin* __weak weakSelf = self;
    [[SDNetworkActivityIndicator sharedActivityIndicator] startActivity];

    @try {
        url = [approovService addApproovToSessionManager:manager URL:url];
        void (^onSuccess)(NSURLSessionTask *, id) = ^(NSURLSessionTask *task, id responseObject) {
            [weakSelf removeRequest:reqId];

            NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

            // no 'body' for HEAD request, omitting 'data'
            if ([method isEqualToString:@"HEAD"]) {
                [self handleSuccess:dictionary withResponse:(NSHTTPURLResponse*)task.response andData:nil];
            } else {
                [self handleSuccess:dictionary withResponse:(NSHTTPURLResponse*)task.response andData:responseObject];
            }

            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dictionary];
            [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            [[SDNetworkActivityIndicator sharedActivityIndicator] stopActivity];
            [manager invalidateSessionCancelingTasks:YES];
        };

        void (^onFailure)(NSURLSessionTask *, NSError *) = ^(NSURLSessionTask *task, NSError *error) {
            [weakSelf removeRequest:reqId];

            NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
            [self handleError:dictionary withResponse:(NSHTTPURLResponse*)task.response error:error];

            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dictionary];
            [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            [[SDNetworkActivityIndicator sharedActivityIndicator] stopActivity];
            [manager invalidateSessionCancelingTasks:YES];
        };

        NSURLSessionDataTask *task = [manager downloadTaskWithHTTPMethod:method URLString:url parameters:nil progress:nil success:onSuccess failure:onFailure];
        [self addRequest:reqId forTask:task];
    }
    @catch (NSException *exception) {
        [[SDNetworkActivityIndicator sharedActivityIndicator] stopActivity];
        [self handleException:exception withCommand:command];
    }
}

- (void)executeRequestWithData:(CDVInvokedUrlCommand*)command withMethod:(NSString*)method {
    SM_AFHTTPSessionManager *manager = [SM_AFHTTPSessionManager manager];

    NSString *url = [command.arguments objectAtIndex:0];
    NSDictionary *data = [command.arguments objectAtIndex:1];
    NSString *serializerName = [command.arguments objectAtIndex:2];
    NSDictionary *headers = [command.arguments objectAtIndex:3];
    NSTimeInterval connectTimeout = [[command.arguments objectAtIndex:4] doubleValue];
    NSTimeInterval readTimeout = [[command.arguments objectAtIndex:5] doubleValue];
    bool followRedirect = [[command.arguments objectAtIndex:6] boolValue];
    NSString *responseType = [command.arguments objectAtIndex:7];
    NSNumber *reqId = [command.arguments objectAtIndex:8];

    [self setRequestSerializer: serializerName forManager: manager];
    [self setupAuthChallengeBlock: manager];
    [self setRequestHeaders: headers forManager: manager];
    [self setTimeout:readTimeout forManager:manager];
    [self setRedirect:followRedirect forManager:manager];
    [self setResponseSerializer:responseType forManager:manager];

    CordovaHttpPlugin* __weak weakSelf = self;
    [[SDNetworkActivityIndicator sharedActivityIndicator] startActivity];

    @try {
        url = [approovService addApproovToSessionManager:manager URL:url];
        void (^constructBody)(id<AFMultipartFormData>) = ^(id<AFMultipartFormData> formData) {
            NSArray *buffers = [data mutableArrayValueForKey:@"buffers"];
            NSArray *fileNames = [data mutableArrayValueForKey:@"fileNames"];
            NSArray *names = [data mutableArrayValueForKey:@"names"];
            NSArray *types = [data mutableArrayValueForKey:@"types"];

            NSError *error;

            for (int i = 0; i < [buffers count]; ++i) {
                NSData *decodedBuffer = [[NSData alloc] initWithBase64EncodedString:[buffers objectAtIndex:i] options:0];
                NSString *fileName = [fileNames objectAtIndex:i];
                NSString *partName = [names objectAtIndex:i];
                NSString *partType = [types objectAtIndex:i];

                if (![fileName isEqual:[NSNull null]]) {
                    [formData appendPartWithFileData:decodedBuffer name:partName fileName:fileName mimeType:partType];
                } else {
                    [formData appendPartWithFormData:decodedBuffer name:[names objectAtIndex:i]];
                }
            }

            if (error) {
                [weakSelf removeRequest:reqId];

                NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
                [dictionary setObject:[NSNumber numberWithInt:400] forKey:@"status"];
                [dictionary setObject:@"Could not add part to multipart request body." forKey:@"error"];
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dictionary];
                [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                [[SDNetworkActivityIndicator sharedActivityIndicator] stopActivity];
                return;
            }
        };

        void (^onSuccess)(NSURLSessionTask *, id) = ^(NSURLSessionTask *task, id responseObject) {
            [weakSelf removeRequest:reqId];

            NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
            [self handleSuccess:dictionary withResponse:(NSHTTPURLResponse*)task.response andData:responseObject];

            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dictionary];
            [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            [[SDNetworkActivityIndicator sharedActivityIndicator] stopActivity];
            [manager invalidateSessionCancelingTasks:YES];
        };

        void (^onFailure)(NSURLSessionTask *, NSError *) = ^(NSURLSessionTask *task, NSError *error) {
            [weakSelf removeRequest:reqId];

            NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
            [self handleError:dictionary withResponse:(NSHTTPURLResponse*)task.response error:error];

            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dictionary];
            [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            [[SDNetworkActivityIndicator sharedActivityIndicator] stopActivity];
            [manager invalidateSessionCancelingTasks:YES];
        };

        NSURLSessionDataTask *task;
        if ([serializerName isEqualToString:@"multipart"]) {
            task = [manager uploadTaskWithHTTPMethod:method URLString:url parameters:nil constructingBodyWithBlock:constructBody progress:nil success:onSuccess failure:onFailure];
        } else {
            task = [manager uploadTaskWithHTTPMethod:method URLString:url parameters:data progress:nil success:onSuccess failure:onFailure];
        }
        [self addRequest:reqId forTask:task];
    }
    @catch (NSException *exception) {
        [[SDNetworkActivityIndicator sharedActivityIndicator] stopActivity];
        [self handleException:exception withCommand:command];
    }
}

- (void)setServerTrustMode:(CDVInvokedUrlCommand*)command {
    NSString *certMode = [command.arguments objectAtIndex:0];

    if ([certMode isEqualToString: @"default"] || [certMode isEqualToString: @"legacy"]) {
        securityPolicy = [SM_AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
        securityPolicy.allowInvalidCertificates = NO;
        securityPolicy.validatesDomainName = YES;
    } else if ([certMode isEqualToString: @"nocheck"]) {
        securityPolicy = [SM_AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
        securityPolicy.allowInvalidCertificates = YES;
        securityPolicy.validatesDomainName = NO;
    } else if ([certMode isEqualToString: @"pinned"]) {
        securityPolicy = [SM_AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate];
        securityPolicy.allowInvalidCertificates = NO;
        securityPolicy.validatesDomainName = YES;
    }

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setClientAuthMode:(CDVInvokedUrlCommand*)command {
    CDVPluginResult* pluginResult;
    NSString *mode = [command.arguments objectAtIndex:0];

    if ([mode isEqualToString:@"none"]) {
      x509Credential = nil;
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }

    if ([mode isEqualToString:@"systemstore"]) {
      NSString *alias = [command.arguments objectAtIndex:1];

      // TODO

      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"mode 'systemstore' is not supported on iOS"];
    }

    if ([mode isEqualToString:@"buffer"]) {
        CFDataRef container = (__bridge CFDataRef) [command.arguments objectAtIndex:2];
        CFStringRef password = (__bridge CFStringRef) [command.arguments objectAtIndex:3];

        const void *keys[] = { kSecImportExportPassphrase };
        const void *values[] = { password };

        CFDictionaryRef options = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
        CFArrayRef items;
        OSStatus securityError = SecPKCS12Import(container, options, &items);
        CFRelease(options);

        if (securityError != noErr) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
        } else {
            CFDictionaryRef identityDict = CFArrayGetValueAtIndex(items, 0);
            SecIdentityRef identity = (SecIdentityRef)CFDictionaryGetValue(identityDict, kSecImportItemIdentity);
            SecTrustRef trust = (SecTrustRef)CFDictionaryGetValue(identityDict, kSecImportItemTrust);

            int count = (int)SecTrustGetCertificateCount(trust);
            NSMutableArray* trustCertificates = nil;
            if (count > 1) {
                trustCertificates = [NSMutableArray arrayWithCapacity:SecTrustGetCertificateCount(trust)];
                for (int i=1;i<count; ++i) {
                    [trustCertificates addObject:(id)SecTrustGetCertificateAtIndex(trust, i)];
                }
            }

            self->x509Credential = [NSURLCredential credentialWithIdentity:identity certificates: trustCertificates persistence:NSURLCredentialPersistenceForSession];
            CFRelease(items);

            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)post:(CDVInvokedUrlCommand*)command {
    [self executeRequestWithData: command withMethod:@"POST"];
}

- (void)put:(CDVInvokedUrlCommand*)command {
    [self executeRequestWithData: command withMethod:@"PUT"];
}

- (void)patch:(CDVInvokedUrlCommand*)command {
    [self executeRequestWithData: command withMethod:@"PATCH"];
}

- (void)get:(CDVInvokedUrlCommand*)command {
    [self executeRequestWithoutData: command withMethod:@"GET"];
}

- (void)delete:(CDVInvokedUrlCommand*)command {
    [self executeRequestWithoutData: command withMethod:@"DELETE"];
}

- (void)head:(CDVInvokedUrlCommand*)command {
    [self executeRequestWithoutData: command withMethod:@"HEAD"];
}

- (void)options:(CDVInvokedUrlCommand*)command {
    [self executeRequestWithoutData: command withMethod:@"OPTIONS"];
}

- (void)uploadFiles:(CDVInvokedUrlCommand*)command {
    SM_AFHTTPSessionManager *manager = [SM_AFHTTPSessionManager manager];

    NSString *url = [command.arguments objectAtIndex:0];
    NSDictionary *headers = [command.arguments objectAtIndex:1];
    NSArray *filePaths = [command.arguments objectAtIndex: 2];
    NSArray *names = [command.arguments objectAtIndex: 3];
    NSTimeInterval connectTimeout = [[command.arguments objectAtIndex:4] doubleValue];
    NSTimeInterval readTimeout = [[command.arguments objectAtIndex:5] doubleValue];
    bool followRedirect = [[command.arguments objectAtIndex:6] boolValue];
    NSString *responseType = [command.arguments objectAtIndex:7];
    NSNumber *reqId = [command.arguments objectAtIndex:8];

    [self setRequestHeaders: headers forManager: manager];
    [self setTimeout:readTimeout forManager:manager];
    [self setRedirect:followRedirect forManager:manager];
    [self setResponseSerializer:responseType forManager:manager];

    CordovaHttpPlugin* __weak weakSelf = self;
    [[SDNetworkActivityIndicator sharedActivityIndicator] startActivity];

    @try {
        url = [approovService addApproovToSessionManager:manager URL:url];
        NSURLSessionDataTask *task = [manager POST:url parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
            NSError *error;
            for (int i = 0; i < [filePaths count]; i++) {
                NSString *filePath = (NSString *) [filePaths objectAtIndex:i];
                NSString *uploadName = (NSString *) [names objectAtIndex:i];
                NSURL *fileURL = [NSURL URLWithString: filePath];
                [formData appendPartWithFileURL:fileURL name:uploadName error:&error];
            }
            if (error) {
                [weakSelf removeRequest:reqId];

                NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
                [dictionary setObject:[NSNumber numberWithInt:500] forKey:@"status"];
                [dictionary setObject:@"Could not add file to post body." forKey:@"error"];
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dictionary];
                [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                [[SDNetworkActivityIndicator sharedActivityIndicator] stopActivity];
                return;
            }
        } progress:nil success:^(NSURLSessionTask *task, id responseObject) {
            [weakSelf removeRequest:reqId];

            NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
            [self handleSuccess:dictionary withResponse:(NSHTTPURLResponse*)task.response andData:responseObject];

            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dictionary];
            [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            [[SDNetworkActivityIndicator sharedActivityIndicator] stopActivity];
        } failure:^(NSURLSessionTask *task, NSError *error) {
            [weakSelf removeRequest:reqId];

            NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
            [self handleError:dictionary withResponse:(NSHTTPURLResponse*)task.response error:error];

            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dictionary];
            [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            [[SDNetworkActivityIndicator sharedActivityIndicator] stopActivity];
        }];
        [self addRequest:reqId forTask:task];
    }
    @catch (NSException *exception) {
        [[SDNetworkActivityIndicator sharedActivityIndicator] stopActivity];
        [self handleException:exception withCommand:command];
    }
}

- (void)downloadFile:(CDVInvokedUrlCommand*)command {
    SM_AFHTTPSessionManager *manager = [SM_AFHTTPSessionManager manager];
    manager.responseSerializer = [SM_AFHTTPResponseSerializer serializer];

    NSString *url = [command.arguments objectAtIndex:0];
    NSDictionary *headers = [command.arguments objectAtIndex:1];
    NSString *filePath = [command.arguments objectAtIndex: 2];
    NSTimeInterval connectTimeout = [[command.arguments objectAtIndex:3] doubleValue];
    NSTimeInterval readTimeout = [[command.arguments objectAtIndex:4] doubleValue];
    bool followRedirect = [[command.arguments objectAtIndex:5] boolValue];
    NSNumber *reqId = [command.arguments objectAtIndex:6];

    [self setRequestHeaders: headers forManager: manager];
    [self setupAuthChallengeBlock: manager];
    [self setTimeout:readTimeout forManager:manager];
    [self setRedirect:followRedirect forManager:manager];

    if ([filePath hasPrefix:@"file://"]) {
        filePath = [filePath substringFromIndex:7];
    }

    CordovaHttpPlugin* __weak weakSelf = self;
    [[SDNetworkActivityIndicator sharedActivityIndicator] startActivity];

    @try {
        url = [approovService addApproovToSessionManager:manager URL:url];
        NSURLSessionDataTask *task = [manager GET:url parameters:nil progress: nil success:^(NSURLSessionTask *task, id responseObject) {
            [weakSelf removeRequest:reqId];
            /*
             *
             * Licensed to the Apache Software Foundation (ASF) under one
             * or more contributor license agreements.  See the NOTICE file
             * distributed with this work for additional information
             * regarding copyright ownership.  The ASF licenses this file
             * to you under the Apache License, Version 2.0 (the
             * "License"); you may not use this file except in compliance
             * with the License.  You may obtain a copy of the License at
             *
             *   http://www.apache.org/licenses/LICENSE-2.0
             *
             * Unless required by applicable law or agreed to in writing,
             * software distributed under the License is distributed on an
             * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
             * KIND, either express or implied.  See the License for the
             * specific language governing permissions and limitations
             * under the License.
             *
             * Modified by Andrew Stephan for Sync OnSet
             *
             */
            // Download response is okay; begin streaming output to file
            NSString* parentPath = [filePath stringByDeletingLastPathComponent];

            // create parent directories if needed
            NSError *error;
            if ([[NSFileManager defaultManager] createDirectoryAtPath:parentPath withIntermediateDirectories:YES attributes:nil error:&error] == NO) {
                NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
                [dictionary setObject:[NSNumber numberWithInt:500] forKey:@"status"];
                if (error) {
                    [dictionary setObject:[NSString stringWithFormat:@"Could not create path to save downloaded file: %@", [error localizedDescription]] forKey:@"error"];
                } else {
                    [dictionary setObject:@"Could not create path to save downloaded file" forKey:@"error"];
                }
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dictionary];
                [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                [[SDNetworkActivityIndicator sharedActivityIndicator] stopActivity];
                return;
            }
            NSData *data = (NSData *)responseObject;
            if (![data writeToFile:filePath atomically:YES]) {
                NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
                [dictionary setObject:[NSNumber numberWithInt:500] forKey:@"status"];
                [dictionary setObject:@"Could not write the data to the given filePath." forKey:@"error"];
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dictionary];
                [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                [[SDNetworkActivityIndicator sharedActivityIndicator] stopActivity];
                return;
            }

            id filePlugin = [self.commandDelegate getCommandInstance:@"File"];
            NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
            [self handleSuccess:dictionary withResponse:(NSHTTPURLResponse*)task.response andData:nil];
            [dictionary setObject:[filePlugin getDirectoryEntry:filePath isDirectory:NO] forKey:@"file"];

            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dictionary];
            [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            [[SDNetworkActivityIndicator sharedActivityIndicator] stopActivity];
        } failure:^(NSURLSessionTask *task, NSError *error) {
            [weakSelf removeRequest:reqId];
            NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
            [self handleError:dictionary withResponse:(NSHTTPURLResponse*)task.response error:error];
            [dictionary setObject:@"There was an error downloading the file" forKey:@"error"];

            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dictionary];
            [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            [[SDNetworkActivityIndicator sharedActivityIndicator] stopActivity];
        }];
        [self addRequest:reqId forTask:task];
    }
    @catch (NSException *exception) {
        [[SDNetworkActivityIndicator sharedActivityIndicator] stopActivity];
        [self handleException:exception withCommand:command];
    }
}

- (void)abort:(CDVInvokedUrlCommand*)command {

    NSNumber *reqId = [command.arguments objectAtIndex:0];

    CDVPluginResult *pluginResult;
    bool removed = false;
    NSURLSessionDataTask *task = [reqDict objectForKey:reqId];
    if(task){
        @try{
            [task cancel];
            removed = true;
        } @catch (NSException *exception) {
            NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
            [dictionary setValue:exception.userInfo forKey:@"error"];
            [dictionary setObject:[NSNumber numberWithInt:-1] forKey:@"status"];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dictionary];
        }
    }

    if(!pluginResult){
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [dictionary setObject:[NSNumber numberWithBool:removed] forKey:@"aborted"];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dictionary];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

@end
