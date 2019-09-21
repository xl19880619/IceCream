//
//  PublicDatabaseManager.swift
//  IceCream
//
//  Created by caiyue on 2019/4/22.
//

#if os(macOS)
import Cocoa
#else
import UIKit
#endif

import CloudKit

final class PublicDatabaseManager: DatabaseManager {
    
    let container: CKContainer
    let database: CKDatabase
    
    let syncObjects: [Syncable]
    
    init(objects: [Syncable], container: CKContainer) {
        self.syncObjects = objects
        self.container = container
        self.database = container.publicCloudDatabase
    }
    
    func fetchChangesInDatabase(_ callback: ((Error?) -> Void)?) {
        syncObjects.forEach { syncObject in
            let predicate = NSPredicate(value: true)
            syncObject.recordTypes.forEach { recordType in
                let query = CKQuery(recordType: recordType, predicate: predicate)
                let queryOperation = CKQueryOperation(query: query)

                if callback != nil {
                    queryOperation.qualityOfService = .userInitiated
                    queryOperation.timeoutIntervalForRequest = 60
                }

                self.excuteQueryOperation(queryOperation: queryOperation, on: syncObject, callback: callback)
            }
        }
    }
    
    func createCustomZonesIfAllowed() {
        
    }
    
    func createDatabaseSubscriptionIfHaveNot() {
        syncObjects.forEach { createSubscriptionInPublicDatabase(on: $0) }
    }
    
    func startObservingTermination() {
        #if os(iOS) || os(tvOS)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.cleanUp), name: UIApplication.willTerminateNotification, object: nil)
        
        #elseif os(macOS)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.cleanUp), name: NSApplication.willTerminateNotification, object: nil)
        
        #endif
    }
    
    func registerLocalDatabase() {
        syncObjects.forEach { object in
            DispatchQueue.main.async {
                object.registerLocalDatabase()
            }
        }
    }
    
    // MARK: - Private Methods
    private func excuteQueryOperation(queryOperation: CKQueryOperation,on syncObject: Syncable, callback: ((Error?) -> Void)? = nil) {
        queryOperation.recordFetchedBlock = { record in
            syncObject.add(record: record)
        }
        
        queryOperation.queryCompletionBlock = { [weak self] cursor, error in
            guard let self = self else { return }
            if let cursor = cursor {
                let subsequentQueryOperation = CKQueryOperation(cursor: cursor)
                self.excuteQueryOperation(queryOperation: subsequentQueryOperation, on: syncObject, callback: callback)
                return
            }
            switch ErrorHandler.shared.resultType(with: error) {
            case .success:
                DispatchQueue.main.async {
                    callback?(nil)
                }
            case .retry(let timeToWait, _, _):
                ErrorHandler.shared.retryOperationIfPossible(retryAfter: timeToWait, block: {
                    self.excuteQueryOperation(queryOperation: queryOperation, on: syncObject, callback: callback)
                })
            default:
                break
            }
        }
        
        database.add(queryOperation)
    }
    
    private func createSubscriptionInPublicDatabase(on syncObject: Syncable) {
        #if os(iOS) || os(tvOS) || os(macOS)
        for recordType in syncObject.recordTypes {
            let predict = NSPredicate(value: true)
            let subscription = CKQuerySubscription(recordType: recordType, predicate: predict, subscriptionID: IceCreamSubscription.cloudKitPublicDatabaseSubscriptionID.id, options: [CKQuerySubscription.Options.firesOnRecordCreation, CKQuerySubscription.Options.firesOnRecordUpdate, CKQuerySubscription.Options.firesOnRecordDeletion])

            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true // Silent Push

            subscription.notificationInfo = notificationInfo

            let createOp = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
            createOp.modifySubscriptionsCompletionBlock = { _, _, _ in

            }
            createOp.qualityOfService = .utility
            database.add(createOp)
        }
        #endif
    }
    
    @objc func cleanUp() {
        for syncObject in syncObjects {
            syncObject.cleanUp()
        }
    }
}
