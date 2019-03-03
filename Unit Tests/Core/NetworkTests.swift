//
//  NetworkTests.swift
//  PeakNetwork
//
//  Created by Sam Oakley on 10/10/2016.
//  Copyright © 2016 3Squared. All rights reserved.
//

import XCTest
import PeakResult
import PeakOperation

#if os(iOS)

@testable import PeakNetwork_iOS

#else

@testable import PeakNetwork_macOS

#endif

class NetworkTests: XCTestCase {
    
    let webService = WebService()
    
    func testResponseValidation() {
        let success = HTTPURLResponse(url: URL(string:"google.com")!, statusCode: 200, httpVersion: "1.1", headerFields: nil)
        XCTAssertTrue(success!.statusCodeEnum.isSuccess)
        
        let serverFail = HTTPURLResponse(url: URL(string:"google.com")!, statusCode: 500, httpVersion: "1.1", headerFields: nil)
        XCTAssertTrue(serverFail!.statusCodeEnum.isServerError)

        
        let notFound = HTTPURLResponse(url: URL(string:"google.com")!, statusCode: 404, httpVersion: "1.1", headerFields: nil)
        XCTAssertTrue(notFound!.statusCodeEnum.isClientError)
        
        let authentication = HTTPURLResponse(url: URL(string:"google.com")!, statusCode: 401, httpVersion: "1.1", headerFields: nil)
        XCTAssertTrue(authentication!.statusCodeEnum.isClientError)
        XCTAssertTrue(authentication!.statusCodeEnum == .unauthorized)
    }
    
    
    func testNetworkOperationFailure() {
        let session = MockSession { session in
            session.queue(response: MockResponse(statusCode: .internalServerError))
        }

        let expect = expectation(description: "")
        
        let networkOperation = NetworkOperation(resource: webService.simple(), session: session)
        
        networkOperation.addResultBlock { result in
            switch result {
            case .failure(ServerError.error(code: .internalServerError, data: _, response: _)):
                expect.fulfill()
            default:
                XCTFail()
            }
        }
        
        networkOperation.enqueue()
        
        waitForExpectations(timeout: 1)
    }
    
    func testNetworkOperationFailureWithResponseBody() {
        let session = MockSession { session in
            session.queue(response: MockResponse(json: ["hello": "world"], statusCode: .internalServerError))
        }
        
        let expect = expectation(description: "")
        
        let networkOperation = NetworkOperation(resource: webService.simple(), session: session)

        networkOperation.addResultBlock { result in
            switch result {
            case .failure(ServerError.error(code: .internalServerError, data: let data, response: _)):
                let responseString = String(data: data!, encoding: .utf8)
                XCTAssertEqual("{\"hello\":\"world\"}", responseString)
                expect.fulfill()
            default:
                XCTFail()
            }
        }
        
        networkOperation.enqueue()
        
        waitForExpectations(timeout: 1)
    }

    
    func testNetworkOperationSuccess() {
        let session = MockSession { session in
            session.queue(response: MockResponse(statusCode: .ok))
        }

        let expect = expectation(description: "")

        let networkOperation = NetworkOperation(resource: webService.simple(), session: session)

        networkOperation.addResultBlock { result in
            do {
                let response = try result.resolve()
                XCTAssertEqual(response.urlResponse.statusCode, 200)
                expect.fulfill()
            } catch {
                XCTFail()
            }
        }
        
        networkOperation.enqueue()
        
        waitForExpectations(timeout: 1)
    }
    
    func testNetworkOperationInputSuccess() {
        let session = MockSession { session in
            session.queue(response: MockResponse(json: ["name" : "Sam"], statusCode: .ok))
        }
        
        let expect = expectation(description: "")
        
        let networkOperation = NetworkOperation<TestEntity>(session: session)

        networkOperation.input = Result { webService.simple() }
        
        networkOperation.addResultBlock { result in
            do {
                let entity = try result.resolve()
                XCTAssertEqual(entity.parsed!.name, "Sam")
                expect.fulfill()
            } catch {
                XCTFail()
            }
        }
        
        networkOperation.enqueue()
        
        waitForExpectations(timeout: 1)
    }
    
    func testNetworkOperationWithNoInputFailure() {
        let session = MockSession { _ in }
        
        let expect = expectation(description: "")
        
        let networkOperation = NetworkOperation<TestEntity>(session: session)

        networkOperation.addResultBlock { result in
            do {
                let _ = try result.resolve()
                XCTFail()
            } catch {
                switch error {
                case ResultError.noResult:
                    expect.fulfill()
                default:
                    XCTFail()
                }
            }
        }
        
        networkOperation.enqueue()
        waitForExpectations(timeout: 1)
    }
    
    func testNetworkOperationFailureWithRetry() {
        let session = MockSession { session in
            session.queue(response: MockResponse(statusCode: .internalServerError, sticky: true))
        }
        
        let expect = expectation(description: "")
        
        let networkOperation = NetworkOperation(resource: webService.simple(), session: session)

        var runCount = 0
        networkOperation.retryStrategy = { failureCount in
            runCount += 1
            return failureCount < 3
        }
        
        networkOperation.addResultBlock { result in
            XCTAssertEqual(runCount, 3)
            expect.fulfill()
        }
        
        networkOperation.enqueue()
        
        waitForExpectations(timeout: 100)
    }
    
    public enum TestError: Error {
        case justATest
    }
}
