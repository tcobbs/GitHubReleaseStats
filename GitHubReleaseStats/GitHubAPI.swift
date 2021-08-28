//
//  GitHubAPI.swift
//  GitHubReleaseStats
//
//  Created by Travis Cobbs on 6/5/21.
//

import Foundation

class DictArrayDecoder<T: Decodable> {
	static func decode(_ jsonData: Data) throws -> T {
		return try JSONDecoder().decode(T.self, from: jsonData)
	}

	static func decode(_ array: [[String: Any]]) throws -> T {
		let jsonData = try JSONSerialization.data(withJSONObject: array, options: [])
		return try decode(jsonData)
	}
}

class DictDecoder<T: Decodable> {
	static func decode(_ jsonData: Data) throws -> T {
		return try JSONDecoder().decode(T.self, from: jsonData)
	}

	static func decode(_ dict: [String: Any]) throws -> T {
		let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])
		return try decode(jsonData)
	}
}

struct Asset: Codable, Identifiable {
	let id: Int
	let name: String
	let downloadCount: Int

	enum CodingKeys: String, CodingKey {
		case id
		case name
		case downloadCount = "download_count"
	}
}

struct Release: Codable, Identifiable {
	let id: Int
	let name: String
	let publishedAt: String
	var assets: [Asset]
	let prerelease: Bool

	enum CodingKeys: String, CodingKey {
		case id
		case name
		case publishedAt = "published_at"
		case assets
		case prerelease
	}

	var publishedAtDate: Date? {
		return ISO8601DateFormatter().date(from: publishedAt)
	}
}

extension String: LocalizedError {
	public var errorDescription: String? { return self }
}

class GitHubAPI {
	let apiRoot = "https://api.github.com/"
	var values: [UUID: [[String: Any]]] = [:]

	// Example URL:	
	// https://api.github.com/repos/tcobbs/ldview/releases
	func getReleases(user: String, project: String, completion: @escaping (([Release]?, Error?) -> Void)) {
		download(url: URL(string: apiRoot + "repos/\(user)/\(project)/releases")) { data, error in
			if error != nil {
				completion(nil, error)
			} else if let data = data {
			    if let releases: [Release] = try? DictArrayDecoder.decode(data) {
					completion(releases, nil)
				} else {
					completion(nil, "Could not parse release data")
				}
			} else {
				completion(nil, nil)
			}
		}
	}
	
	func download(url: URL?, completion: @escaping ((Data?, Error?) -> Void)) {
		guard let url = url else {
			completion(nil, "URL Failure")
			return
		}
		let uuid = UUID()
		values[uuid] = []
		downloadPage(uuid: uuid, url: url) { data, error, nextPageURL in
			if let data = data, let nextPageURL = nextPageURL {
				self.addValues(uuid: uuid, data: data)
				self.downloadPages(uuid: uuid, url: nextPageURL, completion: completion)
			} else {
				completion(data, error)
			}
		}
	}

	func addValues(uuid: UUID, data: Data) {
		if let pageValues = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
			values[uuid]!.append(contentsOf: pageValues)
		}
	}

	func downloadPage(uuid: UUID, url: URL, completion: @escaping((Data?, Error?, URL?) -> Void)) {
		let session = URLSession(configuration: URLSessionConfiguration.default)
		var request = URLRequest(url: url)
		request.httpMethod = "GET"
		request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
		let task = session.dataTask(with: request) { (data, response, error) in
			if error == nil {
				if let response = response as? HTTPURLResponse
				{
					if response.statusCode == 200
					{
						if let linkHeader = response.value(forHTTPHeaderField: "Link") {
							let links = linkHeader.components(separatedBy: ",")
							for link in links {
								if link.hasSuffix("rel=\"next\"") {
									if let data = data, let start = link.firstIndex(of: "<"), let end = link.lastIndex(of: ">") {
										if let nextPageURL = URL(string: String(link[link.index(after: start)..<end])) {
											completion(data, nil, nextPageURL)
											return
										}
									}
								}
							}
						}
						completion(data, nil, nil)
					} else {
						completion(nil, "Status code: \(response.statusCode)", nil)
					}
				} else {
					completion(nil, "Invalid response.", nil)
				}
			} else {
				completion(nil, error, nil)
			}
		}
		task.resume()
	}
	
	func downloadPages(uuid: UUID, url: URL, completion: @escaping ((Data?, Error?) -> Void)) {
		downloadPage(uuid: uuid, url: url) { data, error, nextPageURL in
			if let data = data {
				self.addValues(uuid: uuid, data: data)
			}
			if let nextPageURL = nextPageURL {
				self.downloadPages(uuid: uuid, url: nextPageURL, completion: completion)
			} else {
				if let jsonData = try? JSONSerialization.data(withJSONObject: self.values[uuid]!, options: []) {
					self.values.removeValue(forKey: uuid)
					completion(jsonData, nil)
				}
			}
		}
	}
}
