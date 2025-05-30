import Foundation
import UIKit
import Stripe

@objc(AuBECSDebitFormView)
public class AuBECSDebitFormView: UIView, STPAUBECSDebitFormViewDelegate {

    var auBecsFormView: STPAUBECSDebitFormView?
    @objc public var onCompleteAction: RCTDirectEventBlock?
    @objc public var companyName: NSString?
    
    @objc public func didSetProps() {
        if let auBecsFormView = self.auBecsFormView {
            auBecsFormView.removeFromSuperview()
        }
        

        self.auBecsFormView = STPAUBECSDebitFormView(companyName: (companyName ?? "") as String)
        self.auBecsFormView?.becsDebitFormDelegate = self
       
        
        if let auBecsFormView = self.auBecsFormView {
            self.addSubview(auBecsFormView)
            setStyles()
        }
    }
  
    override public func didSetProps(_ changedProps: [String]!) {
        // This is only called on old arch, for new arch didSetProps() will be called
        // by the view component.
        self.didSetProps();
    }
    
    @objc public var formStyle: NSDictionary = NSDictionary() {
        didSet {
           setStyles()
        }
    }
    
    private func setStyles() {
        auBecsFormView?.formFont = UIFont.systemFont(ofSize: CGFloat(30))

        if let textColor = formStyle["textColor"] as? String {
            auBecsFormView?.formTextColor = UIColor(hexString: textColor)
        }
        if let fontSize = formStyle["fontSize"] as? Int {
            auBecsFormView?.formFont = UIFont.systemFont(ofSize: CGFloat(fontSize))
        }
        if let backgroundColor = formStyle["backgroundColor"] as? String {
            auBecsFormView?.formBackgroundColor = UIColor(hexString: backgroundColor)
        }
        if let placeholderColor = formStyle["placeholderColor"] as? String {
            auBecsFormView?.formPlaceholderColor = UIColor(hexString: placeholderColor)
        }
        if let textErrorColor = formStyle["textErrorColor"] as? String {
            auBecsFormView?.formTextErrorColor = UIColor(hexString: textErrorColor)
        }
        if let borderColor = formStyle["borderColor"] as? String {
            auBecsFormView?.layer.borderColor = UIColor(hexString: borderColor).cgColor
        }
        if let borderRadius = formStyle["borderRadius"] as? CGFloat {
            auBecsFormView?.layer.cornerRadius = borderRadius
        }
        if let borderWidth = formStyle["borderWidth"] as? CGFloat {
            auBecsFormView?.layer.borderWidth = borderWidth
        }
    }
    
    public func auBECSDebitForm(_ form: STPAUBECSDebitFormView, didChangeToStateComplete complete: Bool) {
        onCompleteAction!([
            "accountNumber": form.paymentMethodParams?.auBECSDebit?.accountNumber ?? "",
            "bsbNumber": form.paymentMethodParams?.auBECSDebit?.bsbNumber ?? "",
            "name": form.paymentMethodParams?.billingDetails?.name ?? "",
            "email": form.paymentMethodParams?.billingDetails?.email ?? ""
        ])
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    override public func layoutSubviews() {
        if let auBecsFormView = self.auBecsFormView {
            auBecsFormView.frame = self.bounds
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
