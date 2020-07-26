//
//  CreateRawTxViewController.swift
//  BitSense
//
//  Created by Peter on 09/10/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit

class CreateRawTxViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource {
    
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    var tapQRGesture = UITapGestureRecognizer()
    var tapTextViewGesture = UITapGestureRecognizer()
    var qrCode = UIImage()
    
    var spendable = Double()
    var rawTxUnsigned = String()
    var rawTxSigned = String()
    var amountAvailable = Double()
    let qrImageView = UIImageView()
    var stringURL = String()
    var address = String()
    var amount = String()
    var blurArray = [UIVisualEffectView]()
    let rawDisplayer = RawDisplayer()
    var scannerShowing = false
    var isFirstTime = Bool()
    var outputs = [Any]()
    var outputsString = ""
    
    @IBOutlet weak var addOutputOutlet: UIBarButtonItem!
    @IBOutlet weak var playButtonOutlet: UIBarButtonItem!
    @IBOutlet var amountInput: UITextField!
    @IBOutlet var addressInput: UITextField!
    @IBOutlet var amountLabel: UILabel!
    @IBOutlet var actionOutlet: UIButton!
    @IBOutlet var scanOutlet: UIButton!
    @IBOutlet var receivingLabel: UILabel!
    @IBOutlet var outputsTable: UITableView!
    @IBOutlet var scannerView: UIImageView!
    
    var creatingView = ConnectingView()
    let qrScanner = QRScanner()
    var isTorchOn = Bool()
    let qrGenerator = QRGenerator()
    var spendableBalance = Double()
    var outputArray = [[String:String]]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        amountInput.delegate = self
        addressInput.delegate = self
        outputsTable.delegate = self
        outputsTable.dataSource = self
        outputsTable.tableFooterView = UIView(frame: .zero)
        outputsTable.alpha = 0
        configureRawDisplayer()
        configureScanner()
        addTapGesture()
        scannerView.alpha = 0
        scannerView.backgroundColor = UIColor.black
    }
    
    @IBAction func createPsbt(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToCreatePsbt", sender: vc)
        }
    }
    
    @IBAction func makeADonationAction(_ sender: Any) {
        if let address = Keys.donationAddress() {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.addressInput.text = address
                showAlert(vc: vc, title: "Thank you!", message: "A donation address has automatically been added so you may build a transaction which will fund further development of Fully Noded.\n\nFully Noded is free but has cost an enormous amount of time, blood, sweat and tears to bring it to where it is today as well as a significant amount of money.\n\nPlease donate generously so that the app may remain free for all to use and so that new awesome features can continue to be added!")
            }
        }
    }
    
    func configureScanner() {
        
        isFirstTime = true
        
        scannerView.alpha = 0
        scannerView.frame = view.frame
        scannerView.isUserInteractionEnabled = true
        
        qrScanner.uploadButton.addTarget(self, action: #selector(chooseQRCodeFromLibrary),
                                         for: .touchUpInside)
        
        qrScanner.keepRunning = false
        qrScanner.vc = self
        qrScanner.imageView = scannerView
        qrScanner.textField.alpha = 0
        
        qrScanner.downSwipeAction = { self.back() }
        qrScanner.completion = { self.getQRCode() }
        qrScanner.didChooseImage = { self.didPickImage() }
        
        qrScanner.uploadButton.addTarget(self,
                                         action: #selector(self.chooseQRCodeFromLibrary),
                                         for: .touchUpInside)
        
        qrScanner.torchButton.addTarget(self,
                                        action: #selector(toggleTorch),
                                        for: .touchUpInside)
        
        isTorchOn = false
        
        qrScanner.closeButton.addTarget(self,
                                        action: #selector(back),
                                        for: .touchUpInside)
        
    }
    
    func addScannerButtons() {
        
        self.addBlurView(frame: CGRect(x: self.scannerView.frame.maxX - 80,
                                       y: self.scannerView.frame.maxY - 80,
                                       width: 70,
                                       height: 70), button: self.qrScanner.uploadButton)
        
        self.addBlurView(frame: CGRect(x: 10,
                                       y: self.scannerView.frame.maxY - 80,
                                       width: 70,
                                       height: 70), button: self.qrScanner.torchButton)
        
    }
    
    @IBAction func scanNow(_ sender: Any) {
        
        print("scanNow")
        
        scannerShowing = true
        addressInput.resignFirstResponder()
        amountInput.resignFirstResponder()
        
        if isFirstTime {
            
            DispatchQueue.main.async {
                
                self.qrScanner.scanQRCode()
                self.addScannerButtons()
                self.scannerView.addSubview(self.qrScanner.closeButton)
                self.isFirstTime = false
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.scannerView.alpha = 1
                    
                })
                
            }
            
        } else {
            
            self.qrScanner.startScanner()
            self.addScannerButtons()
            
            DispatchQueue.main.async {
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.scannerView.alpha = 1
                    
                })
                
            }
            
        }
        
    }
    
    @IBAction func addOutput(_ sender: Any) {
        
        if amountInput.text != "" && addressInput.text != "" && amountInput.text != "0.0" {
            
            let dict = ["address":addressInput.text!, "amount":amountInput.text!] as [String : String]
            
            outputArray.append(dict)
            
            DispatchQueue.main.async {
                
                self.outputsTable.alpha = 1
                self.amountInput.text = ""
                self.addressInput.text = ""
                self.outputsTable.reloadData()
                
            }
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "You need to fill out a recipient and amount first then tap this button, this button is used for adding multiple recipients aka \"batching\".")
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        return "Outputs:"
        
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        return 30
        
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        
        (view as! UITableViewHeaderFooterView).backgroundView?.backgroundColor = UIColor.clear
        (view as! UITableViewHeaderFooterView).textLabel?.textAlignment = .left
        (view as! UITableViewHeaderFooterView).textLabel?.font = UIFont.init(name: "System", size: 17)
        (view as! UITableViewHeaderFooterView).textLabel?.textColor = UIColor.darkGray
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return outputArray.count
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        return 85
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        cell.backgroundColor = view.backgroundColor
        
        if outputArray.count > 0 {
            
            if outputArray.count > 1 {
                
                tableView.separatorColor = UIColor.white
                tableView.separatorStyle = .singleLine
                
            }
            
            let address = outputArray[indexPath.row]["address"]!
            let amount = outputArray[indexPath.row]["amount"]!
            
            cell.textLabel?.text = "\n#\(indexPath.row + 1)\n\nSending: \(String(describing: amount))\n\nTo: \(String(describing: address))"
            
        } else {
            
           cell.textLabel?.text = ""
            
        }
        
        return cell
        
    }
    
    func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
    }
    
    func getQRCode() {
        
        let stringURL = qrScanner.stringToReturn
        processKeys(key: stringURL)
        
    }
    
    // MARK: User Actions
    
    @IBAction func sweep(_ sender: Any) {
        
        if addressInput.text != "" {
            creatingView.addConnectingView(vc: self, description: "sweeping...")
            let receivingAddress = addressInput.text!
            Reducer.makeCommand(command: .listunspent, param: "0") { [unowned vc = self] (response, errorMessage) in
                if let resultArray = response as? NSArray {
                    var inputArray = [Any]()
                    var inputs = ""
                    var amount = Double()
                    var spendFromCold = Bool()
                    
                    for utxo in resultArray {
                        let utxoDict = utxo as! NSDictionary
                        let txid = utxoDict["txid"] as! String
                        let vout = "\(utxoDict["vout"] as! Int)"
                        let spendable = utxoDict["spendable"] as! Bool
                        if !spendable {
                            spendFromCold = true
                        }
                        amount += utxoDict["amount"] as! Double
                        let input = "{\"txid\":\"\(txid)\",\"vout\": \(vout),\"sequence\": 1}"
                        inputArray.append(input)
                    }
                    
                    inputs = inputArray.description
                    inputs = inputs.replacingOccurrences(of: "[\"", with: "[")
                    inputs = inputs.replacingOccurrences(of: "\"]", with: "]")
                    inputs = inputs.replacingOccurrences(of: "\"{", with: "{")
                    inputs = inputs.replacingOccurrences(of: "}\"", with: "}")
                    inputs = inputs.replacingOccurrences(of: "\\", with: "")
                    
                    let ud = UserDefaults.standard
                    let param = "''\(inputs)'', ''{\"\(receivingAddress)\":\(vc.rounded(number: amount))}'', 0, ''{\"includeWatching\": \(spendFromCold), \"replaceable\": true, \"conf_target\": \(ud.object(forKey: "feeTarget") as! Int), \"subtractFeeFromOutputs\": [0], \"changeAddress\": \"\(receivingAddress)\"}'', true"
                    Reducer.makeCommand(command: .walletcreatefundedpsbt, param: param) { (response, errorMessage) in
                        if let result = response as? NSDictionary {
                            let psbt1 = result["psbt"] as! String
                            Reducer.makeCommand(command: .walletprocesspsbt, param: "\"\(psbt1)\"") { [unowned vc = self] (response, errorMessage) in
                                if let dict = response as? NSDictionary {
                                    if let processedPSBT = dict["psbt"] as? String {
                                        Signer.sign(psbt: processedPSBT) { (psbt, rawTx, errorMessage) in
                                            if psbt != nil {
                                                vc.rawTxSigned = psbt!
                                                vc.creatingView.removeConnectingView()
                                                vc.showRaw(raw: psbt!)
                                                DispatchQueue.main.async {
                                                    vc.removeViews()
                                                    vc.navigationController?.navigationBar.topItem?.title = "PSBT"
                                                    vc.tapTextViewGesture = UITapGestureRecognizer(target: self, action: #selector(vc.sharePSBT(_:)))
                                                    vc.rawDisplayer.textView.addGestureRecognizer(vc.tapTextViewGesture)
                                                    vc.exportPsbt()
                                                }
                                            } else if rawTx != nil {
                                                vc.rawTxSigned = rawTx!
                                                vc.creatingView.removeConnectingView()
                                                vc.showRaw(raw: rawTx!)
                                                DispatchQueue.main.async {
                                                    vc.removeViews()
                                                    vc.navigationController?.navigationBar.topItem?.title = "Signed Tx"
                                                    vc.tapTextViewGesture = UITapGestureRecognizer(target: self, action: #selector(vc.shareRawText(_:)))
                                                    vc.rawDisplayer.textView.addGestureRecognizer(vc.tapTextViewGesture)
                                                }
                                                vc.broadcastNow()
                                                
                                            } else if errorMessage != nil {
                                                vc.creatingView.removeConnectingView()
                                                showAlert(vc: vc, title: "Error", message: errorMessage!)
                                            }
                                        }
                                    }
                                } else {
                                    vc.creatingView.removeConnectingView()
                                    displayAlert(viewController: vc, isError: true, message: errorMessage ?? "")
                                }
                            }
                        } else {
                            vc.creatingView.removeConnectingView()
                            displayAlert(viewController: vc, isError: true, message: errorMessage ?? "")
                        }
                    }
                } else {
                    vc.creatingView.removeConnectingView()
                    displayAlert(viewController: vc, isError: true, message: errorMessage ?? "")
                }
            }
        }
    }
    
    func configureRawDisplayer() {
        
        rawDisplayer.vc = self
        
        tapQRGesture = UITapGestureRecognizer(target: self,
                                              action: #selector(shareQRCode(_:)))
        
        rawDisplayer.qrView.addGestureRecognizer(tapQRGesture)
        
    }
    
    func removeViews() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.amountInput.removeFromSuperview()
            vc.addressInput.removeFromSuperview()
            vc.amountLabel.removeFromSuperview()
            vc.receivingLabel.removeFromSuperview()
            vc.scanOutlet.removeFromSuperview()
            vc.outputsTable.removeFromSuperview()
        }
    }
    
    func showRaw(raw: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.playButtonOutlet.tintColor = UIColor.lightGray.withAlphaComponent(0)
            vc.addOutputOutlet.tintColor = UIColor.lightGray.withAlphaComponent(0)
            vc.rawDisplayer.rawString = raw
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: { [unowned vc = self] in
                vc.scannerView.removeFromSuperview()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: { [unowned vc = self] in
                    vc.rawDisplayer.addRawDisplay()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: { [unowned vc = self] in
                        vc.creatingView.removeConnectingView()
                    })
                })
            })
        }
    }
    
    @IBAction func tryRawNow(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.amountInput.resignFirstResponder()
            vc.addressInput.resignFirstResponder()
        }
        tryRaw()
    }
    
    @objc func tryRaw() {
        
        creatingView.addConnectingView(vc: self,
                                       description: "Creating Raw")
        
        func convertOutputs() {
            
            for output in outputArray {
                
                if let amount = output["amount"] {
                    
                    if let address = output["address"] {
                        
                        if address != "" {
                            
                            let dbl = Double(amount)!
                            let out = [address:dbl]
                            outputs.append(out)
                            
                        }
                        
                    }
                    
                }
                
            }
            
            outputsString = outputs.description
            outputsString = outputsString.replacingOccurrences(of: "[", with: "")
            outputsString = outputsString.replacingOccurrences(of: "]", with: "")
            self.getRawTx()
            
        }
        
        if outputArray.count == 0 {
            
            if self.amountInput.text != "" && self.amountInput.text != "0.0" && self.addressInput.text != "" {
                
                let dict = ["address":addressInput.text!, "amount":amountInput.text!] as [String : String]
                
                outputArray.append(dict)
                convertOutputs()
                
            } else {
                
                creatingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "You need to fill out an amount and a recipient")
                
            }
            
        } else if outputArray.count > 0 && self.amountInput.text != "" || self.amountInput.text != "0.0" && self.addressInput.text != "" {
            
            creatingView.removeConnectingView()
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "If you want to add multiple recipients please tap the \"+\" and add them all first.")
            
        } else if outputArray.count > 0 {
            
            convertOutputs()
            
        }
        
    }
    
    @objc func shareRawText(_ sender: UITapGestureRecognizer) {
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.rawDisplayer.textView.alpha = 0
                
            }) { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    self.rawDisplayer.textView.alpha = 1
                    
                })
                
            }
            
            let textToShare = [self.rawDisplayer.rawString]
            
            let activityViewController = UIActivityViewController(activityItems: textToShare,
                                                                  applicationActivities: nil)
            
            activityViewController.popoverPresentationController?.sourceView = self.view
            self.present(activityViewController, animated: true) {}
            
        }
        
    }
    
    @objc func shareQRCode(_ sender: UITapGestureRecognizer) {
        print("shareQRCode")
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.rawDisplayer.qrView.alpha = 0
                
            }) { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    self.rawDisplayer.qrView.alpha = 1
                    
                })
                
            }
            
            self.qrGenerator.textInput = self.rawDisplayer.rawString
            let qrImage = self.qrGenerator.getQRCode()
            let objectsToShare = [qrImage]
                
            let activityController = UIActivityViewController(activityItems: objectsToShare,
                                                              applicationActivities: nil)
            
            activityController.popoverPresentationController?.sourceView = self.view
            self.present(activityController, animated: true) {}
            
        }
        
    }
    
    func didPickImage() {
        
        let qrString = qrScanner.qrString
        processKeys(key: qrString)
        
    }
    
    @objc func chooseQRCodeFromLibrary() {
        
        qrScanner.chooseQRCodeFromLibrary()
        
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        
        amountInput.resignFirstResponder()
        addressInput.resignFirstResponder()
        
    }
    
    @IBAction func backAction(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    //MARK: User Interface
    
    func addShadow(view: UIView) {
        
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 1.5, height: 1.5)
        view.layer.shadowRadius = 1.5
        view.layer.shadowOpacity = 0.5
        
    }
    
    func generateQrCode(key: String) -> UIImage {
        
        self.qrGenerator.textInput = key
        let imageToReturn = self.qrGenerator.getQRCode()
        
        return imageToReturn
        
    }
    
    func addBlurView(frame: CGRect, button: UIButton) {
        
        button.removeFromSuperview()
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
        blur.frame = frame
        blur.clipsToBounds = true
        blur.layer.cornerRadius = frame.width / 2
        blur.contentView.addSubview(button)
        self.scannerView.addSubview(blur)
        
    }
    
    @objc func back() {
        
        DispatchQueue.main.async {
            
            self.scannerView.alpha = 0
            self.scannerShowing = false
            
        }
        
    }
    
    @objc func toggleTorch() {
        
        if isTorchOn {
            
            qrScanner.toggleTorch(on: false)
            isTorchOn = false
            
        } else {
            
            qrScanner.toggleTorch(on: true)
            isTorchOn = true
            
        }
        
    }
    
    //MARK: Textfield methods
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        print("shouldChangeCharactersInRange")
        
        if (textField.text?.contains("."))! {
            
           let decimalCount = (textField.text?.components(separatedBy: ".")[1])?.count
            
            if decimalCount! <= 7 {
                
                
            } else {
                
                DispatchQueue.main.async {
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: "Only 8 decimal places allowed")
                    
                    self.amountInput.text = ""
                    
                }
                
            }
            
        }
        
        return true
        
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        
        textField.resignFirstResponder()
        
        if textField == addressInput && addressInput.text != "" {
            
            processKeys(key: addressInput.text!)
            
        } else if textField == addressInput && addressInput.text == "" {
            
            shakeAlert(viewToShake: self.qrScanner.textField)
            
        }
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        if isTorchOn {
            
            toggleTorch()
            
        }
        
    }
    
    //MARK: Helpers
    
    private func rounded(number: Double) -> Double {
        return Double(round(100000000*number)/100000000)
    }
    
    func processBIP21(url: String) {
        
        let addressParser = AddressParser()
        let errorBool = addressParser.parseAddress(url: url).errorBool
        let errorDescription = addressParser.parseAddress(url: url).errorDescription
        
        if !errorBool {
            
            self.address = addressParser.parseAddress(url: url).address
            self.amount = "\(addressParser.parseAddress(url: url).amount)"
            
            DispatchQueue.main.async {
                
                self.addressInput.resignFirstResponder()
                self.amountInput.resignFirstResponder()
                
                DispatchQueue.main.async {
                    
                    if self.amount != "" && self.amount != "0.0" {
                        
                        self.amountInput.text = self.amount
                        
                    }
                    
                    self.addressInput.text = self.address
                    
                }
                
                self.back()
                
            }
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: errorDescription)
            
        }
        
    }
    
    enum error: Error {
        
        case noCameraAvailable
        case videoInputInitFail
        
    }
    
    func processKeys(key: String) {
        
        self.processBIP21(url: key)
        
    }
    
    private func broadcastNow() {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "Broadcast with your node?", message: "You can optionally broadcast this transaction using Blockstream's esplora API over Tor V3 for improved privacy.", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Privately", style: .default, handler: { action in
                vc.creatingView.addConnectingView(vc: vc, description: "broadcasting...")
                Broadcaster.sharedInstance.send(rawTx: vc.rawTxSigned) { [unowned vc = self] (txid) in
                    if txid != nil {
                        DispatchQueue.main.async { [unowned vc = self] in
                            vc.rawDisplayer.rawString = txid!
                            vc.rawDisplayer.textView.text = "txid: " + txid!
                            vc.rawDisplayer.qrView.image = vc.rawDisplayer.generateQrCode(key: txid!)
                            vc.navigationController?.navigationBar.topItem?.title = "Transaction ID"
                            vc.creatingView.removeConnectingView()
                            displayAlert(viewController: vc, isError: false, message: "Transaction Sent ✓")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                            }
                        }
                    } else {
                        vc.creatingView.removeConnectingView()
                        displayAlert(viewController: vc, isError: true, message: "error broadcasting")
                    }
                }
            }))
            alert.addAction(UIAlertAction(title: "Use my node", style: .default, handler: { [unowned vc = self] action in
                vc.creatingView.addConnectingView(vc: vc, description: "broadcasting...")
                Reducer.makeCommand(command: .sendrawtransaction, param: "\"\(vc.rawTxSigned)\"") { (response, errorMesage) in
                    if let txid = response as? String {
                        DispatchQueue.main.async { [unowned vc = self] in
                            vc.navigationController?.navigationBar.topItem?.title = "Transaction ID"
                            vc.rawDisplayer.rawString = txid
                            vc.rawDisplayer.textView.text = "txid: " + txid
                            vc.rawDisplayer.qrView.image = vc.rawDisplayer.generateQrCode(key: txid)
                            vc.creatingView.removeConnectingView()
                            displayAlert(viewController: vc, isError: false, message: "Transaction sent ✓")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                            }
                        }
                    } else {
                        displayAlert(viewController: vc, isError: true, message: "Error: \(errorMesage ?? "")")
                    }
                }
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true) {}
        }
    }
    
    func getRawTx() {
        CreatePSBT.create(outputs: outputsString) { [unowned vc = self] (psbt, rawTx, errorMessage) in
            if psbt != nil {
                vc.rawTxSigned = psbt!
                vc.creatingView.removeConnectingView()
                vc.showRaw(raw: psbt!)
                DispatchQueue.main.async {
                    vc.removeViews()
                    vc.navigationController?.navigationBar.topItem?.title = "PSBT"
                    vc.tapTextViewGesture = UITapGestureRecognizer(target: self, action: #selector(vc.sharePSBT(_:)))
                    vc.rawDisplayer.textView.addGestureRecognizer(vc.tapTextViewGesture)
                    vc.exportPsbt()
                }
            } else if rawTx != nil {
                vc.rawTxSigned = rawTx!
                vc.creatingView.removeConnectingView()
                vc.showRaw(raw: rawTx!)
                DispatchQueue.main.async {
                    vc.removeViews()
                    vc.navigationController?.navigationBar.topItem?.title = "Signed Tx"
                    vc.tapTextViewGesture = UITapGestureRecognizer(target: self, action: #selector(vc.shareRawText(_:)))
                    vc.rawDisplayer.textView.addGestureRecognizer(vc.tapTextViewGesture)
                }
                vc.broadcastNow()
                
            } else if errorMessage != nil {
                vc.creatingView.removeConnectingView()
                showAlert(vc: vc, title: "Error", message: errorMessage!)
            }
        }
    }
    
    private func exportPsbt() {
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.rawDisplayer.textView.alpha = 0
                
            }) { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    self.rawDisplayer.textView.alpha = 1
                    
                })
                
            }
            
            let alert = UIAlertController(title: "Share as raw data or text?", message: "Sharing as raw data allows you to send the unsigned psbt directly to your Coldcard Wallets SD card for signing or to Electrum 4.0", preferredStyle: .actionSheet)
            
            alert.addAction(UIAlertAction(title: "Raw Data", style: .default, handler: { action in
                
                self.convertPSBTtoData(string: self.rawTxSigned)
                
            }))
            
            alert.addAction(UIAlertAction(title: "Text", style: .default, handler: { action in
                
                DispatchQueue.main.async {
                    
                    let textToShare = [self.rawTxSigned]
                    
                    let activityViewController = UIActivityViewController(activityItems: textToShare,
                                                                          applicationActivities: nil)
                    
                    activityViewController.popoverPresentationController?.sourceView = self.view
                    self.present(activityViewController, animated: true) {}
                    
                }
                
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
                
            }))
            
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true) {}
            
        }
    }
    
    @objc func sharePSBT(_ sender: UITapGestureRecognizer) {
        exportPsbt()
    }
    
    private func convertPSBTtoData(string: String) {
        if let data = Data(base64Encoded: string) {
            if let url = exportPsbtToURL(data: data) {
                DispatchQueue.main.async { [unowned vc = self] in
                    let activityViewController = UIActivityViewController(activityItems: ["Fully Noded PSBT", url], applicationActivities: nil)
                    activityViewController.popoverPresentationController?.sourceView = vc.view
                    vc.present(activityViewController, animated: true) {}
                }
            }
        }
    }
    
    //MARK: Node Commands
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        
        if textField == addressInput {
            
            if textField.text != "" {
                
                textField.becomeFirstResponder()
                
            } else {
                
                if let string = UIPasteboard.general.string {
                    
                    textField.becomeFirstResponder()
                    textField.text = string
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        textField.resignFirstResponder()
                        self.processKeys(key: string)
                    }
                    
                    
                } else {
                    
                    textField.becomeFirstResponder()
                    
                }
                
            }
            
        }
        
    }
    
}

extension String {
    func toDouble() -> Double? {
        return NumberFormatter().number(from: self)?.doubleValue
    }
}



