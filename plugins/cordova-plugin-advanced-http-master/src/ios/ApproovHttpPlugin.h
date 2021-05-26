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

#import <Foundation/Foundation.h>


@interface ApproovHttpPlugin:NSObject
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
 * @param data (command.arguments[0]) is the data whose SHA256 hash is to be included in future Approov tokens
 */
- (void)setDataHashInToken:(NSString*) data;

/**
 * Sets a binding header that must be present on all requests using the Approov service. A
 * header should be chosen whose value is unchanging for most requests (such as an
 * Authorization header). A hash of the header value is included in the issued Approov tokens
 * to bind them to the value. This may then be verified by the backend API integration. This
 * method should typically only be called once.
 *
 * @param header (command.arguments[0]) is the header to use for Approov token binding
 */
- (void)setBindingHeader:(NSString*) header;

- (void)initializeHeaders;
- (void)initializeApproov;

@end
