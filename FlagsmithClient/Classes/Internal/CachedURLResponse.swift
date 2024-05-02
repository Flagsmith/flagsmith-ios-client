//
//  CachedURLResponse.swift
//  CachedURLResponse
//
//  Created by Daniel Wichett on 21/06/2023.
//

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

extension CachedURLResponse {
    func response(withExpirationDuration duration: Int) -> CachedURLResponse {
        var cachedResponse = self
        if let httpResponse = cachedResponse.response as? HTTPURLResponse,
           var headers = httpResponse.allHeaderFields as? [String: String],
           let url = httpResponse.url
        {
            // set to 1 year (the max allowed) if the value is 0
            headers["Cache-Control"] = "max-age=\(duration == 0 ? 31_536_000 : duration)"
            headers.removeValue(forKey: "Expires")
            headers.removeValue(forKey: "s-maxage")

            if let newResponse = HTTPURLResponse(url: url, statusCode: httpResponse.statusCode,
                                                 httpVersion: "HTTP/1.1", headerFields: headers)
            {
                cachedResponse = CachedURLResponse(response: newResponse, data: cachedResponse.data,
                                                   userInfo: headers, storagePolicy: cachedResponse.storagePolicy)
            }
        }
        return cachedResponse
    }
}
