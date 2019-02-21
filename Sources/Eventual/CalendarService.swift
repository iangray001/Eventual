//
//  service.swift
//  Eventual
//
//  Created by Ian Gray on 27/12/2018.
//

import Foundation
import EventKit

class CalendarService : Service {
	let type: ServiceType = .Calendar
	
	
	let uuids : [String]
	let calendarNames : [String]
	let calendarSymbols : String
	let lookaheadHours : Int
	let updateInterval : Int
	let carriageReturns : Bool
	let maxEventLength : Int
	let daySeparators : Bool
	
	let eventStore = EKEventStore()
	var updateTimer : Timer?
	var events : [EKEvent]?
	let targetCalendars : [EKCalendar]?
	
	
	static var allInstances : [CalendarService] = []
	
	//This is the main update function, called from EventKit and the Timer
	class func updateAllInstances() {
		for c in allInstances {
			c.getNextEvents()
		}
	}
	
	
	/**
	Create the service by checking we can use the event store, registering an EventKit notification,
	creating an update timer to ping us back every updateInterval seconds, and making an initial call
	to getNextEvents()
	*/
	init(
		uuids : [String],
		calendarNames : [String],
		calendarSymbols : String,
		lookaheadHours : Int,
		updateInterval : Int,
		carriageReturns : Bool,
		maxEventLength : Int,
		daySeparators : Bool
	) {
		self.uuids = uuids
		self.calendarNames = calendarNames
		self.calendarSymbols = calendarSymbols
		self.lookaheadHours = lookaheadHours
		self.updateInterval = updateInterval
		self.carriageReturns = carriageReturns
		self.maxEventLength = maxEventLength
		self.daySeparators = daySeparators
		
		//Ensure we are authorised to use EventKit
		while(EKEventStore.authorizationStatus(for: EKEntityType.event) != EKAuthorizationStatus.authorized) {
			print("You must allow Eventual to access your calendar events in order for it to show them to you.")
			eventStore.requestAccess(to: .event, completion: {
				(success, error) -> Void in
				print("Got permission = \(success); error = \(String(describing: error))")
			})
			sleep(1);
		}

		//Grab the actual calendar objects
		targetCalendars = eventStore.calendars(for: EKEntityType.event).filter { (x) -> Bool in calendarNames.contains(x.title) }

		//Create an update timer to refresh the widgets every updateInterval
		updateTimer = Timer.scheduledTimer(withTimeInterval: Double(updateInterval), repeats: true) { timer in
			CalendarService.updateAllInstances()
		}
		
		//Add a notification to update us when the Event Store changes
		NotificationCenter.default.addObserver(
			forName: NSNotification.Name.EKEventStoreChanged,
			object: nil,
			queue: OperationQueue.main) {(note) in CalendarService.updateAllInstances()}
		
		CalendarService.allInstances.append(self)
		
		getNextEvents()
	}
	
	/**
	Update the events array from the EventStore, then call updateText()
	*/
	func getNextEvents() {
		events = eventStore.events(matching: eventStore.predicateForEvents(
			withStart: Date.init(),
			end: Date.init(timeIntervalSinceNow: Double(lookaheadHours) * 60*60), //Convert to seconds
			calendars: targetCalendars))
		updateText()
	}
	
	
	/**
	Find out if we have a calendarSymbol for the event's calendar
	*/
	func calendarSymbolForCalendar(_ calTitle : String) -> String {
		for t in 0..<calendarNames.count {
			if calendarNames[t] == calTitle {
				if calendarSymbols.count > t {
					let index = calendarSymbols.index(calendarSymbols.startIndex, offsetBy: t)
					return String(calendarSymbols[index]) + " "
				}
			}
		}
		return ""
	}
	
	/**
	Pretty print the events to BetterTouchTool
	*/
	func updateText() {
		var eventnum = 0
		var uuidnum = 0
		var currentDoW = Calendar.current.dateComponents([.weekday], from: Date.init()).weekday!

		if let evs = events {
			while true {
				var output = ""

				if uuidnum >= uuids.count {
					return
				}
				
				if eventnum >= evs.count {
					output = uuidnum == 0 ? "No calendar events" : ""
				} else {
					if daySeparators && evs[eventnum].dayOfWeek() != nil && evs[eventnum].dayOfWeek()! > currentDoW {
						currentDoW = evs[eventnum].dayOfWeek()!
						output = "●"
					} else {
						output = output + calendarSymbolForCalendar(evs[eventnum].calendar!.title)
						output = output + evs[eventnum].toPrettyString(maxlen: maxEventLength, twoLines: carriageReturns)
						eventnum = eventnum + 1
					}
				}

				//addingPercentEncoding doesn't replace &, but this will cause issues when used as a GET request
				var text = output.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
				//so manually encode it
				text = text.replacingOccurrences(of: "&", with: "%26")
				
				//Data prepared, send it over via a GET request
				BTT.updateTouchBarWidget(uuid : uuids[uuidnum],
										 text : text,
										 icon_data : nil)
				
				uuidnum = uuidnum + 1
			}
		}
	}
}




