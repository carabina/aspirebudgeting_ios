//
//  GoogleDriveManager.swift
//  Aspire Budgeting
//
//  Created by TeraMo Labs on 10/21/19.
//  Copyright © 2019 TeraMo Labs. All rights reserved.
//

import Foundation
import GoogleAPIClientForREST
import GoogleSignIn
import GTMSessionFetcher

enum GoogleDriveManagerError: String, Error {
  case nilAuthorizer = "nilAuthorizer"
  case invalidSheet = "Please select a valid Aspire Sheet"
  case noInternet = "No Internet connection available"
}
  
  final class GoogleDriveManager: ObservableObject {
    static let queryFields: String = "kind,nextPageToken,files(mimeType,id,kind,name)"
    static let spreadsheetMIME: String = "application/vnd.google-apps.spreadsheet"
    
    private let driveService: GTLRService
    private let googleFilesListQuery: GTLRDriveQuery_FilesList
    
    
    private var authorizer: GTMFetcherAuthorizationProtocol?
    private var authorizerNotificationObserver: NSObjectProtocol?
    
    private var ticket: GTLRServiceTicket?
    
    @Published public private(set) var fileList = [File]()
    @Published public private(set) var error: Error?
    
    init(driveService: GTLRService = GTLRDriveService(),
         googleFilesListQuery: GTLRDriveQuery_FilesList = GTLRDriveQuery_FilesList.query()) {
      self.driveService = driveService
      self.googleFilesListQuery = googleFilesListQuery
      
      subscribeToAuthorizerNotification()
      
    }
    
    private func subscribeToAuthorizerNotification() {
      authorizerNotificationObserver = NotificationCenter.default.addObserver(forName: .authorizerUpdated, object: nil, queue: nil) { [weak self] (notification) in
        guard let weakSelf = self else {
            return
        }
        
        weakSelf.assignAuthorizer(from: notification)
      }
    }
    
    private func assignAuthorizer(from notification: Notification) {
      guard let userInfo = notification.userInfo,
        let authorizer = userInfo[Notification.Name.authorizerUpdated] as? GTMFetcherAuthorizationProtocol else {
          return
      }
      
      self.authorizer = authorizer
    }
    
    func clearFileList() {
      fileList.removeAll()
    }
    
    func getFileList() {
      guard let authorizer = self.authorizer else {
        self.error = GoogleDriveManagerError.nilAuthorizer
        return
      }
      
      let backupFileList = fileList
      fileList.removeAll()
      
      driveService.authorizer = authorizer
      driveService.shouldFetchNextPages = true
      
      googleFilesListQuery.fields = GoogleDriveManager.queryFields
      googleFilesListQuery.q = "mimeType='\(GoogleDriveManager.spreadsheetMIME)'"
      ticket = driveService.executeQuery(googleFilesListQuery, completionHandler: { [weak self] (_, driveFileList, error) in
        guard let weakSelf = self else {
          return
        }
        weakSelf.googleFilesListQuery.isQueryInvalid = false
        
        if let error = error {
          weakSelf.error = error
          weakSelf.fileList = backupFileList
        } else {
          if let driveFileList = driveFileList as? GTLRDrive_FileList,
            let files = driveFileList.files {
            weakSelf.fileList = files
              .map({ File(driveFile: $0)})
          }
        }
      })
    }
}
