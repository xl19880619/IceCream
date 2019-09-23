//
//  DatabaseManager+ResumeOperations.swift
//  IceCream
//
//  Created by Peter Livesey on 9/23/19.
//  Copyright © 2019 蔡越. All rights reserved.
//

import Foundation
import CloudKit

private var resumedOperationIds = Set<CKOperation.ID>()
private let queue = DispatchQueue(label: "com.icecream.ckcontainer.resumeoperations", qos: .utility)

extension DatabaseManager {
    /// The CloudKit Best Practice is out of date, now use this:
    /// https://developer.apple.com/documentation/cloudkit/ckoperation
    /// Which problem does this func solve? E.g.:
    /// 1.(Offline) You make a local change, involve a operation
    /// 2. App exits or ejected by user
    /// 3. Back to app again
    /// The operation resumes! All works like a magic!
    func resumeLongLivedOperationIfPossible() {
        container.fetchAllLongLivedOperationIDs { [weak self] (opeIDs, error) in
            guard let self = self, error == nil, let ids = opeIDs else { return }
            for id in ids {
                // If you add the same operation to a container, it will crash
                // So, we need to keep track of all the operation ids and make sure we don't repeat them
                queue.async {
                    if resumedOperationIds.contains(id) {
                        return
                    }

                    resumedOperationIds.insert(id)

                    self.container.fetchLongLivedOperation(withID: id) { (ope, error) in
                        guard error == nil else {
                            queue.async {
                                resumedOperationIds.remove(id)
                            }

                            return
                        }

                        if let modifyOp = ope as? CKModifyRecordsOperation {
                            modifyOp.modifyRecordsCompletionBlock = { (_,_,_) in
                                print("Resume modify records success!")
                            }

                            self.database.add(modifyOp)
                        }
                    }
                }
            }
        }
    }
}
