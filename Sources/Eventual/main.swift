//
//  main.swift
//  Eventual
//
//  Created by Ian Gray on 21/12/2018.
//  Copyright © 2018 Ian Gray. All rights reserved.
//

import Foundation

//All services conform to this protocol
protocol Service {
	var type : ServiceType { get }
}

enum ServiceType {
	case Calendar
	case Audio
	case Bluetooth
}

var services : [Service] = []


//Use the output of ps to count how many processes are named ourname
func countRunningCopies(_ ourname : String) -> Int {
	let task = Process()
	task.launchPath = "/bin/ps"
	task.arguments = ["-c", "-o", "command="]
	let pipe = Pipe()
	task.standardOutput = pipe
	task.launch()
	let data = pipe.fileHandleForReading.readDataToEndOfFile()
	let output = String(data: data, encoding: String.Encoding.utf8)!
	
	var count = 0
	for line in output.components(separatedBy: "\n") {
		if line.trimmingCharacters(in: NSCharacterSet.whitespaces) == "Eventual" {
			count = count + 1
		}
	}
	return count
}

//If we are already running elsewhere (so countRunningCopies will return at least 2) then quit
if countRunningCopies("Eventual") > 1 {
	exit(0)
}

//Check command line arguments
if CommandLine.argc != 2 {
	print("Usage: " + (CommandLine.arguments[0] as NSString).lastPathComponent + " <path to config>")
	exit(1)
}
if !FileManager.default.fileExists(atPath: CommandLine.arguments[1]) {
	print("File " + CommandLine.arguments[1] + " does not exist.")
	exit(1)
}

//Set up the requested service(s) and sit in the event loop
let config = ConfigFile.loadFile(CommandLine.arguments[1])
BTT.bttSecret = config.bttSecret
BTT.bttServername = config.bttServerName

for service in config.services {
	switch service.type {
	case "calendar":
		services.append(
			CalendarService(
				uuids: service.uuids,
				calendarNames: service.calendarNames!.components(separatedBy: ","),
				calendarSymbols: service.calendarSymbols ?? "◎●○◉⦿",
				lookaheadHours: service.lookaheadHours ?? 48,
				updateInterval: service.updateInterval ?? 40,
				carriageReturns: service.carriageReturns ?? false,
				maxEventLength: service.maxEventLength ?? 30,
				daySeparators: service.daySeparators ?? false)
		)
	case "audio":
		services.append(AudioService(uuid: service.uuids[0]))
	case "bluetooth":
		services.append(BluetoothService(
			deviceName: service.deviceName!, //Cannot be nil. Validated.
			uuid: service.uuids[0],
			variableName: service.variableName!))  //Cannot be nil. Validated.
	default:
		//Shouldn't happen. Validated.
		exit(1)
	}
}

//Tell BTT our PID so it knows we are alive
let pid = ProcessInfo.processInfo.processIdentifier
BTT.setPersistentStringVariable(varName: "eventualpid", to: String(pid)) { (e) in
	print("Error sending PID to BetterTouchTool: " + e.localizedDescription)
	exit(1)
}

//Enter a non-terminating run loop so that we can receive framework callbacks
while (true) {
	RunLoop.current.run(mode: RunLoop.Mode.default, before: Date.distantFuture)
}
