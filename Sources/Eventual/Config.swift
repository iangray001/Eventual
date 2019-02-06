//
//  config.swift
//  Eventual
//
//  Created by Ian Gray on 06/01/2019.
//

import Foundation

class ConfigFile : Decodable {
	var services : [ServiceConf]
	
	var bttServerName : String
	var bttSecret : String
	
	
	func validate() -> String? {
		if self.services.count == 0 {
			return "No services defined in config file."
		}
		for s in self.services {
			switch s.type {
			case "calendar":
				if s.calendarNames == nil {
					return "Required parameter calendarNames is not set."
				}
			case "audio":
			break //nothing to check
			case "bluetooth":
				if s.deviceName == nil || s.variableName == nil {
					return "Bluetooth service requires 'deviceName' and 'variableName' to be set."
				}
			default:
				return "Unknown service type " + s.type + " in config file."
			}
		}
		return nil
	}
	
	class func loadFile(_ fileName : String) -> ConfigFile {
		let fileContent = try? Data(contentsOf: URL(fileURLWithPath: fileName))
		
		if fileContent == nil {
			print("Cannot load config file " + fileName)
			exit(1)
		}
		let configData = fileContent!
		
		guard let config = try? JSONDecoder().decode(ConfigFile.self, from: configData) else {
			print("Couldn't decode config file " + fileName)
			exit(1)
		}
		
		let err = config.validate()
		if let e = err {
			print(e)
			exit(1)
		}
		
		return config
	}
}


class ServiceConf : Decodable {
	//All
	let type : String //calendar, audio, bluetooth
	let uuids : [String]
	
	//Calendar
	let calendarNames : String?
	var calendarSymbols : String?
	var lookaheadHours : Int?
	var updateInterval : Int?
	var maxNumEvents : Int?
	var carriageReturns : Bool?
	var maxEventLength : Int?
	var daySeparators : Bool?
	
	//Bluetooth
	var deviceName : String?
	var variableName : String?
	
	//Audio
	//none yet
}




