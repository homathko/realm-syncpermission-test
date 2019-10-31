//
//  SyncPermissionTest.swift
//  realm-syncpermission-testTests
//
//  Created by Eric Lightfoot on 2019-10-31.
//  Copyright © 2019 HomathkoTech. All rights reserved.
//


import Foundation
import XCTest
import RealmSwift

let ROSHost = "<<your realm host>>" // Exclude 'https://', 'realms://'
let realmName = "synctest"
let userAName: String = "User22"
let userBName: String = "User23"
var userAId: String = ""
var userBId: String = ""

class SyncPermissionTest: XCTestCase {
    var userA: SyncUser!
    var userB: SyncUser!
    var realmA: Realm!
    var realmB: Realm!
    
    override func setUp () {
        super.setUp()
    }
    
    func testEverything () {
        print("Registering new users")
        registerUsers()
        print("Creating new realms")
        createRealms()
        print("Creating new objects")
        addSomeObjects()
        print("Reading some objects")
        readUsersOwnObjects()
        print("Not able to access other user's realm yet")
        connectToOtherUsersRealmShouldntWork()
        print("Now try exchanging mutual permission")
        exchangePermissionToReadEachOthersRealms()
        print("Now try accessing each other's realm again")
        connectToOtherUsersRealmShouldNowWork()
        print("Reading other user's realm")
        readOtherUsersObjects()
    }
    
    func registerUsers () {
        let exp_userACreated = XCTestExpectation(description: "\(userAName) registered")
        let exp_userBCreated = XCTestExpectation(description: "\(userBName) registered")
        
        let authURL = URL(string: "https://\(ROSHost)")!
        let userAcreds = SyncCredentials.usernamePassword(username: userAName, password: userAName, register: true)
        let userBcreds = SyncCredentials.usernamePassword(username: userBName, password: userBName, register: true)
        
        SyncUser.logIn(with: userAcreds, server: authURL) { user, err in
            XCTAssert(err == nil)
            XCTAssert(user != nil)
            self.userA = user!
            userAId = user!.identity!
            print("Created \(userAName)")
            exp_userACreated.fulfill()
        }
        
        SyncUser.logIn(with: userBcreds, server: authURL) { user, err in
            XCTAssert(err == nil)
            XCTAssert(user != nil)
            self.userB = user!
            userBId = user!.identity!
            print("Created \(userBName)")
            exp_userBCreated.fulfill()
        }
        
        wait(for: [exp_userACreated, exp_userBCreated], timeout: 60)
    }
    
    func createRealms () {
        let exp_realmForUserACreated = XCTestExpectation(description: "User A realm created")
        let exp_realmForUserBCreated = XCTestExpectation(description: "User B realm created")
        
        let realmURL = URL(string: "realms://\(ROSHost)/~/\(realmName)")!
        
        var userAConfig = self.userA.configuration(realmURL: realmURL, fullSynchronization: true)
        userAConfig.objectTypes = [Thing.self]
        Realm.asyncOpen(configuration: userAConfig) { realm, err in
            XCTAssert(err == nil)
            print("\(userAName).realm created")
            self.realmA = realm
            exp_realmForUserACreated.fulfill()
        }
        
        var userBConfig = self.userB.configuration(realmURL: realmURL, fullSynchronization: true)
        userBConfig.objectTypes = [Thing.self]
        Realm.asyncOpen(configuration: userBConfig) { realm, err in
            XCTAssert(err == nil)
            print("\(userBName).realm created")
            self.realmB = realm
            exp_realmForUserBCreated.fulfill()
        }
        
        wait(for: [exp_realmForUserACreated, exp_realmForUserBCreated], timeout: 60)
    }
    
    func addSomeObjects () {
        let names = ["Dude", "Man", "Bra", "Dingus", "Mangnolia", "Broseph"]
        
        func createRandomObjectsInRealm(realm: Realm, howMany: Int) {
            realm.beginWrite()
            for _ in 1...howMany {
                let thing = Thing(value: [
                    "name": names[Int.random(in: 0..<names.count)],
                    "age": Int.random(in: 0...1000)
                    ])
                realm.add(thing)
            }
            do {
                try realm.commitWrite()
            } catch (let err) {
                print(err.localizedDescription)
                XCTAssert(false)
            }
        }
        
        createRandomObjectsInRealm(realm: self.realmA, howMany: 10)
        print("Created some objects in \(userAName)'s realm")
        createRandomObjectsInRealm(realm: self.realmB, howMany: 10)
        print("Created some objects in \(userBName)'s realm")
    }
    
    func readUsersOwnObjects () {
        let exp_canReadObjectsFromUserAsRealm = XCTestExpectation(description: "\(userAName)'s realm contains objects")
        let exp_canReadObjectsFromUserBsRealm = XCTestExpectation(description: "\(userBName)'s realm contains objects")
        
        func readObjectsFromRealm (realm: Realm, expectation: XCTestExpectation) {
            let _ = realm.objects(Thing.self).observe { π in
                switch π {
                case .initial(let results), .update(let results, _, _, _):
                    print(Array(results))
                    if results.count == 10 {
                        expectation.fulfill()
                    }
                case .error(let err):
                    print(err.localizedDescription)
                    XCTAssert(false)
                }
            }
        }
        
        readObjectsFromRealm(realm: self.realmA, expectation: exp_canReadObjectsFromUserAsRealm)
        print("\(userAName) reads objects from \(userAName)'s realm")
        readObjectsFromRealm(realm: self.realmB, expectation: exp_canReadObjectsFromUserBsRealm)
        print("\(userBName) reads objects from \(userBName)'s realm")
        wait(for: [exp_canReadObjectsFromUserAsRealm, exp_canReadObjectsFromUserBsRealm], timeout: 60)
    }
    
    func connectToOtherUsersRealmShouldntWork () {
        let exp_UserAcannotConnectToUserBsRealm = XCTestExpectation(description: "\(userAName) can't connect to \(userBName)'s realm")
        let exp_UserBcannotConnectToUserAsRealm = XCTestExpectation(description: "\(userBName) can't connect to \(userAName)'s realm")
        
        // Connect UserA to UserB
        let userBRealmURL = URL(string: "realms://\(ROSHost)/\(userBId)/\(realmName)")!
        
        var userAConfig = self.userA.configuration(realmURL: userBRealmURL, fullSynchronization: true)
        userAConfig.objectTypes = [Thing.self]
        Realm.asyncOpen(configuration: userAConfig) { realm, err in
            print(err?.localizedDescription ?? "none")
            XCTAssert(err != nil)
            exp_UserAcannotConnectToUserBsRealm.fulfill()
        }
        
        // Connect UserB to UserA
        let userARealmURL = URL(string: "realms://\(ROSHost)/\(userAId)/\(realmName)")!
        
        var userBConfig = self.userB.configuration(realmURL: userARealmURL, fullSynchronization: true)
        userBConfig.objectTypes = [Thing.self]
        Realm.asyncOpen(configuration: userBConfig) { realm, err in
            print(err?.localizedDescription ?? "none")
            XCTAssert(err != nil)
            exp_UserBcannotConnectToUserAsRealm.fulfill()
        }
        
        wait(for: [exp_UserAcannotConnectToUserBsRealm, exp_UserBcannotConnectToUserAsRealm], timeout: 60)
    }
    
    func exchangePermissionToReadEachOthersRealms () {
        let exp_UserAGivesReadPermissionToUserB = XCTestExpectation(description: "\(userAName) gives read permission to \(userBName)'s realm")
        let exp_UserBGivesReadPermissionToUserA = XCTestExpectation(description: "\(userBName) gives read permission to \(userAName)'s realm")
        
        let userARealmURLStringToGivePermissionTo = "/\(userAId)/\(realmName)"
        let permissionToA = SyncPermission(realmPath: userARealmURLStringToGivePermissionTo, identity: userBId, accessLevel: .admin)
        userA.apply(permissionToA) { err in
            print(err?.localizedDescription ?? "no error")
            XCTAssert(err == nil, "userA.apply() -> Callback received with no error")
            exp_UserAGivesReadPermissionToUserB.fulfill()
        }
        
        let userBRealmURLStringToGivePermissionTo = "/\(userBId)/\(realmName)"
        let permissionToB = SyncPermission(realmPath: userBRealmURLStringToGivePermissionTo, identity: userAId, accessLevel: .admin)
        userB.apply(permissionToB) { err in
            print(err?.localizedDescription ?? "no error")
            XCTAssert(err == nil, "userB.apply() -> Callback received with no error")
            exp_UserBGivesReadPermissionToUserA.fulfill()
        }
        
        wait(for: [exp_UserAGivesReadPermissionToUserB,exp_UserBGivesReadPermissionToUserA], timeout: 60)
    }
    
    func connectToOtherUsersRealmShouldNowWork () {
        let exp_UserAcanConnectToUserBsRealm = XCTestExpectation(description: "\(userAName) can now connect to \(userBName)'s realm")
        let exp_UserBcanConnectToUserAsRealm = XCTestExpectation(description: "\(userBName) can now connect to \(userAName)'s realm")
        
        // Connect UserA to UserB
        let userBRealmURL = URL(string: "realms://\(ROSHost)/\(userBId)/\(realmName)")!
        
        var userAConfig = self.userA.configuration(realmURL: userBRealmURL, fullSynchronization: true)
        userAConfig.objectTypes = [Thing.self]
        Realm.asyncOpen(configuration: userAConfig) { realm, err in
            print(err?.localizedDescription ?? "no error")
            XCTAssert(err == nil)
            exp_UserAcanConnectToUserBsRealm.fulfill()
        }
        
        // Connect UserB to UserA
        let userARealmURL = URL(string: "realms://\(ROSHost)/\(userAId)/\(realmName)")!
        
        var userBConfig = self.userB.configuration(realmURL: userARealmURL, fullSynchronization: true)
        userBConfig.objectTypes = [Thing.self]
        Realm.asyncOpen(configuration: userBConfig) { realm, err in
            print(err?.localizedDescription ?? "no error")
            XCTAssert(err == nil)
            exp_UserBcanConnectToUserAsRealm.fulfill()
        }
        
        wait(for: [exp_UserAcanConnectToUserBsRealm, exp_UserBcanConnectToUserAsRealm], timeout: 60)
    }
    
    func readOtherUsersObjects () {
        let exp_userAcanReadObjectsFromUserBsRealm = XCTestExpectation(description: "\(userAName) can see that \(userBName)'s realm contains objects")
        let exp_userBcanReadObjectsFromUserAsRealm = XCTestExpectation(description: "\(userBName) can see that \(userAName)'s realm contains objects")
        
        func objectsRead (byUser: SyncUser, ofUser: SyncUser, expectation: XCTestExpectation) {
            // Connect UserA to UserB
            let ofUserRealmURL = URL(string: "realms://\(ROSHost)/\(ofUser.identity!)/\(realmName)")!
            var byUserConfig = byUser.configuration(realmURL: ofUserRealmURL, fullSynchronization: true)
            byUserConfig.objectTypes = [Thing.self]
            Realm.asyncOpen(configuration: byUserConfig, callbackQueue: DispatchQueue.main) { realm, err in
                print(err?.localizedDescription ?? "no error")
                XCTAssert(err == nil)
                let _ = realm!.objects(Thing.self).observe { π in
                    switch π {
                    case .initial(let results), .update(let results, _, _, _):
                        print(Array(results))
                        if results.count == 10 {
                            expectation.fulfill()
                        }
                    case .error(let err):
                        print(err.localizedDescription)
                        XCTAssert(false)
                    }
                }
            }
        }
        
        objectsRead(byUser: userA, ofUser: userB, expectation: exp_userAcanReadObjectsFromUserBsRealm)
        print("\(userAName) reads objects from \(userBName)'s realm")
        objectsRead(byUser: userB, ofUser: userA, expectation: exp_userBcanReadObjectsFromUserAsRealm)
        print("\(userBName) reads objects from \(userAName)'s realm")
        wait(for: [exp_userAcanReadObjectsFromUserBsRealm, exp_userBcanReadObjectsFromUserAsRealm], timeout: 60)
    }
}

class Thing: Object {
    @objc dynamic var name: String = ""
    @objc dynamic var age: Int = 0
}

