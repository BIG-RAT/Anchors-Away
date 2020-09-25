//
//  ViewController.swift
//  Anchors Away
//
//  Created by Leslie Helou on 9/24/20.
//  Copyright © 2020 Leslie Helou. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var serverUrl_TextField: NSTextField!
    @IBOutlet weak var username_TextField: NSTextField!
    @IBOutlet weak var password_TextField: NSSecureTextField!

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

    let defaults = UserDefaults.standard

    @IBOutlet weak var spinner_ProgressIndicator: NSProgressIndicator!
    var progressQ     = DispatchQueue(label: "com.jamf.aa.progressq", qos: DispatchQoS.background)

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

    func fetchPrestages() {
        serverUrl = serverUrl_TextField.stringValue
        jamfCreds           = "\(username_TextField.stringValue):\(password_TextField.stringValue)"
        let jamfUtf8Creds   = jamfCreds.data(using: String.Encoding.utf8)
        jamfCredsB64     = (jamfUtf8Creds?.base64EncodedString())!

        spinner(action: "start")
        // get token for authentication
        Json().getToken(serverUrl: serverUrl, base64creds: jamfCredsB64) {
            (result: String) in
//            print("token: \(result)")
            if result != "" {
                self.token = result

                self.defaults.set("\(self.serverUrl_TextField.stringValue)", forKey: "serverUrl")
                self.defaults.set("\(self.username_TextField.stringValue)", forKey: "username")

                self.withAnchorArray?.removeAll()
                // get computer prestages
                Json().getRecord(serverUrl: self.serverUrl, token: self.token, theEndpoint: "computer-prestages") {
                (result: [String:AnyObject]) in
//                    print("prestages: \(result)")
                    if let _ = result["results"] {
                        let computerPrestageArray = result["results"] as! [Dictionary<String, Any>]
                        let computerPrestageCount = computerPrestageArray.count
                        if computerPrestageCount > 0 {
                            for computerPrestage in computerPrestageArray {
                                let displayName = "\(String(describing: computerPrestage["displayName"]!))"
                                let id = "\(String(describing: computerPrestage["id"]!))"
                                let anchorCertificates = computerPrestage["anchorCertificates"]! as! [String]

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
                            }
                        }
                    }

                    // get mobile device prestages
                    Json().getRecord(serverUrl: self.serverUrl, token: self.token, theEndpoint: "mobile-device-prestages") {
                    (result: [String:AnyObject]) in
//                        print("prestages: \(result)")
                        if let _ = result["results"] {
                            let prestageArray = result["results"] as! [Dictionary<String, Any>]
                            let prestageCount = prestageArray.count
                            if prestageCount > 0 {
                                for devicePrestage in prestageArray {
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
                                }
                                self.spinner(action: "stop")
                            }

                        }
                    }   //Json().getRecord - mobile - end
                }   //Json().getRecord - computers - end

            }
        }

    }

    func removeAnchors() {
        print("modifying prestages")
        spinner(action: "start")
        let totalRecords = (withAnchorArray?.count)!
        var processed = 1
        // computers
        for (id, prestage) in modifiedComputerPrestages {
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
//            text = String("\(item)".split(separator: ",")[0])
            cellIdentifier = CellIdentifiers.TypeCell
        } else if tableColumn == object_TableView.tableColumns[1] {
            text = item[1]
//            text = String("\(item)".split(separator: ",")[1])
            cellIdentifier = CellIdentifiers.NameCell
//            object_TableView.tableColumns[1].isHidden = false
        }
//        } else if tableColumn == object_TableView.tableColumns[1] {
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
