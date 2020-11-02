//
//  Json.swift
//  Anchors Away
//
//  Created by Leslie Helou on 09/24/2020.
//  Copyright © 2020 Leslie Helou. All rights reserved.
//

import Cocoa

class Json: NSObject, URLSessionDelegate, URLSessionDataDelegate, URLSessionTaskDelegate {
    
    let defaults = UserDefaults.standard
    
    func getRecord(serverUrl: String, token: String, theEndpoint: String, completion: @escaping (_ result: [String:AnyObject]) -> Void) {

        let getRecordQ = OperationQueue() // DispatchQueue(label: "com.jamf.getRecordQ", qos: DispatchQoS.background)
    
        URLCache.shared.removeAllCachedResponses()
        var existingDestString = "\(serverUrl)/api/v2/\(theEndpoint)"
        
        existingDestString = existingDestString.replacingOccurrences(of: "//api/v2", with: "/api/v2")
        
//        if LogLevel.debug { WriteToLog().message(stringOfText: "[Json.getRecord] Looking up: \(existingDestUrl)\n") }
//        print("[Json.getRecord] existing endpoints URL: \(existingDestUrl)")

//        print("check")
        let existingDestUrl = URL(string: existingDestString)
        var jsonRequest = URLRequest(url: existingDestUrl!)

        let semaphore = DispatchSemaphore(value: 0)
        getRecordQ.maxConcurrentOperationCount = 4
        getRecordQ.addOperation {
            
            jsonRequest.httpMethod = "GET"
            let destConf = URLSessionConfiguration.default
            destConf.httpAdditionalHeaders = ["Authorization" : "Bearer \(token)", "Content-Type" : "application/json", "Accept" : "application/json"]
            let destSession = Foundation.URLSession(configuration: destConf, delegate: self, delegateQueue: OperationQueue.main)
            let task = destSession.dataTask(with: jsonRequest as URLRequest, completionHandler: {
                (data, response, error) -> Void in
                if let httpResponse = response as? HTTPURLResponse {
//                    print("[Json.getRecord] httpResponse: \(String(describing: httpResponse))")
                    if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                        do {
                            let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                            if let endpointJSON = json as? [String:AnyObject] {
//                                if LogLevel.debug { WriteToLog().message(stringOfText: "[Json.getRecord] \(endpointJSON)\n") }
//                                print("[Json.getRecord] endpointJSON: \(endpointJSON)")
                                completion(endpointJSON)
                            } else {
//                                WriteToLog().message(stringOfText: "[Json.getRecord] error parsing JSON for \(existingDestUrl)\n")
                                completion([:])
                            }
                        }
                    } else {
                        print("[Json.getRecord] error HTTP Status Code: \(httpResponse.statusCode)\n")
                        if "\(httpResponse.statusCode)" == "401" {
                            Alert().display(header: "Alert", message: "Verify username and password.")
                        }
//                        WriteToLog().message(stringOfText: "[Json.getRecord] error HTTP Status Code: \(httpResponse.statusCode)\n")
                        completion([:])
                    }
                } else {
//                    WriteToLog().message(stringOfText: "[Json.getRecord] error parsing JSON for \(existingDestUrl)\n")
                    completion([:])
                }   // if let httpResponse - end
                semaphore.signal()
                if error != nil {
                }
            })  // let task = destSession - end
            //print("GET")
            task.resume()
        }   // getRecordQ - end
    }

    func putRecord(serverUrl: String, token: String, theEndpoint: String, prestage: [String: Any], completion: @escaping (_ result: [String:[String:Any]]) -> Void) {

        let getRecordQ = OperationQueue() // DispatchQueue(label: "com.jamf.getRecordQ", qos: DispatchQoS.background)

        URLCache.shared.removeAllCachedResponses()
        var existingDestUrl = ""

        existingDestUrl = "\(serverUrl)/api/v2/\(theEndpoint)"
        existingDestUrl = existingDestUrl.replacingOccurrences(of: "//api/v2", with: "/api/v2")

//        if LogLevel.debug { WriteToLog().message(stringOfText: "[Json.getRecord] Looking up: \(existingDestUrl)\n") }
//        print("[Json.putRecord] existing endpoints URL: \(existingDestUrl)")
//        print("[Json.putRecord] passed prestage: \(prestage)")

        var jsonRequest = URLRequest(url: URL(string: existingDestUrl)!)

        guard let JSONSerializedPrestage = try? JSONSerialization.data(withJSONObject: prestage, options: []) else {
            return
        }

//        let encodedPrestage = JSONSerializedPrestage

//        print("[Json.putRecord] data has been encoded")

        let semaphore = DispatchSemaphore(value: 0)
        getRecordQ.maxConcurrentOperationCount = 4
        getRecordQ.addOperation {

            jsonRequest.httpMethod = "PUT"
            jsonRequest.httpBody   = JSONSerializedPrestage
            let destConf = URLSessionConfiguration.default
            destConf.httpAdditionalHeaders = ["Authorization" : "Bearer \(token)", "Content-Type" : "application/json", "Accept" : "application/json"]
            let destSession = Foundation.URLSession(configuration: destConf, delegate: self, delegateQueue: OperationQueue.main)
            let task = destSession.dataTask(with: jsonRequest as URLRequest, completionHandler: {
                (data, response, error) -> Void in
                if let httpResponse = response as? HTTPURLResponse {
//                    print("[Json.getRecord] httpResponse: \(String(describing: httpResponse))")
                    if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                        do {
                            let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                            if let endpointJSON = json as? [String:AnyObject] {
//                                if LogLevel.debug { WriteToLog().message(stringOfText: "[Json.getRecord] \(endpointJSON)\n") }
                                completion(["\(httpResponse.statusCode)":endpointJSON])
                            } else {
//                                WriteToLog().message(stringOfText: "[Json.getRecord] error parsing JSON for \(existingDestUrl)\n")
                                completion(["\(httpResponse.statusCode)":[:]])
                            }
                        }
                    } else {
                        print("[Json.putRecord] error HTTP Status Code: \(httpResponse.statusCode)\n")
                        if "\(httpResponse.statusCode)" == "401" {
                            Alert().display(header: "Alert", message: "Verify username and password.")
                        }
//                        WriteToLog().message(stringOfText: "[Json.getRecord] error HTTP Status Code: \(httpResponse.statusCode)\n")
                        completion([:])
                    }
                } else {
//                    WriteToLog().message(stringOfText: "[Json.getRecord] error parsing JSON for \(existingDestUrl)\n")
                    completion([:])
                }   // if let httpResponse - end
                semaphore.signal()
                if error != nil {
                }
            })  // let task = destSession - end
            //print("GET")
            task.resume()
        }   // getRecordQ - end
    }
    
    func getToken(serverUrl: String, base64creds: String, completion: @escaping (_ returnedToken: String) -> Void) {
        
        URLCache.shared.removeAllCachedResponses()
        
        var token          = ""

        var tokenUrlString = "\(serverUrl)/api/auth/tokens"
        tokenUrlString     = tokenUrlString.replacingOccurrences(of: "//api", with: "/api")
//        var tokenUrlString = "\(serverUrl)/uapi/auth/tokens"
//        tokenUrlString     = tokenUrlString.replacingOccurrences(of: "//uapi", with: "/uapi")
//        print("\(tokenUrlString)")

        
        let tokenUrl       = URL(string: "\(tokenUrlString)")
        let configuration  = URLSessionConfiguration.default
        var request        = URLRequest(url: tokenUrl!)
        request.httpMethod = "POST"
        
        configuration.httpAdditionalHeaders = ["Authorization" : "Basic \(base64creds)", "Content-Type" : "application/json", "Accept" : "application/json"]
        let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
        let task = session.dataTask(with: request as URLRequest, completionHandler: {
            (data, response, error) -> Void in
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                    let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                    if let endpointJSON = json! as? Dictionary<String, Any>, let _ = endpointJSON["token"] {
                        token = endpointJSON["token"] as! String
                        completion(token)
                        return
                    } else {    // if let endpointJSON error
                        print("JSON error")
                        completion("")
                        return
                    }
                } else {    // if httpResponse.statusCode <200 or >299
                    print("response error: \(httpResponse.statusCode)")

                    if "\(httpResponse.statusCode)" == "401" {
                        Alert().display(header: "Alert", message: "Failed to authenticate.  Verify username and password.")
                    }
                    completion("")
                    return
                }
            } else {
                print("token response error.  Verify url and port.")
                Alert().display(header: "Alert", message: "No response from the server.  Verify URL and port.")
                completion("")
                return
            }
        })
        task.resume()
        
    }   // func token - end
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(  URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
}

