//
//  MySQL.swift
//  MySQLSwift
//
//  Created by Alsey Coleman Miller on 10/10/15.
//  Copyright © 2015 ColemanCDA. All rights reserved.
//

import mysqlclient

public final class MySQL {
    
    // MARK: - Class Methods
    
    public static var clientInfo: String {
        
        guard let version = String.fromCString(mysql_get_client_info())
            else { fatalError("Could not get MySQL client version") }
        
        return version
    }
    
    public static var clientVersion: UInt {
        
        return mysql_get_client_version()
    }
    
    // MARK: - Properties
    
    /// Human readable error string for the last error produced (if any).
    public var errorString: String? {
        
        return String.fromCString(mysql_error(internalPointer))
    }
    
    public var hostInfo: String? {
        
        return String.fromCString(mysql_get_host_info(internalPointer))
    }
    
    // MARK: - Private Properties
    
    private let internalPointer = UnsafeMutablePointer<MYSQL>()
    
    // MARK: - Initialization
    
    deinit {
        
        mysql_close(internalPointer)
    }
    
    public init() {
        
        guard mysql_init(internalPointer) != nil else { fatalError("Could not initialize MySQL") }
    }
    
    // MARK: - Methods
    
    /// Attempts to establish a connection to a MySQL database engine.
    public func connect(host: String, user: String, password: String, database: String? = nil, port: UInt32 = 0, options: [ClientOption] = []) throws {
        
        let clientFlags: UInt = 0
        
        if let database = database {
            
            guard mysql_real_connect(internalPointer, host, user, password, database, port, nil, clientFlags) != nil
                else { throw ClientError(rawValue: mysql_errno(internalPointer))! }
        }
        else {
            
            guard mysql_real_connect(internalPointer, host, user, password, nil, port, nil, clientFlags) != nil
                else { throw ClientError(rawValue: mysql_errno(internalPointer))! }
        }
    }
    
    // MARK: Database Operations
    
    public func selectDatabase(database: String) throws {
        
        guard mysql_select_db(internalPointer, database) == 0
            else { throw ClientError(rawValue: mysql_errno(internalPointer))! }
    }
    
    public func createDatabase(database: String) throws {
        
        guard mysql_create_db(internalPointer, database) == 0
            else { throw ClientError(rawValue: mysql_errno(internalPointer))! }
    }
    
    public func deleteDatabase(database: String) throws {
        
        guard mysql_drop_db(internalPointer, database) == 0
            else { throw ClientError(rawValue: mysql_errno(internalPointer))! }
    }
    
    // MARK: Query
    
    public func executeQuery(query: String) throws -> [[(Field, Data)]]? {
        
        guard mysql_exec_sql(internalPointer, query) == 0
            else { throw ClientError(rawValue: mysql_errno(internalPointer))! }
        
        // get result... 
        
        let mysqlResult = mysql_store_result(internalPointer)
        
        guard mysqlResult != nil else {
            
            // make sure it was really an empty result
            // http://dev.mysql.com/doc/refman/5.0/en/null-mysql-store-result.html
            
            guard mysql_field_count(internalPointer) == 0
                else { throw MySQL.Error.BadResult }
            
            return nil
        }
        
        defer { mysql_free_result(mysqlResult) }
        
        var rowResults = [[(Field, Data)]]()
        
        var row: MYSQL_ROW
        
        repeat {
            
            row = mysql_fetch_row(mysqlResult)
            
            let numberOfFields = mysql_num_fields(mysqlResult)
            
            let fieldLengths = mysql_fetch_lengths(mysqlResult)
            
            let lastFieldIndex = Int(numberOfFields - 1)
            
            var fields = [Data]()
            
            for i in 0...lastFieldIndex {
                
                let fieldValuePointer = row[i]
                
                let fieldLength = fieldLengths[i]
                
                let field = x(mysqlResult, UInt32(i))
                
                let data = DataFromBytePointer(fieldValuePointer, length: Int(fieldLength))
                
                fields.append(data)
            }
            
            rowResults.append(fields)
            
        } while row != nil
        
        guard mysql_eof(mysqlResult) != 0
            else { throw Error.NotEndOfFile }
        
        return rowResults
    }
}

// MARK: - Definitions

public typealias Data = [UInt8]

@asmname("mysql_create_db") func mysql_create_db(mysql: UnsafeMutablePointer<MYSQL>, _ database: UnsafePointer<CChar>) -> Int32

@asmname("mysql_drop_db") func mysql_drop_db(mysql: UnsafeMutablePointer<MYSQL>, _ database: UnsafePointer<CChar>) -> Int32

@asmname("mysql_exec_sql") func mysql_exec_sql(mysql: UnsafeMutablePointer<MYSQL>, _ SQL: UnsafePointer<CChar>) -> Int32
