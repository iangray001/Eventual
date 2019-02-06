//
//  WebInterface.swift
//  Eventual
//
//  Created by Ian Gray on 04/01/2019.
//

import Foundation


class BTT {
	//This class interacts with the BetterTouchTool web interface. This is documented at:
	//https://docs.bettertouchtool.net/docs/webserver.html
	//Note that currently the endpoint set_persistent_number_variable seems to cause the number
	//to be stored in scientific format which messes scripts up. So all interactions with BTT currently
	//store data in strings.
	
	static var bttServername : String = ""
	static var bttSecret : String = ""
	
	
	class func setPersistentStringVariable(varName : String, to: String, onError: ((Error) -> ())?) {
		
		let requrl = bttServername + "/set_persistent_string_variable/?shared_secret="
			+ bttSecret + "&variableName=" + varName + "&to=" + to
		let url = URL(string: requrl)!
		
		let task = URLSession(configuration: .default).dataTask(with: url) { (data, response, error) in
			if let e = error {
				onError?(e)
			}
		}
		task.resume()
	}

	
	class func updateTouchBarWidget(uuid : String, text : String, icon_data : String?) {
		var requrl = bttServername + "/update_touch_bar_widget/?shared_secret=" + bttSecret + "&uuid=" + uuid + "&text=" + text
		
		if let id = icon_data {
			requrl += "&icon_data=" + id
		}
		
		let url = URL(string: requrl)!
		let task = URLSession(configuration: .default).dataTask(with: url) { (data, response, error) in }
		task.resume()
	}
	
	
	class func refreshWidget(uuid : String) {
		let requrl = bttServername + "/refresh_widget/?shared_secret=" + bttSecret + "&uuid=" + uuid
		let url = URL(string: requrl)!
		let task = URLSession(configuration: .default).dataTask(with: url) { (data, response, error) in }
		task.resume()
	}
	
}

