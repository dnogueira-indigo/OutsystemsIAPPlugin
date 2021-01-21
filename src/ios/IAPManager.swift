//
//  IAPManager.swift
//  OutsystemsApplePay
//
//  Created by WorldIT on 18/01/2021.
//

import Foundation
import StoreKit

class IAPManager: NSObject {
    
    enum IAPManagerError: Error {
        case noProductIDsFound
        case noProductsFound
        case paymentWasCancelled
        case productRequestFailed
    }
    
    static let shared = IAPManager()
    
    //callback for get products
    var onReceiveProductsHandler: ((Result<[SKProduct], IAPManagerError>) -> Void)?
    
    //callback for buy products
    var onBuyProductHandler: ((Result<SKPaymentTransaction, Error>) -> Void)?
    
    private override init() {
        super.init()
    }
   
    func startObserving() {
        SKPaymentQueue.default().add(self)
    }
     
     
    func stopObserving() {
        SKPaymentQueue.default().remove(self)
    }
    
    //get products from apple with specified product ids
    //product object from apple is needed to purchase
    func getProducts(productIDs:[String], withHandler productsReceiveHandler: @escaping (_ result: Result<[SKProduct], IAPManagerError>) -> Void) {
        self.onReceiveProductsHandler = productsReceiveHandler

        if productIDs.count <= 0 {
            productsReceiveHandler(.failure(.noProductIDsFound))
            return
        }
       
        let request = SKProductsRequest(productIdentifiers: Set(productIDs))
             
        request.delegate = self
        request.start()
    }
    
    
    //converts price from product to formatted string
    func getPriceFormatted(for product: SKProduct) -> String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        return formatter.string(from: product.price)
    }
    
    
    func buy(product: SKProduct, withHandler handler: @escaping ((_ result: Result<SKPaymentTransaction, Error>) -> Void)) {
        
        let payment = SKPayment(product: product)
        
        onBuyProductHandler = handler
        SKPaymentQueue.default().add(payment)
    }
    
    func canMakePayments() -> Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    
    func restorePurchases(withHandler handler: @escaping ((_ result: Result<SKPaymentTransaction, Error>) -> Void)) {
        onBuyProductHandler = handler
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    func openManagesubscriptions() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
    
}
extension IAPManager.IAPManagerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noProductIDsFound: return "No In-App Purchase product identifiers were found."
        case .noProductsFound: return "No In-App Purchases were found."
        case .productRequestFailed: return "Unable to fetch available In-App Purchase products at the moment."
        case .paymentWasCancelled: return "In-App Purchase process was cancelled."
        }
    }
}

extension IAPManager :SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
     
        if response.products.count > 0 {
            onReceiveProductsHandler?(.success(response.products))
        } else {
            // No products were found.
            onReceiveProductsHandler?(.failure(.noProductsFound))
        }
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        onReceiveProductsHandler?(.failure(.productRequestFailed))
    }

}

extension IAPManager: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
      
        transactions.forEach { (transaction) in
           
            switch transaction.transactionState {
            case .purchased:
                print("b \(transaction.payment.productIdentifier) + \(transaction.transactionDate)")
              
                onBuyProductHandler?(.success(transaction))
                SKPaymentQueue.default().finishTransaction(transaction)
                
            case .restored:
                print("restored \(transaction.original?.payment.productIdentifier)")
                
                onBuyProductHandler?(.success(transaction))
                SKPaymentQueue.default().finishTransaction(transaction)
            
            case .failed:
                if let error = transaction.error as? SKError {
                    if error.code != .paymentCancelled {
                        onBuyProductHandler?(.failure(error))
                    } else {
                        onBuyProductHandler?(.failure(IAPManagerError.paymentWasCancelled))
                    }
                    print("IAP Error:", error.localizedDescription)
                }
                SKPaymentQueue.default().finishTransaction(transaction)
            
            case .deferred, .purchasing:
                break
            @unknown default:
                break
            }
        }

    }
    
}
