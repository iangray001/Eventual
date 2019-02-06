//
//  datetimeextensions.swift
//  Eventual
//
//  Created by Ian Gray on 22/12/2018.
//  Copyright © 2018 Ian Gray. All rights reserved.
//

import Foundation
import EventKit

/**
	A set of convenience extensions for time intervals that format them as time in hours and minutes.
 */
extension TimeInterval {
	
	func asHoursStr() -> String {
		let val = Float(self) / 3600.0
		return String(format: "%.1f", val) + " hrs"
	}
	
	func asMins() -> Int {
		return Int(self) / 60
	}
	
	func asMinsStr() -> String {
		let val = Int(self) / 60
		return String(val) + " min" + (val == 1 ? "" : "s")
	}
	
	func asTimeStr() -> String {
		if self.asMins() < 60 {
			return self.asMinsStr()
		} else {
			return self.asHoursStr();
		}
	}
}


public extension EKEvent {
	
	/**
	This is the main formatting for an event. It formats an event's title and start/end time according to the following cases:
		If the start time is in the past, then it is formatted as: <title> ending in X mins
		If the start time is in the future then either: <title> in X mins or <title> in X.Y hrs
		If the next day, then: <title> HH:MM tmrw
		If further in the future: <title> HH:MM EEE (i.e. Mon, Tue, etc.)
	*/
	func toPrettyString(maxlen : Int, twoLines : Bool) -> String {
		if let evst = self.startDate {
			var title = self.title!

			if maxlen > 0 && title.count > maxlen {
				title = title.prefix(maxlen) + "..."
			}
			
			title += twoLines ? "\n" : " "
			
			if evst.timeIntervalSinceNow.asMins() < 0 {
				//Event is currently going
				if self.isAllDay {
					return title + "today"
				} else {
					if let even = self.endDate {
						if even > Date.init() {
							return title + "ending in " + even.timeIntervalSinceNow.asTimeStr()
						} else {
							return title + "ended."
						}
					} else {
						return title + "<no end date>"
					}
				}
			} else {
				//Event is in the future
				if Calendar.current.isDateInToday(evst) {
					if self.isAllDay {
						return title + "today"
					} else {
						if evst.timeIntervalSinceNow.asMins() < 60 {
							return title + "in " + evst.timeIntervalSinceNow.asMinsStr()
						} else {
							let df = DateFormatter()
							df.dateFormat = "HH:mm"
							return title + "at " + df.string(from: evst)
						}
						
					}
				} else if Calendar.current.isDateInTomorrow(evst) {
					if self.isAllDay {
						return title + "tmrw"
					} else {
						let df = DateFormatter()
						df.dateFormat = "HH:mm"
						return title + df.string(from: evst) + " tmrw"
					}
				} else {
					if self.isAllDay {
						let df = DateFormatter()
						df.dateFormat = "EEE"
						return title + df.string(from: evst)
					} else {
						let df = DateFormatter()
						df.dateFormat = "HH:mm EEE"
						return title + df.string(from: evst)
					}
				}
			}
		} else {
			return title + "<no start date>"
		}
	}
	
	
	func dayOfWeek() -> Int? {
		if let sd = self.startDate {
			return Calendar.current.dateComponents([.weekday], from: sd).weekday
		}
		return nil
	}
}

