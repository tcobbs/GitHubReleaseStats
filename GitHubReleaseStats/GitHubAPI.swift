//
//  GitHubAPI.swift
//  GitHubReleaseStats
//
//  Created by Travis Cobbs on 6/5/21.
//

// GitHub REST API Documentation:
// https://docs.github.com/en/rest
// Repositories:
// https://docs.github.com/en/rest/reference/repos

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
	let tagName: String

	enum CodingKeys: String, CodingKey {
		case id
		case name
		case publishedAt = "published_at"
		case assets
		case prerelease
		case tagName = "tag_name"
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
	func getReleases(user: String, project: String) async throws -> [Release] {
		let data = try await download(url: URL(string: apiRoot + "repos/\(user)/\(project)/releases"))
		if let releases: [Release] = try? DictArrayDecoder.decode(data) {
			return releases
		} else {
			throw "Could not parse release data"
		}
	}

	func download(url: URL?) async throws -> Data {
		guard let url = url else {
			throw "URL Failure"
		}
		let uuid = UUID()
		values[uuid] = []
		return try await downloadPages(uuid: uuid, url: url)
	}

	func addValues(uuid: UUID, data: Data) {
		if let pageValues = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
			values[uuid]!.append(contentsOf: pageValues)
		}
	}

	func downloadPage(uuid: UUID, url: URL) async throws -> (Data, URL?) {
		var request = URLRequest(url: url)
		request.httpMethod = "GET"
		request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
		let (data, response) = try await URLSession.shared.data(for: request)
		if let response = response as? HTTPURLResponse
		{
			if response.statusCode == 200
			{
				if let linkHeader = response.value(forHTTPHeaderField: "link") {
					let links = linkHeader.components(separatedBy: ",")
					for link in links {
						if link.hasSuffix("rel=\"next\"") {
							if let start = link.firstIndex(of: "<"), let end = link.lastIndex(of: ">") {
								if let nextPageURL = URL(string: String(link[link.index(after: start)..<end])) {
									return (data, nextPageURL)
								}
							}
						}
					}
				}
				return (data, nil)
			} else {
				throw "Status code: \(response.statusCode)"
			}
		} else {
			throw "Invalid response."
		}
	}

	func downloadPages(uuid: UUID, url: URL) async throws -> Data {
		let (data, nextPageURL) = try await downloadPage(uuid: uuid, url: url)
		addValues(uuid: uuid, data: data)
		if let nextPageURL = nextPageURL {
			return try await downloadPages(uuid: uuid, url: nextPageURL)
		} else {
			let jsonData = try JSONSerialization.data(withJSONObject: values[uuid]!, options: [])
			values.removeValue(forKey: uuid)
			return jsonData
		}
	}
}
