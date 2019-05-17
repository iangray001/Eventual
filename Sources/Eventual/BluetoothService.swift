//
//  BluetoothService.swift
//  Eventual
//
//  Created by Ian Gray on 31/12/2018.
//

import Foundation
import IOBluetooth

class BluetoothService : Service {
	let type: ServiceType = .Bluetooth
	
	
	//The devices to look for. Format is:
	//    deviceName -> (UUID of BTT widget to update, name of BTT persistent variable to update for this device)
	//When deviceName connects, the variable is set to "yes" and the widget uuid is refreshed
	var devices : Dictionary<String, (String, String)> = [:]
	
	
	func error(e : Error) {
		print("Error sending bluetooth state to BetterTouchTool: " + e.localizedDescription)
	}

	//Called when any Bluetooth device connects
	@objc func connectCallback(iob : IOBluetoothUserNotification, device : IOBluetoothDevice) {
		if device.name != nil && devices[device.name] != nil  {
			let (uuid, variableName) = devices[device.name]!
			
			//Tell us when this device disconnects
			device.register(forDisconnectNotification: self, selector: #selector(disconnectCallback))
			
			//Update BTT
			BTT.setPersistentStringVariable(varName: variableName, to: "yes", onError: error)
			BTT.refreshWidget(uuid: uuid)
		}
	}
	
	//Called when any Bluetooth device disconnects
	@objc func disconnectCallback(iob : IOBluetoothUserNotification, device : IOBluetoothDevice) {
		if device.name != nil && devices[device.name] != nil  {
			let (uuid, variableName) = devices[device.name]!
			
			BTT.setPersistentStringVariable(varName: variableName, to: "no", onError: error)
			BTT.refreshWidget(uuid: uuid)
		}
	}
	
	func addDevice(name: String, uuid: String, variableName: String) {
		devices[name] = (uuid, variableName)
		updateAllDevices()
	}
	
	func updateAllDevices() {
		for (devName, (uuid, variableName)) in devices {
			BTT.setPersistentStringVariable(varName: variableName, to: (deviceIsConnected(devName) ? "yes" : "no"), onError: error)
			BTT.refreshWidget(uuid: uuid)
		}
	}
	
	//Is the named Bluetooth device currently connected?
	func deviceIsConnected(_ name: String) -> Bool {
		guard let btdevices = IOBluetoothDevice.pairedDevices() else {
			return false
		}
		for item in btdevices {
			if let device = item as? IOBluetoothDevice {
				if device.name != nil && devices[device.name] != nil {
					return device.isConnected()
				}
			}
		}
		return false
	}
	
	
	init(deviceName : String, uuid : String, variableName : String) {
		addDevice(name: deviceName, uuid: uuid, variableName: variableName)
		
		//Register for all bluetooth device connections
		IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(connectCallback))
	}
}

