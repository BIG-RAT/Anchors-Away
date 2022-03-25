//
//  ViewController.swift
//  Anchors Away
//
//  Created by Leslie Helou on 9/24/20.
//  Copyright © 2020 Leslie Helou. All rights reserved.
//

import Cocoa
import CommonCrypto

class ViewController: NSViewController {

    @IBOutlet weak var serverUrl_TextField: NSTextField!
    @IBOutlet weak var username_TextField: NSTextField!
    @IBOutlet weak var password_TextField: NSSecureTextField!

//    @IBOutlet weak var existingAnchors_Button: NSPopUpButton!
    @IBOutlet weak var platforms_Button: NSPopUpButton!

    @IBOutlet weak var prestages_TableView: NSTableView!
    var withAnchorArray: [[String]]?

    var modifiedComputerPrestages = [String:[String: Any]]()
    var modifiedMobilePrestages   = [String:[String: Any]]()

    @IBOutlet weak var fetch_Button: NSButton!

    var serverUrl    = ""
    var username     = ""
    var password     = ""
    var jamfCreds    = ""
    var jamfCredsB64 = ""
    var token        = ""
    var platforms    = "All"

    let defaults        = UserDefaults.standard
    let fm              = FileManager()
    var isDir: ObjCBool = true

    @IBOutlet weak var spinner_ProgressIndicator: NSProgressIndicator!
    var progressQ     = DispatchQueue(label: "com.jamf.aa.progressq", qos: DispatchQoS.background)

    @IBAction func anchorsToRemove(_ sender: Any) {
//        WriteToLog().message(stringOfText: "\(platforms_Button.titleOfSelectedItem!)")
        platforms = platforms_Button.titleOfSelectedItem!
        fetchPrestages()
    }

    @IBAction func fetch_Action(_ sender: Any) {
        if serverUrl_TextField.stringValue == "" || username_TextField.stringValue == "" || password_TextField.stringValue == "" {
            Alert().display(header: "Alert:", message: "Must supply Server, username, and password")
        } else {
            fetchPrestages()
        }
    }
    
    @IBAction func remove_Action(_ sender: Any) {
        if serverUrl_TextField.stringValue == "" || username_TextField.stringValue == "" || password_TextField.stringValue == "" {
            Alert().display(header: "Alert:", message: "Must supply Server, username, and password")
        } else {
            removeAnchors()
        }
    }

    @IBAction func showFingerprinig_Button(_ sender: Any) {
        WriteToLog().message(stringOfText: "\(String(describing: platforms_Button.titleOfSelectedItem))")
    }


    func fetchPrestages() {
        History.didRun = true
        serverUrl = serverUrl_TextField.stringValue
        jamfCreds           = "\(username_TextField.stringValue):\(password_TextField.stringValue)"
        let jamfUtf8Creds   = jamfCreds.data(using: String.Encoding.utf8)
        jamfCredsB64        = (jamfUtf8Creds?.base64EncodedString())!

        spinner(action: "start")
        self.withAnchorArray?.removeAll()
        self.modifiedComputerPrestages.removeAll()
        self.modifiedMobilePrestages.removeAll()
        DispatchQueue.main.async {
            self.prestages_TableView.reloadData()
        }
        // get token for authentication
        Json().getToken(serverUrl: serverUrl, base64creds: jamfCredsB64) {
            (result: String) in
//            WriteToLog().message(stringOfText: "token: \(result)")
            if result != "" {
                self.token = result

                self.defaults.set("\(self.serverUrl_TextField.stringValue)", forKey: "serverUrl")
                self.defaults.set("\(self.username_TextField.stringValue)", forKey: "username")


                // get computer prestages

                Json().getRecord(serverUrl: self.serverUrl, token: self.token, theEndpoint: "computer-prestages", page: 0, skip: self.skip(endpoint: "computer-prestages")) {
                (result: [String:AnyObject]) in
//                    WriteToLog().message(stringOfText: "prestages: \(result)")
                    if let _ = result["results"] {
                        let computerPrestageArray = result["results"] as! [[String:Any]]
                        for computerPrestage in computerPrestageArray {
                            WriteToLog().message(stringOfText: "computerPresgate: \(computerPrestage)")
                            if let _ = computerPrestage["displayName"], let _ = computerPrestage["id"], let _ = computerPrestage["anchorCertificates"] {
                                let displayName = "\(String(describing: computerPrestage["displayName"]!))"
                                let id = "\(String(describing: computerPrestage["id"]!))"
                                let anchorCertificates = computerPrestage["anchorCertificates"]! as! [String]

                                for certificate in anchorCertificates {
                                    let base64Encoded = certificate

                                    let decodedData = Data(base64Encoded: base64Encoded)!
                                    let pemCertString = String(data: decodedData, encoding: .utf8)!

    //                                    print(pemCertString)

    //                                    WriteToLog().message(stringOfText: "Anchor certificate for \(displayName): \(pemCertString)")
                                    let certData = Data(base64Encoded: self.pemToString(pemCert: pemCertString))!

                                    if let certificate = SecCertificateCreateWithData(nil, certData as CFData) {
                                        let summary = SecCertificateCopySubjectSummary(certificate)! as String
    //                                        let stuff = SecCertificateCopyData(certificate)
                                        // and then doing a SHA1 of that data (with
                                        // CC_SHA1
                                        // nope - let fp = "\(stuff)".sha1()

    //                                        let data = Data(self.utf8)

                                        var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
                                        certData.withUnsafeBytes {
                                            _ = CC_SHA1($0.baseAddress, CC_LONG(certData.count), &digest)
                                        }
                                        let fp = digest.map { String(format: "%02hhx", $0) }
                                        var fingerprint = ""
                                        for hexValue in fp {
                                            fingerprint.append("\(hexValue) ")
                                        }

                                        WriteToLog().message(stringOfText: "Cert Name: \(summary) \t fingerprint: \(fingerprint)")
                                        // add cert to dropdown list
    //                                        self.existingAnchors_Button.addItem(withTitle: "\(summary)")
                                    }
                                }

    //                                WriteToLog().message(stringOfText: "Display Name: \(String(describing: displayName))")
    //                                WriteToLog().message(stringOfText: "anchorCertificates count: \(anchorCertificates.count)")
                                if anchorCertificates.count > 0 {
    //                                    WriteToLog().message(stringOfText: "before: \(computerPrestage)")
                                    if self.withAnchorArray?.count != nil {
    //                                        WriteToLog().message(stringOfText: "add to withAnchorArray")
                                        self.withAnchorArray?.append(["computer", "\(String(describing: displayName))", "\(id)"])
                                    } else {
    //                                        WriteToLog().message(stringOfText: "initialize withAnchorArray")
                                        self.withAnchorArray = [["computer", "\(String(describing: displayName))", "\(id)"]]
                                    }
    //                                    let modifiedAnchorCertificates = [String]()
                                    var modifiedPrestage = computerPrestage
                                    modifiedPrestage["anchorCertificates"] = [String]() //modifiedAnchorCertificates

                                    self.modifiedComputerPrestages["\(id)"] = modifiedPrestage
    //                                    WriteToLog().message(stringOfText: "after: \(self.modifiedComputerPrestages)")
                                    DispatchQueue.main.async {
                                        self.prestages_TableView.reloadData()
            //                            WriteToLog().message(stringOfText: "\(String(describing: self.withAnchorArray))")
                                    }
                                }
                            } else {
                                WriteToLog().message(stringOfText: "missing data in \(computerPrestage)")
                            }
                        }
                        WriteToLog().message(stringOfText: "finished fetching macOS prestages")
                        WriteToLog().message(stringOfText: "platforms: \(self.platforms)")
                        if self.platforms == "macOS" {
                            print("macOS only, stop spinner")
                            self.spinner(action: "stop")
                        }
                    }

                    // get mobile device prestages
                    Json().getRecord(serverUrl: self.serverUrl, token: self.token, theEndpoint: "mobile-device-prestages", page: 0, skip: self.skip(endpoint: "mobile-device-prestages")) {
                    (result: [String:AnyObject]) in
//                        WriteToLog().message(stringOfText: "prestages: \(result)")
                        if let _ = result["results"] {
                            let prestageArray = result["results"] as! [Dictionary<String, Any>]
//                            let prestageCount = prestageArray.count
//                            if prestageCount > 0 {
                                for devicePrestage in prestageArray {
                                    if let _ = devicePrestage["displayName"], let _ = devicePrestage["id"], let _ = devicePrestage["anchorCertificates"] {
                                        let displayName = "\(String(describing: devicePrestage["displayName"]!))"
                                        let id = "\(String(describing: devicePrestage["id"]!))"
                                        let anchorCertificates = devicePrestage["anchorCertificates"]! as! [String]

    //                                    WriteToLog().message(stringOfText: "Display Name: \(String(describing: displayName))")
    //                                    WriteToLog().message(stringOfText: "anchorCertificates count: \(anchorCertificates.count)")
                                        if anchorCertificates.count > 0 {
    //                                        WriteToLog().message(stringOfText: "before: \(devicePrestage)")
                                            if self.withAnchorArray?.count != nil {
    //                                            WriteToLog().message(stringOfText: "add to withAnchorArray")
                                                self.withAnchorArray?.append(["mobile", "\(String(describing: displayName))", "\(id)"])
                                            } else {
    //                                            WriteToLog().message(stringOfText: "initialize withAnchorArray")
                                                self.withAnchorArray = [["mobile", "\(String(describing: displayName))", "\(id)"]]
                                            }
                                            var modifiedPrestage = devicePrestage
                                            modifiedPrestage["anchorCertificates"] = [String]() //modifiedAnchorCertificates

                                            self.modifiedMobilePrestages["\(id)"] = modifiedPrestage
    //                                        WriteToLog().message(stringOfText: "after: \(modifiedPrestage)")
                                            DispatchQueue.main.async {
                                                self.prestages_TableView.reloadData()
                //                                WriteToLog().message(stringOfText: "\(String(describing: self.withAnchorArray))")
                                            }
                                        }
                                    } else {
                                        WriteToLog().message(stringOfText: "missing data in \(devicePrestage)")
                                    }
                                }
                                self.spinner(action: "stop")
//                            } else {
//                                self.spinner(action: "stop")
//                            }
                        }
                    }   //Json().getRecord - mobile - end
                }   //Json().getRecord - computers - end
            }
        }
    }

    func pemToString(pemCert: String) -> String {
        var certAsString = pemCert
        certAsString = certAsString.replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
        certAsString = certAsString.replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
        certAsString = certAsString.replacingOccurrences(of: "\n", with: "")
        return certAsString
    }

    func removeAnchors() {
        WriteToLog().message(stringOfText: "modifying prestages")
        spinner(action: "start")
        let totalRecords = (withAnchorArray?.count)!
        var processed = 1
        // computers
        for (id, prestage) in modifiedComputerPrestages {
            WriteToLog().message(stringOfText: "modified computer prestage - id=\(id):")
            WriteToLog().message(stringOfText: "\(prestage)")
            Json().putRecord(serverUrl: self.serverUrl, token: self.token, theEndpoint: "computer-prestages/\(id)", prestage: prestage) {
                (result: [String:[String:Any]]) in
                for (httpResponse, _) in result {
                    WriteToLog().message(stringOfText: "put response for computer prestage id \(id): \(httpResponse)")
                    processed+=1
                }
            }
        }
        // mobile devices
        for (id, prestage) in modifiedMobilePrestages {
            WriteToLog().message(stringOfText: "modified mobile prestage - id=\(id):")
            WriteToLog().message(stringOfText: "\(prestage)")
            Json().putRecord(serverUrl: self.serverUrl, token: self.token, theEndpoint: "mobile-device-prestages/\(id)", prestage: prestage) {
                (result: [String:[String:Any]]) in
                for (httpResponse, _) in result {
                    WriteToLog().message(stringOfText: "put response for mobile device prestage id \(id): \(httpResponse)")
                    processed+=1
                }
            }
        }
        progressQ.async {
            while processed < totalRecords {
                sleep(2)
            }
            self.spinner(action: "stop")
        }
    }

    func skip(endpoint: String) -> Bool {
        var skipResult = false
        switch endpoint {
        case "computer-prestages":
            if platforms == "iOS" {
                skipResult = true
            }
        default:
            if platforms == "macOS" {
                skipResult = true
            }
        }
        return skipResult
    }

    func spinner(action: String) {
        DispatchQueue.main.async {
            if action == "start" {
                self.spinner_ProgressIndicator.startAnimation(self)
            } else {
                self.spinner_ProgressIndicator.stopAnimation(self)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        serverUrl_TextField.stringValue = defaults.object(forKey: "serverUrl") as? String ?? ""
        username_TextField.stringValue  = defaults.object(forKey: "username") as? String ?? ""

        NSApp.activate(ignoringOtherApps: true)

        prestages_TableView.delegate   = self
        prestages_TableView.dataSource = self

        // Do any additional setup after loading the view.
        
        History.logFile = WriteToLog().getCurrentTime().replacingOccurrences(of: ":", with: "") + "_AnchorsAway.log"
        
        // create log directory if missing - start
        if !fm.fileExists(atPath: History.logPath!) {
            do {
                try fm.createDirectory(atPath: History.logPath!, withIntermediateDirectories: true, attributes: nil )
                } catch {
                    Alert().display(header: "Error:", message: "Unable to create log directory:\n\(String(describing: History.logPath))\nTry creating it manually.")
                    NSApplication.shared.terminate(self)
            }
        }
        // create log directory if missing - end
        
        // create log file
        isDir = false
        if !(fm.fileExists(atPath: History.logPath! + History.logFile, isDirectory: &isDir)) {
            fm.createFile(atPath: History.logPath! + History.logFile, contents: nil, attributes: nil)
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}


extension ViewController: NSTableViewDataSource {
    func numberOfRows(in object_TableView: NSTableView) -> Int {
//        WriteToLog().message(stringOfText: "[numberOfRows] \(withAnchorArray?.count ?? 0)")
        return withAnchorArray?.count ?? 0
    }
}


extension ViewController: NSTableViewDelegate {

    fileprivate enum CellIdentifiers {
        static let TypeCell = "Type_Cell-ID"
        static let NameCell = "Name_Cell-ID"
    }

    func tableView(_ object_TableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        var text: String = ""
        var cellIdentifier: String = ""

//        WriteToLog().message(stringOfText: "[func tableView] item: \(withAnchorArray?[row] ?? nil)")
        
        guard let item = withAnchorArray?[row] else {
            return nil
        }


        if tableColumn == object_TableView.tableColumns[0] {
            text = item[0]
            cellIdentifier = CellIdentifiers.TypeCell
        } else if tableColumn == object_TableView.tableColumns[1] {
            text = item[1]
            cellIdentifier = CellIdentifiers.NameCell
//            object_TableView.tableColumns[1].isHidden = false
        }
//        } else if tableColumn == object_TableView.tableColumns[2] {
//            let result:NSPopUpButton = tableView.make(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "objectType"), owner: self) as! NSPopUpButton
//            cellIdentifier = CellIdentifiers.TypeCell
//        }

        if let cell = object_TableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            return cell
        }
        return nil
    }



}

extension String {
    func sha1() -> String {
        let data = Data(self.utf8)
        var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }
        let hexBytes = digest.map { String(format: "%02hhx", $0) }
        return hexBytes.joined()
    }
}
