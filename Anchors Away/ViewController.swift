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

    let defaults = UserDefaults.standard

    @IBOutlet weak var spinner_ProgressIndicator: NSProgressIndicator!
    var progressQ     = DispatchQueue(label: "com.jamf.aa.progressq", qos: DispatchQoS.background)

    @IBAction func anchorsToRemove(_ sender: Any) {
//        print("\(platforms_Button.titleOfSelectedItem!)")
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
        print("\(String(describing: platforms_Button.titleOfSelectedItem))")
    }


    func fetchPrestages() {
        serverUrl = serverUrl_TextField.stringValue
        jamfCreds           = "\(username_TextField.stringValue):\(password_TextField.stringValue)"
        let jamfUtf8Creds   = jamfCreds.data(using: String.Encoding.utf8)
        jamfCredsB64     = (jamfUtf8Creds?.base64EncodedString())!

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
//            print("token: \(result)")
            if result != "" {
                self.token = result

                self.defaults.set("\(self.serverUrl_TextField.stringValue)", forKey: "serverUrl")
                self.defaults.set("\(self.username_TextField.stringValue)", forKey: "username")


                // get computer prestages

                Json().getRecord(serverUrl: self.serverUrl, token: self.token, theEndpoint: "computer-prestages", skip: self.skip(endpoint: "computer-prestages")) {
                (result: [String:AnyObject]) in
//                    print("prestages: \(result)")
                    if let _ = result["results"] {
                        let computerPrestageArray = result["results"] as! [[String:Any]]
                        for computerPrestage in computerPrestageArray {
                            if let _ = computerPrestage["displayName"], let _ = computerPrestage["id"], let _ = computerPrestage["anchorCertificates"] {
                                let displayName = "\(String(describing: computerPrestage["displayName"]!))"
                                let id = "\(String(describing: computerPrestage["id"]!))"
                                let anchorCertificates = computerPrestage["anchorCertificates"]! as! [String]

                                for certificate in anchorCertificates {
                                    let base64Encoded = certificate

                                    let decodedData = Data(base64Encoded: base64Encoded)!
                                    let pemCertString = String(data: decodedData, encoding: .utf8)!

    //                                    print(pemCertString)

    //                                    print("Anchor certificate for \(displayName): \(pemCertString)")
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

                                        print("Cert Name: \(summary) \t fingerprint: \(fingerprint)")
                                        // add cert to dropdown list
    //                                        self.existingAnchors_Button.addItem(withTitle: "\(summary)")
                                    }
                                }

    //                                print("Display Name: \(String(describing: displayName))")
    //                                print("anchorCertificates count: \(anchorCertificates.count)")
                                if anchorCertificates.count > 0 {
    //                                    print("before: \(computerPrestage)")
                                    if self.withAnchorArray?.count != nil {
    //                                        print("add to withAnchorArray")
                                        self.withAnchorArray?.append(["computer", "\(String(describing: displayName))", "\(id)"])
                                    } else {
    //                                        print("initialize withAnchorArray")
                                        self.withAnchorArray = [["computer", "\(String(describing: displayName))", "\(id)"]]
                                    }
    //                                    let modifiedAnchorCertificates = [String]()
                                    var modifiedPrestage = computerPrestage
                                    modifiedPrestage["anchorCertificates"] = [String]() //modifiedAnchorCertificates

                                    self.modifiedComputerPrestages["\(id)"] = modifiedPrestage
    //                                    print("after: \(self.modifiedComputerPrestages)")
                                    DispatchQueue.main.async {
                                        self.prestages_TableView.reloadData()
            //                            print("\(String(describing: self.withAnchorArray))")
                                    }
                                }
                            } else {
                                print("missing data in \(computerPrestage)")
                            }
                        }
                        print("finished fetching macOS prestages")
                        print("platforms: \(self.platforms)")
                        if self.platforms == "macOS" {
                            print("macOS only, stop spinner")
                            self.spinner(action: "stop")
                        }
                    }

                    // get mobile device prestages
                    Json().getRecord(serverUrl: self.serverUrl, token: self.token, theEndpoint: "mobile-device-prestages", skip: self.skip(endpoint: "mobile-device-prestages")) {
                    (result: [String:AnyObject]) in
//                        print("prestages: \(result)")
                        if let _ = result["results"] {
                            let prestageArray = result["results"] as! [Dictionary<String, Any>]
                            let prestageCount = prestageArray.count
                            if prestageCount > 0 {
                                for devicePrestage in prestageArray {
                                    if let _ = devicePrestage["displayName"], let _ = devicePrestage["id"], let _ = devicePrestage["anchorCertificates"] {
                                        let displayName = "\(String(describing: devicePrestage["displayName"]!))"
                                        let id = "\(String(describing: devicePrestage["id"]!))"
                                        let anchorCertificates = devicePrestage["anchorCertificates"]! as! [String]

    //                                    print("Display Name: \(String(describing: displayName))")
    //                                    print("anchorCertificates count: \(anchorCertificates.count)")
                                        if anchorCertificates.count > 0 {
    //                                        print("before: \(devicePrestage)")
                                            if self.withAnchorArray?.count != nil {
    //                                            print("add to withAnchorArray")
                                                self.withAnchorArray?.append(["mobile", "\(String(describing: displayName))", "\(id)"])
                                            } else {
    //                                            print("initialize withAnchorArray")
                                                self.withAnchorArray = [["mobile", "\(String(describing: displayName))", "\(id)"]]
                                            }
                                            var modifiedPrestage = devicePrestage
                                            modifiedPrestage["anchorCertificates"] = [String]() //modifiedAnchorCertificates

                                            self.modifiedMobilePrestages["\(id)"] = modifiedPrestage
    //                                        print("after: \(modifiedPrestage)")
                                            DispatchQueue.main.async {
                                                self.prestages_TableView.reloadData()
                //                                print("\(String(describing: self.withAnchorArray))")
                                            }
                                        }
                                    } else {
                                        print("missing data in \(devicePrestage)")
                                    }
                                }
                                self.spinner(action: "stop")
                            }

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
        print("modifying prestages")
        spinner(action: "start")
        let totalRecords = (withAnchorArray?.count)!
        var processed = 1
        // computers
        for (id, prestage) in modifiedComputerPrestages {
            print("\nmodified computer prestage - id=\(id):")
            print("\(prestage)")
            Json().putRecord(serverUrl: self.serverUrl, token: self.token, theEndpoint: "computer-prestages/\(id)", prestage: prestage) {
                (result: [String:[String:Any]]) in
                for (httpResponse, _) in result {
                    print("put response for computer prestage id \(id): \(httpResponse)")
                    processed+=1
                }
            }
        }
        // mobile devices
        for (id, prestage) in modifiedMobilePrestages {
            print("\nmodified mobile prestage - id=\(id):")
            print("\(prestage)")
            Json().putRecord(serverUrl: self.serverUrl, token: self.token, theEndpoint: "mobile-device-prestages/\(id)", prestage: prestage) {
                (result: [String:[String:Any]]) in
                for (httpResponse, _) in result {
                    print("put response for mobile device prestage id \(id): \(httpResponse)")
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
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}


extension ViewController: NSTableViewDataSource {
    func numberOfRows(in object_TableView: NSTableView) -> Int {
//        print("[numberOfRows] \(withAnchorArray?.count ?? 0)")
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

//        print("[func tableView] item: \(withAnchorArray?[row] ?? nil)")
        
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
