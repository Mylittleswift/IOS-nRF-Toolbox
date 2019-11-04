//
//  HTSViewController.swift
//  nRF Toolbox
//
//  Created by Mostafa Berg on 09/05/16.
//  Copyright © 2016 Nordic Semiconductor. All rights reserved.
//

import UIKit
import CoreBluetooth

class HTSViewController: BaseViewController, CBCentralManagerDelegate, CBPeripheralDelegate, ScannerDelegate {

    //MARK: - ViewController properties
    var bluetoothManager                 : CBCentralManager?
    var connectedPeripheral              : CBPeripheral?
    var htsServiceUUID                   : CBUUID
    var htsMeasurementCharacteristicUUID : CBUUID
    var batteryServiceUUID               : CBUUID
    var batteryLevelCharacteristicUUID   : CBUUID
    var temperatureValueFahrenheit       : Bool?
    var temperatureValue                 : Double?

    //MARK: - ViewController outlets
    @IBOutlet weak var type: UILabel!
    @IBOutlet weak var timestamp: UILabel!
    @IBOutlet weak var connectionButon: UIButton!
    @IBOutlet weak var temperatureUnit: UILabel!
    @IBOutlet weak var temperature: UILabel!
    @IBOutlet weak var deviceName: UILabel!
    @IBOutlet weak var battery: UIButton!
    @IBOutlet weak var verticalLabel: UILabel!
    @IBOutlet weak var degreeControl: UISegmentedControl!
   
    //MARK: - ViewControllerActions
    @IBAction func aboutButtonTapped(_ sender: AnyObject) {
        self.showAbout(message: AppUtilities.getHelpTextForService(service: .htm))
    }
    
    @IBAction func connectionButtonTapped(_ sender: AnyObject) {
        if connectedPeripheral != nil {
            bluetoothManager?.cancelPeripheralConnection(connectedPeripheral!)
        }
    }
    
    @IBAction func degreeHasChanged(_ sender: AnyObject) {
        let control = sender as! UISegmentedControl
        if (control.selectedSegmentIndex == 0) {
            // Celsius
            temperatureValueFahrenheit = false
            UserDefaults.standard.set(false, forKey: "fahrenheit")
            self.temperatureUnit.text = "°C"
            if temperatureValue != nil {
                temperatureValue = (temperatureValue! - 32.0) * 5.0 / 9.0
            }
        } else {
            // Fahrenheit
            temperatureValueFahrenheit = true
            UserDefaults.standard.set(true, forKey: "fahrenheit")
            self.temperatureUnit.text = "°F"
            if temperatureValue != nil {
                temperatureValue = temperatureValue! * 9.0 / 5.0 + 32.0
            }
        }
        
        UserDefaults.standard.synchronize()
        
        if temperatureValue != nil {
            self.temperature.text = String(format:"%.2f", temperatureValue!)
        }
    }

    //MARK: - Segue handling
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        // The 'scan' seque will be performed only if connectedPeripheral == nil (if we are not connected already).
        return identifier != "scan" || connectedPeripheral == nil
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "scan" {
            // Set this contoller as scanner delegate
            let navigationController = segue.destination as! UINavigationController
            let scannerController    = navigationController.children.first as! ScannerViewController
            scannerController.filterUUID = htsServiceUUID
            scannerController.delegate = self
        }
    }

    //MARK: - UIViewControllerDelegate
    required init?(coder aDecoder: NSCoder) {
        // Custom initialization
        htsServiceUUID                   = CBUUID(string: ServiceIdentifiers.htsServiceUUIDString)
        htsMeasurementCharacteristicUUID = CBUUID(string: ServiceIdentifiers.htsMeasurementCharacteristicUUIDString)
        batteryServiceUUID               = CBUUID(string: ServiceIdentifiers.batteryServiceUUIDString)
        batteryLevelCharacteristicUUID   = CBUUID(string: ServiceIdentifiers.batteryLevelCharacteristicUUIDString)
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.verticalLabel.transform = CGAffineTransform(translationX: -(verticalLabel.frame.width/2) + (verticalLabel.frame.height / 2), y: 0.0).rotated(by: -.pi / 2)
        self.updateUnits()
    }

    //MARK: - CBPeripheralDelegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("An error occured while discovering services: \(error!.localizedDescription)")
            bluetoothManager!.cancelPeripheralConnection(peripheral)
            return;
        }
        
        for aService : CBService in peripheral.services! {
            // Discovers the characteristics for a given service
            if aService.uuid == htsServiceUUID {
                peripheral.discoverCharacteristics([htsMeasurementCharacteristicUUID], for: aService)
            }else if aService.uuid == batteryServiceUUID {
               peripheral.discoverCharacteristics([batteryLevelCharacteristicUUID], for: aService)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("Error occurred while discovering characteristic: \(error!.localizedDescription)")
            bluetoothManager!.cancelPeripheralConnection(peripheral)
            return
        }
        
        // Characteristics for one of those services has been found
        if service.uuid == htsServiceUUID {
            for aCharacteristic : CBCharacteristic in service.characteristics! {
                if aCharacteristic.uuid == htsMeasurementCharacteristicUUID {
                    // Enable notification on data characteristic
                    peripheral.setNotifyValue(true, for: aCharacteristic)
                    break
                }
            }
        } else if service.uuid == batteryServiceUUID {
            for aCharacteristic : CBCharacteristic in service.characteristics! {
                if aCharacteristic.uuid == batteryLevelCharacteristicUUID {
                    peripheral.readValue(for: aCharacteristic)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error occurred while updating characteristic value: \(error!.localizedDescription)")
            return
        }
        
        // Scanner uses other queue to send events. We must edit UI in the main queue
        DispatchQueue.main.async {
            // Decode the characteristic data
            let data = characteristic.value
            var array = UnsafeMutablePointer<UInt8>(OpaquePointer(((data as NSData?)?.bytes)!))
            
            if characteristic.uuid == self.batteryLevelCharacteristicUUID {
                let batteryLevel = CharacteristicReader.readUInt8Value(ptr: &array)
                
                let text = "\(batteryLevel)%"
                self.battery.setTitle(text, for: .disabled)
                
                if self.battery.tag == 0 {
                    // If battery level notifications are available, enable them
                    if characteristic.properties.rawValue & CBCharacteristicProperties.notify.rawValue > 0 {
                        self.battery.tag = 1; // mark that we have enabled notifications
                        
                        // Enable notification on data characteristic
                        peripheral.setNotifyValue(true, for: characteristic)
                    }
                }
            } else if characteristic.uuid == self.htsMeasurementCharacteristicUUID {
                let flags = CharacteristicReader.readUInt8Value(ptr: &array)
                let tempInFahrenheit : Bool = (flags & 0x01) > 0
                let timestampPresent : Bool = (flags & 0x02) > 0
                let typePresent      : Bool = (flags & 0x04) > 0
                
                var tempValue        : Float = CharacteristicReader.readFloatValue(ptr: &array)
                if tempInFahrenheit == false && self.temperatureValueFahrenheit! == true {
                    tempValue = tempValue * 9.0 / 5.0 + 32.0
                }
                if tempInFahrenheit == true && self.temperatureValueFahrenheit == false {
                    tempValue = (tempValue - 32.0) * 5.0 / 9.0
                }
                
                self.temperatureValue = Double(tempValue)
                self.temperature.text = String(format: "%.2f", tempValue)
                
                if timestampPresent == true {
                    let date = CharacteristicReader.readDateTime(ptr: &array)
                    let dateFormat = DateFormatter()
                    dateFormat.dateFormat = "dd.MM.yyyy, hh:mm"
                    
                    let dateFormattedString = dateFormat.string(from: date)
                    self.timestamp.text = dateFormattedString
                } else {
                    self.timestamp.text = "Date n/a"
                }
                
                /* temperature type */
                if typePresent == true {
                    let type = CharacteristicReader.readUInt8Value(ptr: &array)
                    var location: NSString = ""
                    
                    switch type {
                    case 0x01:
                        location = "Armpit"
                    case 0x02:
                        location = "Body - general"
                    case 0x03:
                        location = "Ear"
                    case 0x04:
                        location = "Finger"
                    case 0x05:
                        location = "Gastro-intenstinal Tract"
                    case 0x06:
                        location = "Mouth"
                    case 0x07:
                        location = "Rectum"
                    case 0x08:
                        location = "Toe"
                    case 0x09:
                        location = "Tympanum - ear drum"
                    default:
                        location = "Unknown"
                    }
                    self.type.text = "Location: \(location)"
                } else {
                    self.type.text = "Location: N/A";
                }
                
                if  AppUtilities.isApplicationInactive() {
                    var message : String = ""
                    if let fahrenheit = self.temperatureValueFahrenheit, fahrenheit {
                        message = String(format:"New temperature reading: %.2f°F", tempValue)
                    } else {
                        message = String(format:"New temperature reading: %.2f°C", tempValue)
                    }
                    
                    AppUtilities.showBackgroundNotification(message: message)
                }
            }
            }
    }
    //MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOff {
            print("Bluetooth powered off")
        } else {
            print("Bluetooth powered on")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Scanner uses other queue to send events. We must edit UI in the main queue
        DispatchQueue.main.async {
            self.deviceName.text = peripheral.name
            self.connectionButon.setTitle("DISCONNECT", for: .normal)

            NotificationCenter.default.addObserver(self, selector: #selector(self.appDidEnterBackrgoundCallback), name: UIApplication.didEnterBackgroundNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.appDidBecomeActiveCallback), name: UIApplication.didBecomeActiveNotification, object: nil)
        }

        // Peripheral has connected. Discover required services
        connectedPeripheral = peripheral;
        peripheral.discoverServices([htsServiceUUID, batteryServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // Scanner uses other queue to send events. We must edit UI in the main queue
        DispatchQueue.main.async {
            AppUtilities.showAlert(title: "Error", andMessage: "Connecting to peripheral failed. Try again", from: self)
            self.connectionButon.setTitle("CONNECT", for: .normal)
            self.connectedPeripheral = nil
            self.clearUI()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // Scanner uses other queue to send events. We must edit UI in the main queue
        DispatchQueue.main.async {
            self.connectionButon.setTitle("CONNECT", for: .normal)
            if AppUtilities.isApplicationInactive() {
                let name = peripheral.name ?? "Peripheral"
                AppUtilities.showBackgroundNotification(message: "\(name) is disconnected.")
            }
            self.connectedPeripheral = nil
            self.clearUI()
            NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        }
    }
    
    //MARK: - ScannerDelegate
    func centralManagerDidSelectPeripheral(withManager aManager: CBCentralManager, andPeripheral aPeripheral: CBPeripheral) {
        // We may not use more than one Central Manager instance. Let's just take the one returned from Scanner View Controller
        bluetoothManager = aManager
        bluetoothManager!.delegate = self
        
        // The sensor has been selected, connect to it
        connectedPeripheral = aPeripheral
        connectedPeripheral?.delegate = self

        let options = [CBConnectPeripheralOptionNotifyOnNotificationKey : NSNumber(value: true as Bool)]
        bluetoothManager!.connect(aPeripheral, options: options)
    }
    
    //MARK: - HTSViewController implementation
    func updateUnits() {
        temperatureValueFahrenheit = UserDefaults.standard.bool(forKey: "fahrenheit")
        if temperatureValueFahrenheit == true {
            degreeControl.selectedSegmentIndex = 1
            self.temperatureUnit.text = "°F"
        } else {
            degreeControl.selectedSegmentIndex = 0
            self.temperatureUnit.text = "°C"
        }
    }
    
    @objc func appDidEnterBackrgoundCallback() {
        let name = connectedPeripheral?.name ?? "peripheral"
        AppUtilities.showBackgroundNotification(message: "You are still connected to \(name). It will collect data also in background.")
    }
    
    @objc func appDidBecomeActiveCallback() {
        UIApplication.shared.cancelAllLocalNotifications()
        self.updateUnits()
    }
    
    func clearUI() {
        deviceName.text = "DEFAULT HTM"
        battery.tag = 0
        battery.setTitle("n/a", for: .disabled)
        self.temperature.text = "-"
        self.timestamp.text = ""
        self.type.text = ""
    }
}
