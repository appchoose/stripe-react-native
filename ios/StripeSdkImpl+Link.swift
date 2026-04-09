//
//  StripeSdkImpl+Link.swift
//  stripe-react-native
//

import Foundation
import Stripe

extension StripeSdkImpl {

    // MARK: - REST helpers

    private func linkPost(
        endpoint: String,
        bodyParts: [(String, String)],
        apiKey: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let url = URL(string: "https://api.stripe.com/v1/\(endpoint)") else {
            completion(.failure(NSError(domain: "LinkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = bodyParts.map { key, value in
            "\(linkFormEncode(key))=\(linkFormEncode(value))"
        }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(NSError(domain: "LinkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])))
                return
            }
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                let errorObj = json["error"] as? [String: Any]
                let msg = errorObj?["message"] as? String ?? "HTTP \(httpResponse.statusCode)"
                completion(.failure(NSError(domain: "LinkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])))
                return
            }
            completion(.success(json))
        }.resume()
    }

    private func linkFormEncode(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    private func linkApiKey(consumerAccountPublishableKey: String?) -> String {
        return consumerAccountPublishableKey ?? STPAPIClient.shared.publishableKey ?? ""
    }

    // MARK: - Lookup

    @objc(lookupLinkConsumer:resolver:rejecter:)
    public func lookupLinkConsumer(
        email: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        let apiKey = STPAPIClient.shared.publishableKey ?? ""
        let bodyParts: [(String, String)] = [
            ("email_address", email.lowercased()),
            ("request_surface", "ios_payment_element"),
            ("session_id", UUID().uuidString),
        ]

        linkPost(endpoint: "consumers/sessions/lookup", bodyParts: bodyParts, apiKey: apiKey) { result in
            switch result {
            case .success(let json):
                let exists = json["exists"] as? Bool ?? false
                if exists {
                    guard let session = json["consumerSession"] as? [String: Any] else {
                        resolve(["exists": false])
                        return
                    }
                    var response: [String: Any] = [
                        "exists": true,
                        "consumerSessionClientSecret": session["clientSecret"] as? String ?? "",
                        "redactedPhoneNumber": session["redactedFormattedPhoneNumber"] as? String ?? "",
                    ]
                    if let consumerKey = json["publishableKey"] as? String, !consumerKey.isEmpty {
                        response["consumerAccountPublishableKey"] = consumerKey
                    }
                    resolve(response)
                } else {
                    resolve(["exists": false])
                }
            case .failure(let error):
                resolve(Errors.createError(ErrorType.Failed, error))
            }
        }
    }

    // MARK: - Start OTP

    @objc(startLinkOTPVerification:resolver:rejecter:)
    public func startLinkOTPVerification(
        params: NSDictionary,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let consumerSessionClientSecret = params["consumerSessionClientSecret"] as? String else {
            resolve(Errors.createError(ErrorType.Failed, "consumerSessionClientSecret is required"))
            return
        }
        let consumerAccountPublishableKey = params["consumerAccountPublishableKey"] as? String
        let apiKey = linkApiKey(consumerAccountPublishableKey: consumerAccountPublishableKey)

        let locale = Locale.autoupdatingCurrent.identifier.replacingOccurrences(of: "_", with: "-")
        let bodyParts: [(String, String)] = [
            ("credentials[consumer_session_client_secret]", consumerSessionClientSecret),
            ("type", "SMS"),
            ("locale", locale),
        ]

        linkPost(endpoint: "consumers/sessions/start_verification", bodyParts: bodyParts, apiKey: apiKey) { result in
            switch result {
            case .success:
                resolve([:])
            case .failure(let error):
                resolve(Errors.createError(ErrorType.Failed, error))
            }
        }
    }

    // MARK: - Confirm OTP

    @objc(confirmLinkOTPVerification:resolver:rejecter:)
    public func confirmLinkOTPVerification(
        params: NSDictionary,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let consumerSessionClientSecret = params["consumerSessionClientSecret"] as? String,
              let code = params["code"] as? String else {
            resolve(Errors.createError(ErrorType.Failed, "consumerSessionClientSecret and code are required"))
            return
        }
        let consumerAccountPublishableKey = params["consumerAccountPublishableKey"] as? String
        let apiKey = linkApiKey(consumerAccountPublishableKey: consumerAccountPublishableKey)

        let bodyParts: [(String, String)] = [
            ("credentials[consumer_session_client_secret]", consumerSessionClientSecret),
            ("type", "SMS"),
            ("code", code),
            ("request_surface", "ios_payment_element"),
        ]

        linkPost(endpoint: "consumers/sessions/confirm_verification", bodyParts: bodyParts, apiKey: apiKey) { result in
            switch result {
            case .success(let json):
                let session = json["consumerSession"] as? [String: Any]
                let newSecret = session?["clientSecret"] as? String ?? consumerSessionClientSecret
                resolve(["consumerSessionClientSecret": newSecret])
            case .failure(let error):
                resolve(Errors.createError(ErrorType.Failed, error))
            }
        }
    }

    // MARK: - List payment methods

    @objc(listLinkPaymentMethods:resolver:rejecter:)
    public func listLinkPaymentMethods(
        params: NSDictionary,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let consumerSessionClientSecret = params["consumerSessionClientSecret"] as? String else {
            resolve(Errors.createError(ErrorType.Failed, "consumerSessionClientSecret is required"))
            return
        }
        let consumerAccountPublishableKey = params["consumerAccountPublishableKey"] as? String
        let apiKey = linkApiKey(consumerAccountPublishableKey: consumerAccountPublishableKey)

        let bodyParts: [(String, String)] = [
            ("credentials[consumer_session_client_secret]", consumerSessionClientSecret),
            ("request_surface", "ios_payment_element"),
            ("types[]", "CARD"),
            ("types[]", "BANK_ACCOUNT"),
        ]

        linkPost(endpoint: "consumers/payment_details/list", bodyParts: bodyParts, apiKey: apiKey) { result in
            switch result {
            case .success(let json):
                let detailsArray = json["redactedPaymentDetails"] as? [[String: Any]] ?? []
                let methods: [[String: Any]] = detailsArray.compactMap { detail in
                    let id = detail["id"] as? String ?? ""
                    let isDefault = detail["isDefault"] as? Bool ?? false
                    let type = (detail["type"] as? String ?? "").uppercased()

                    switch type {
                    case "CARD":
                        let card = detail["cardDetails"] as? [String: Any]
                        var method: [String: Any] = [
                            "id": id,
                            "type": "Card",
                            "last4": card?["last4"] as? String ?? "",
                            "isDefault": isDefault,
                        ]
                        if let card = card {
                            method["brand"] = card["brand"] as? String ?? ""
                            method["expYear"] = card["expYear"] as? Int ?? 0
                            method["expMonth"] = card["expMonth"] as? Int ?? 0
                        }
                        return method
                    case "BANK_ACCOUNT":
                        let bank = detail["bankAccountDetails"] as? [String: Any]
                        return [
                            "id": id,
                            "type": "BankAccount",
                            "last4": bank?["last4"] as? String ?? "",
                            "isDefault": isDefault,
                            "bankName": bank?["bankName"] as? String ?? "",
                        ]
                    default:
                        return [
                            "id": id,
                            "type": "Unknown",
                            "last4": "",
                            "isDefault": isDefault,
                        ]
                    }
                }
                resolve(["paymentMethods": methods])
            case .failure(let error):
                resolve(Errors.createError(ErrorType.Failed, error))
            }
        }
    }
}
