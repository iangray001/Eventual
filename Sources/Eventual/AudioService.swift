//
//  AudioService.swift
//  Eventual
//
//  Created by Ian Gray on 27/12/2018.
//

import Foundation
import CoreAudio


//These trampolines have to be top level funcs to allow them to be passed to C
//They cast the userData pointer, which is a reference to 'self' in order to call the appropriate instance method

func volumeChangeTrampoline(devId : UInt32, numAopas : UInt32, aopa : UnsafePointer<AudioObjectPropertyAddress>, userData : Optional<UnsafeMutableRawPointer>) -> Int32 {
	if let obs = userData {
		let mySelf = Unmanaged<AudioService>.fromOpaque(obs).takeUnretainedValue()
		mySelf.onVolumeChanged()
		return 0
	}
	return 1
}

func deviceChangeTrampoline(devId : UInt32, numAopas : UInt32, aopa : UnsafePointer<AudioObjectPropertyAddress>, userData : Optional<UnsafeMutableRawPointer>) -> Int32 {
	if let obs = userData {
		let mySelf = Unmanaged<AudioService>.fromOpaque(obs).takeUnretainedValue()
		return mySelf.onDefaultOutputDeviceChanged(devId: devId, numAopas: numAopas, aopa: aopa, userData: userData)
	}
	return 1
}




class AudioService : Service {
	let type: ServiceType = .Audio

	var widgetUUID : String
	
	//CoreAudio data structures
	var outputDeviceAOPA = AudioObjectPropertyAddress(
		mSelector: kAudioHardwarePropertyDefaultOutputDevice,
		mScope: kAudioObjectPropertyScopeGlobal,
		mElement: kAudioObjectPropertyElementMaster)
	
	var volumeAOPA = AudioObjectPropertyAddress(
		mSelector: kAudioDevicePropertyVolumeScalar,
		mScope: kAudioObjectPropertyScopeOutput,
		mElement: 1)
	
	var muteAOPA = AudioObjectPropertyAddress(
		mSelector: kAudioDevicePropertyMute,
		mScope: kAudioObjectPropertyScopeOutput,
		mElement: 1)
	
	var observer : UnsafeMutableRawPointer? = nil
	
	var volume : Float32 = 0.5
	var mute : UInt32 = 0
	var outputDeviceID : UInt32 = kAudioObjectUnknown
	
	var volSize : UInt32
	var muteSize : UInt32
	var outputDevicePropertySize : UInt32
	
	var lastKey : String? = nil
	
	
	init(uuid: String) {
		self.widgetUUID = uuid
		
		//A few size lookups are needed first
		volSize = UInt32(MemoryLayout.size(ofValue: volume))
		outputDevicePropertySize = UInt32(MemoryLayout.size(ofValue: outputDeviceID))
		muteSize =  UInt32(MemoryLayout.size(ofValue: mute))
		
		//Store a pointer to this instance which gets passed into the trampoline functions to allow it to call us back. yuk.
		observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
		
		//Attach a device change listener
		AudioObjectAddPropertyListener(UInt32(kAudioObjectSystemObject), &outputDeviceAOPA, deviceChangeTrampoline, observer)
		
		//Update outputDeviceID to contain the current output device
		AudioObjectGetPropertyData(UInt32(kAudioObjectSystemObject), &outputDeviceAOPA, 0, nil, &outputDevicePropertySize, &outputDeviceID)
		
		//Attach listeners to that output device
		AudioObjectAddPropertyListener(outputDeviceID, &volumeAOPA, volumeChangeTrampoline, observer)
		AudioObjectAddPropertyListener(outputDeviceID, &muteAOPA, volumeChangeTrampoline, observer)
		
		update()
	}
	
	
	func update() {
		//Determine whether we need to send a new icon to BTT
		var key = "0"
		if volume > 0.65 {
			key = "3"
		} else if volume > 0.32 {
			key = "2"
		} else if volume > 0.05 {
			key = "1"
		}
		if mute > 0 {
			key = "-" + key
		}
		
		if lastKey == nil || lastKey! != key {
			lastKey = key
			var json = "{\"text\":\"Volume\",\"icon_data\": \"" + AudioService.icons[key]! + "\"}"
			json = json.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
			BTT.setPersistentStringVariable(varName: "volstate", to: json) { (e) in
				print("Error updating BTT with volume icon data. " + e.localizedDescription)
			}
			BTT.refreshWidget(uuid: widgetUUID)
		}
	}
	
	
	func onDefaultOutputDeviceChanged(devId : UInt32, numAopas : UInt32,
									  aopa : UnsafePointer<AudioObjectPropertyAddress>,
									  userData : Optional<UnsafeMutableRawPointer>) -> Int32 {
		//Unhook the old listeners and hook new ones
		AudioObjectRemovePropertyListener(outputDeviceID, &volumeAOPA, volumeChangeTrampoline, observer)
		AudioObjectRemovePropertyListener(outputDeviceID, &muteAOPA, volumeChangeTrampoline, observer)
		AudioObjectGetPropertyData(UInt32(kAudioObjectSystemObject), &outputDeviceAOPA, 0, nil, &outputDevicePropertySize, &outputDeviceID)
		AudioObjectAddPropertyListener(outputDeviceID, &volumeAOPA, volumeChangeTrampoline, observer)
		AudioObjectAddPropertyListener(outputDeviceID, &muteAOPA, volumeChangeTrampoline, observer)
		
		update()
		return 0
	}
	
	func onVolumeChanged() {
		AudioObjectGetPropertyData(outputDeviceID, &volumeAOPA, 0, nil, &volSize, &volume)
		AudioObjectGetPropertyData(outputDeviceID, &muteAOPA, 0, nil, &muteSize, &mute)
		update()
	}

	//These are the base64 encoded icons used to represent the volume states
	//Icon data is taken from https://github.com/andrewchidden/btt-controllers/blob/master/control-strip/volume-controller.sh
	static let icons = [
		"3" : "iVBORw0KGgoAAAANSUhEUgAAADwAAAA8CAMAAAANIilAAAAAM1BMVEUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACjBUbJAAAAEXRSTlMAz/9A7xBQj5+/IICv33BgMNi9EfoAAAEoSURBVHgB7ZUBi4QgEIX1jWY7m9X//7UHx/Qgw5s9DwKOPgCC9dPX09zwX3h4iJBxOSHlYXkCShhmxh+C54RX8JGUNFx5e0vbIEhTsy29eOleOMsJNXNWdSKDMmt+27zA6kWmbCzc4QXRi9zKyqU3QJ3IlKOVPqMy9+ZEpnxs7ARMR/NzI224IvbDboUXO2WXc5J6cqgm0VmBRkZXLohnRz6XOVYAPR7kUznbw07nFzLH3iH7sW8prKD6W+Ufktg7JKt3PDlJKNdrTOWb0srVhsoPHwaZUivvljr1P0mi8SRnPS6D4l0G9lKUyUxlsfb70VtZuHDmUz96I1fef2s/NSmtbFWzfS/6HkjWwLok+GQd+aNz3kZGXQGWUZelD8rTiMYS7+Ph4QufIgmRGZQddAAAAABJRU5ErkJggg==",
		"2" : "iVBORw0KGgoAAAANSUhEUgAAADwAAAA8CAYAAAA6/NlyAAABwklEQVR4Ae2aIaz6MBDGT839E/TUFI5kyV/hqlBPLEHhnkLjFd7UK7x6XuHVvKpX9WpvJCcuL498F1bWvvR+yQWxdvBxH+3tCtWNYRiGYRiGYRznOM/RUiV8suDHa0MV0D0Ec+ypEhwLrsbajbD2R2mZiBwdpeV/aVm+zjGJcKRnFHM0WT5QRjZz3IXQVwRHnhP4fpos/8tp4Wmh4EHMu4Isnzl2mS2MBQO+eF4EWT6w4GNuCy8V3CmzvJW2zmNhveARrOA3nhuUtt7mszAWLBenu+K3PCjqa7e0Zp0ShgPv0YMV2wOnLS5C4rsFMwEIugEXPNgJW7/MtJJgz9dH+p2LuMcz2r8k2AFB8nqnENyWLngDxvTgOlO6YAkeY4J/Ypa2Rau8bSnUsS3pC4/x3YXHJX9pib8QZp+qv9XN4Z6ETyA4gLLRrffwoO9MxASCe2DnWMLjoXTB+KLgDc9HDQCfoQEA8Yk7Hje5HSlaPCfKwJCoieeU2W3yH7uwxRcKDsoG3g7YeVV8AsEDGHcC21FWi/eEwIuZZFvqgRp/+PIP00pmX9NxaSvEHqgCTlX95UEI7qgSGt5zDcMwDMMwjGL4BoAv8WBJyctXAAAAAElFTkSuQmCC",
		"1" : "iVBORw0KGgoAAAANSUhEUgAAADwAAAA8CAYAAAA6/NlyAAABrElEQVR4Ae2ZAWbEQBSGBwRYQoGAAQFCWBBgQEBRAgIsWAA9Qm+QI+0RcoQcIUdIZ3l4WjW/ZDbzat7HU2Sor+/vm8nEKIqiKIqiKEreDL7uviqTCTcSfv4sTAZYEn5WZzLBkXA20S5YtN+ldWKlsiYuV2ld/vK1sXKRJzHvcm8SUvp6kOQuYSYykhjS5UvKCG+AMDqJr4Eu36madBEGhAF6vt8C64bUET4qfAG7XPNYp4wwIjwHJrgjkRGMdZ0uwoAw+2M9gP9lC0x1d/TMukUsF/gdbWBid4GkHT6ErK8WJhZ6Ph2QaVgSdrOdJDzR8/mATPWfhB1bE5K5AGsq6cJlYM0bIiNemAOsUeGfaKR1aMnblpY8tiX84DG8+uDxKeRoOQJHyy7W/Zb15f6oKYLwEnh5qM55ecD58LVGEG4Dcb5JeD3kKZh3Cpe+LHAB0Em5AOBMkDCOA0V64JIgScSdwanA7hbguiQRdwZnBC/wGjjOJzBFELbAOmw7ShDx1uAUQMdqqR/UaBLL/5gmmS6nz6V8gvcmA35P8EyErckEmuCKoiiKoiiKHL4BRZ7KNXRjQgYAAAAASUVORK5CYII=",
		"-0" : "iVBORw0KGgoAAAANSUhEUgAAADwAAAA8CAYAAAA6/NlyAAACOUlEQVR4Ae2ZAYb7QBTGB4QihP8fBIxFgVK6UGBAQVECAgQUQI/QG+QIe4Q9wh6hR+gRcoTs4GWNmr5+dl4Y2ffjg90p8+V782aSMcrfRlEURVEURWm8zl61EeLidfWyJk86Mtx5FSaRk9dIGsh8blivM2kv8fTGB31lmLYjwyKl3U9mM067CEr7KPUE7wJpO6+BJF0lO7GUiSox7evD71xqJ2ZSPhgY+bQr+t+YYHgy0pIxJOXSAEinbelvI2oY6MQ7LuVg3Gau7hgz9OlVBVvbkGKYOID77TSuMTNRkcFY2qdwTKLhEkx5LVrWDCc0bcZwQwmWL/bbFixrb57IIG3HNKcjsJYt0NWd9KmLTZIZk1KOHXCMdOmHkIgBKEl+TIyWMYSa2fw8uAR4s3Jp75kui5qp5Q3Lpe34ybJmSmBMLW8YT/vyJO0+GLPy6pjJ/kPMiBtOSNs+OWrep7QpuSMz2ewNT/pA0mZKNX/DTJJo2vmXNKitIcC1nXvT4hUmiKSd2baUbhhMe+Ldq5n74HERN8xP+Bb5zS1YChx7qe9bliYaUy9guKXJrqKfhUj0dyP/8iD3iggbjjSjLZ62/OshWgW3XxoumM6Lpo1/ABCmBwzj4Gn/92r5pjZ3iacbrqkzo2kXKfuvbIkDhpm1fYDTzoBewLDN+yqIL3E+Bb6ZyV8FzUglPwngcmBhrL1KIO1FUAc3Em8v0nZmAbTMFUyY9uBVLcmwZda2W4jZoINnhKIoiqIoivINDkAfAMyszHAAAAAASUVORK5CYII=",
		"0" : "iVBORw0KGgoAAAANSUhEUgAAADwAAAA8CAYAAAA6/NlyAAABpElEQVR4Ae2ZAYYDMRiFBwQYSoEBAwqUpWCAgAHFMiBAQQHsEfYGPdIeYY/SI8ymBGGt9zTTJDbv47fYQb7+z59MpmsbIYQQQgghFl9XX0MrwpeHcPhrWhAeH8Khpq4RbBBuJtomiva5tk7cQ43dtpxq6/KnrzUqmzKJQZfnkqI7X19BEgqDSeyCGNPlvmSEV14YTuIT6PI11LFwhIEwZo73W+K5pXSEU4V7ssuHONZlIswLL6GDPdhvHRnrQ8kIY2G8l46RzEhMdZt6Zl03LAviuAcTewJJSz6E3F8tHHBAiJE5Rj/c06yZhCcwZRmZoUphuFj8/554Zqhd2IDF7kmZ+oX5xUr4F4q0hlZ925JrZVtiDx7Lqw8eHwWOlvAHASk5b3Elav+o2wbCDix0yPPywPPu676B8B7E+ZL39RCn4PtJYeOrJy4ApgIXAJAbL0xhSZEZTPkMEU8XHsjuGvxcpognCjvyAu8IUpCVW5Iwnsx4yheO+FvHY4iOHWr9oLYDnUr/mNYAU0ufS+MJPv9XSTzBGxAeG3AFE7wQQgghhBDiBwMUs5HKdLyOAAAAAElFTkSuQmCC",
		"-1" : "iVBORw0KGgoAAAANSUhEUgAAADwAAAA8CAYAAAA6/NlyAAACOklEQVR4Ae2ZIWjsQBCGV50LBN5TUcsT5453cDXnVp2qODgVV1V9XsWbeFWv6lW9ilfxKl6lezApy5LtLP03YUnng59CO6H8+SeT3awSfjeCIAiCIAjCzerVqlKJuFs1VlrlyQsZfvzcKZCr1UgayHxu6Idh0jnF3Rs9fWSYtnFMw63dTmYzTnvntPZzqjvYJ0jbWA0krdJyQlP2KcG0G+86g0xiJuWLAkDTLulvI2B4MlKTsZiUC0Wsmbam342gYXcSn5iUp7qDWgATMPRuVTqvtgExTFyY961fd1MLUZLBubSvbg1ouIhMeY+1dTzX+LSDhjtmghsyUke29V4ROaQ9Z3hwBiD3LOuIqW4Srrr4JJka7n/oYA2/jDTwIiRggE2SqZmjp7oWMHP46gSAkReetvO66wAz1XKG8bTNTIIjiTNTRNRUsGEg7Xsg7dapKZlJ/ifGTHLDQNo6sNTsyaBbYxgz2Rqe9Baddoj8DfNJMjV5tTSgoyL4tPMfWqy8BNm0s30tAYZj0p54srotvfC4r2GY+G/VzVzT0aPAcU71fUtbmYDaBIZ777ltAtc2agLfPOBbRNCwv3E48mnj20O0C7ofGi49swSfNv4BAKeNNhxPTNp/rWpmqK3T4oDhiiZzbNo7ugYHaXHAcO19b+bTzoA2gWGd71EQ3+LRKVCLFsDhwLrwk3iFw4GNsbcq2LQ3QuWcSPxj0jZqA9SBIxg/7cGq3JJh/c2zbbZi1p3ggiAIgiAIQjZ8AoxZK6i4lrSOAAAAAElFTkSuQmCC",
		"-2" : "iVBORw0KGgoAAAANSUhEUgAAADwAAAA8CAMAAAANIilAAAAAY1BMVEUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABmaHTeAAAAIXRSTlMAU2YacIAgYAZQ/+85v0CPTN8zEM9GDS2vJp8wfy8UWSLQfZGSAAABoElEQVR4Ae2Vh3qjMBAGf1MEWsXLcSK9vv9LXlnL+5GFKOJ6YdJjzzeAGnb+FXYOVY0FTetQQld1PQyeKDQowFXVBQwdfeFYEudqeeEDUVm876oPsPBo4xyCw5KPK2lEE2+JiKFMxJq+BLLxeKTXcqAxavoKyMRdICN7ojalq+oaa7BINxE+GBk3FFL6sjpglXgjcY94Y2Sn6Vu97gV+Fhd5Sg/9jka97lvg3bjIgY7nu/bnCc5rk0yaGtcXXHrgAwRezBMRUlPjwpiku3QJuK4qI5Ni4wNNp5VHBKFelZdxBsAiyU93lut1WeONxIeImB77vY5dXpa4kyk6MtzxJJXJwt0sjo2yNDVeftnKPTRe/MAUBjReNlRG1jjwML01SZo3ZTxO9IXpHomL5TbmWBisPA4RrfzZwiyMJT4YmRxwr/H8koSbXslRHrHGc5uBMKiszOJPzwfk8MHK/KBx9DWyuMnII93M4u8xWNmXHUt66bNEdPZkyBMdsifDdm6vznFspq66lxRnbOW56vrTnYf4DbKTn5G3u+iv8OvY2fkMzwwjlCq76hwAAAAASUVORK5CYII=",
		"-3" : "iVBORw0KGgoAAAANSUhEUgAAADwAAAA8CAMAAAANIilAAAAAM1BMVEUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACjBUbJAAAAEXRSTlMAz/9AcIAg7xBQj2C/n9+vMImzzagAAAF8SURBVHgB7JXbjoMwDAVPjiG3lsD/f+1WFrWogQheV8xLsxKzE5lE4OHhvxAo2DGMEVdITBmOQqYBXezBCseLH95X4hP3G6/ktXhOfMMjzcclpYg9o6Yd2eL2EGU3Zk3PQDee3/yVE1u2/xqBTjwmOrmQI5RMHs9GVJozSnIyZnvDMwMOybPGy2fh5Gjpl+17R9nEVQ7r0Cc22/cLSjeu8vfFFrJ8Jz8dHTJr6sLtMrFCmXbnRAVrrgulrZI5A+lkGj5eGX4dOZF9XOxZ/Y3fhRzLFh80XjPyOvbFnL6s8ahHtMlnIeb0ZWPaxHFT1qbFr2/bWGDxywMzBLC4e1XXZIsDYzg7JMOpjCXwQ1iwUvmGI4pSvdxqxqh/jnAXY09JTmbcxvtXEjH8yFlHbHG7ZmfUjWxYfGkBPUrysoyweBZ0icHJjbMfe4fq5XLns1QSN4kc/ZehT47ofhnu84rfOG4jTGWNC+7SmPR26u89bOjIcs/tDPHh4W80AgAyqg30uw64JQAAAABJRU5ErkJggg==",
		"default" : "iVBORw0KGgoAAAANSUhEUgAAADwAAAA8CAYAAAA6/NlyAAABpElEQVR4Ae2ZAYYDMRiFBwQYSoEBAwqUpWCAgAHFMiBAQQHsEfYGPdIeYY/SI8ymBGGt9zTTJDbv47fYQb7+z59MpmsbIYQQQgghFl9XX0MrwpeHcPhrWhAeH8Khpq4RbBBuJtomiva5tk7cQ43dtpxq6/KnrzUqmzKJQZfnkqI7X19BEgqDSeyCGNPlvmSEV14YTuIT6PI11LFwhIEwZo73W+K5pXSEU4V7ssuHONZlIswLL6GDPdhvHRnrQ8kIY2G8l46RzEhMdZt6Zl03LAviuAcTewJJSz6E3F8tHHBAiJE5Rj/c06yZhCcwZRmZoUphuFj8/554Zqhd2IDF7kmZ+oX5xUr4F4q0hlZ925JrZVtiDx7Lqw8eHwWOlvAHASk5b3Elav+o2wbCDix0yPPywPPu676B8B7E+ZL39RCn4PtJYeOrJy4ApgIXAJAbL0xhSZEZTPkMEU8XHsjuGvxcpognCjvyAu8IUpCVW5Iwnsx4yheO+FvHY4iOHWr9oLYDnUr/mNYAU0ufS+MJPv9XSTzBGxAeG3AFE7wQQgghhBDiBwMUs5HKdLyOAAAAAElFTkSuQmCC"
	]
}
