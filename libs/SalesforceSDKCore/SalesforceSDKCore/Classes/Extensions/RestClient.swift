import Foundation

/*
 RestClient.swift
 SalesforceSDKCore
 
 Created by Raj Rao on 9/24/19.
 
 Copyright (c) 2019-present, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
import Combine
/// Errors that can be thrown while using RestClient
public enum RestClientError: Error {
    case ApiResponseIsEmpty
    case ApiInvocationFailed(underlyingError: Error, urlResponse: URLResponse?)
    case DecodingFailed(underlyingError: Error)
    case JsonSerialization(underlyingError: Error)
}

public struct RestResponse {
    
    private static let emptyJsonDictionaryArrayResponse = [String:Any]()
    private static let emptyJsonArrayResponse = [[String:Any]]()
    private static let emptyStringResponse = ""
    
    private (set) var data: Data
    private (set) var urlResponse: URLResponse
    
    /// Initializes the RestResponse with a Data object and URLResponse
    /// - Parameter data: Response as raw Data
    /// - Parameter urlResponse: URlResponse from endpoint
    public init(data: Data, urlResponse: URLResponse) {
        self.data = data
        self.urlResponse = urlResponse
    }
    
    /// Parse the response as a Json Dictionary.
    public func asJson() throws -> Any {
        do {
            let jsonData = try JSONSerialization.jsonObject(with: data, options: [])
            return jsonData
        } catch let error {
            throw RestClientError.JsonSerialization(underlyingError: error)
        }
    }
    
    /// Get response as Data object. Use this for retrieving  binary objects
    public func asData() -> Data {
        return self.data
    }
    
    /// Parse response as String
    public func asString() -> String {
        let stringData = String(data: data, encoding: String.Encoding.utf8)
        return stringData ?? RestResponse.emptyStringResponse
    }
    
    /// Decode the response as  a codable
    /// - Parameter type: The type to use for decoding.
    public func asDecodable<T:Decodable>(type: T.Type) throws -> Decodable?  {
        let decoder = JSONDecoder()
        do{
            let object = try decoder.decode(type, from: data)
            return object
        } catch let error {
            throw RestClientError.DecodingFailed(underlyingError: error)
        }
    }
}

extension RestClient {
    
    /// Execute a request.
    /// - Parameter request: RestRequest object
    /// - Parameter completionBlock: The completion block to invoke.
    public func send(request: RestRequest, _ completionBlock: @escaping (Result<RestResponse,RestClientError>) -> () ) {
        request.parseResponse = false
        __send(request, fail: { (error, urlResponse) in
            let apiError = RestClientError.ApiInvocationFailed(underlyingError: error ?? RestClientError.ApiResponseIsEmpty, urlResponse: urlResponse)
            completionBlock(Result.failure(apiError))
        }) { (rawResponse, urlResponse) in
            if let data = rawResponse as? Data,
                let urlResponse = urlResponse {
                let result = RestResponse(data: data, urlResponse: urlResponse)
                completionBlock(Result.success(result))
            } else {
                completionBlock(Result.failure(.ApiResponseIsEmpty))
            }
        }
    }
    
    /// Execute a request.
    /// - Parameter request: Composite Request object
    /// - Parameter completionBlock: The completion block to invoke.
    public func sendComposite(request: CompositeRequest, _ completionBlock: @escaping (Result<CompositeResponse,RestClientError>) -> () ) {
        request.parseResponse = false
        __sendCompositeRESTRequest(request, fail: { (error, urlResponse) in
            let apiError = RestClientError.ApiInvocationFailed(underlyingError: error ?? RestClientError.ApiResponseIsEmpty, urlResponse: urlResponse)
            completionBlock(Result.failure(apiError))
        }) { (response, urlResponse) in
            completionBlock(Result.success(response))
        }
    }
  
}

@available(iOS 13.0, watchOS 6.0, *)
extension RestClient {
    public func publisher(for request: RestRequest) -> Future<RestResponse, RestClientError> {
        return Future<RestResponse, RestClientError> { promise in
            self.send(request: request) { (result) in
                switch result {
                    case .success(let response):
                        promise(.success(response))
                    case .failure(let error):
                        promise(.failure(error))
                }
            }
        }
    }
    
    public func publisher(for request: CompositeRequest) -> Future<CompositeResponse, RestClientError> {
        return Future<CompositeResponse, RestClientError> { promise in
            self.sendComposite(request: request) { (result) in
                switch result {
                    case .success(let response):
                        promise(.success(response))
                    case .failure(let error):
                        promise(.failure(error))
                }
            }
        }
    }
}
