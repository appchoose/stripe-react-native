//
//  StripeSdkImpl+Link.swift
//  stripe-react-native
//

import Foundation
@_spi(STP) import StripePaymentSheet

extension StripeSdkImpl {

    @objc(lookupLinkConsumer:resolver:rejecter:)
    public func lookupLinkConsumer(
        email: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        ConsumerSession.lookupSession(
            for: email,
            emailSource: .customerObject,
            sessionID: UUID().uuidString,
            with: STPAPIClient.shared,
            cookieStore: LinkSecureCookieStore.shared,
            useMobileEndpoints: false
        ) { result in
            switch result {
            case .success(let lookupResponse):
                switch lookupResponse.responseType {
                case .found(let session):
                    var response: [String: Any] = [
                        "exists": true,
                        "consumerSessionClientSecret": session.consumerSession.clientSecret,
                        "redactedPhoneNumber": session.consumerSession.redactedFormattedPhoneNumber,
                    ]
                    response["consumerAccountPublishableKey"] = session.publishableKey
                    resolve(response)
                case .notFound, .noAvailableLookupParams:
                    resolve(["exists": false])
                }
            case .failure(let error):
                resolve(Errors.createError(ErrorType.Failed, error))
            }
        }
    }

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

        STPAPIClient.shared.startVerification(
            for: consumerSessionClientSecret,
            type: .sms,
            locale: .autoupdatingCurrent,
            cookieStore: LinkSecureCookieStore.shared,
            consumerAccountPublishableKey: consumerAccountPublishableKey
        ) { result in
            switch result {
            case .success:
                resolve([:])
            case .failure(let error):
                resolve(Errors.createError(ErrorType.Failed, error))
            }
        }
    }

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

        STPAPIClient.shared.confirmSMSVerification(
            for: consumerSessionClientSecret,
            with: code,
            cookieStore: LinkSecureCookieStore.shared,
            consumerAccountPublishableKey: consumerAccountPublishableKey
        ) { result in
            switch result {
            case .success(let session):
                resolve(["consumerSessionClientSecret": session.clientSecret])
            case .failure(let error):
                resolve(Errors.createError(ErrorType.Failed, error))
            }
        }
    }

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

        STPAPIClient.shared.listPaymentDetails(
            for: consumerSessionClientSecret,
            supportedPaymentDetailsTypes: [.card, .bankAccount],
            consumerAccountPublishableKey: consumerAccountPublishableKey
        ) { result in
            switch result {
            case .success(let paymentDetails):
                let methods: [[String: Any]] = paymentDetails.compactMap { detail in
                    switch detail.details {
                    case .card(let card):
                        return [
                            "id": detail.stripeID,
                            "type": "Card",
                            "last4": card.last4,
                            "isDefault": detail.isDefault,
                            "brand": card.brand,
                            "expYear": card.expiryYear,
                            "expMonth": card.expiryMonth,
                        ]
                    case .bankAccount(let bank):
                        return [
                            "id": detail.stripeID,
                            "type": "BankAccount",
                            "last4": bank.last4,
                            "isDefault": detail.isDefault,
                            "bankName": bank.name,
                        ]
                    case .unparsable:
                        return [
                            "id": detail.stripeID,
                            "type": "Unknown",
                            "last4": "",
                            "isDefault": detail.isDefault,
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
