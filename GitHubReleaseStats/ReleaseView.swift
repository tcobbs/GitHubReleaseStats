//
//  ReleaseView.swift
//  GitHubReleaseStats
//
//  Created by Travis Cobbs on 6/6/21.
//

import SwiftUI

public extension Color {

	#if os(macOS)
	static let background = Color(NSColor.windowBackgroundColor)
	static let secondaryBackground = Color(NSColor.unemphasizedSelectedContentBackgroundColor)
	static let tertiaryBackground = Color(NSColor.underPageBackgroundColor)
	#else
	static let background = Color(UIColor.systemBackground)
	static let secondaryBackground = Color(UIColor.secondarySystemBackground)
	static let tertiaryBackground = Color(UIColor.tertiarySystemBackground)
	#endif
}

struct Alternating: View {
	var backgroundColors = [
		Color.red,
		Color.blue,
	]
	var dummyValues = ["One", "Two", "Three", "Four", "Five"]

	func nextBackgroundIndex(_ index: inout Int) -> Int {
		index = index + 1
		return index % 2
	}
	var body: some View {
		var index = 0
		VStack {
			ForEach(dummyValues, id: \.self) { dummyValue in
				Text(dummyValue)
					.frame(maxWidth: .infinity)
					.background(backgroundColors[nextBackgroundIndex(&index)])
			}
		}
	}
}

struct ReleaseView: View {
	let release: Release
	var isExpanded: Binding<Bool>?
	@State var isExpanded2: Bool = false
	private let localFormatter = DateFormatter()
	private let backgroundColors: [Color] = [
		Color.secondaryBackground,
		Color.tertiaryBackground,
	]

	init(release: Release, isExpanded: Binding<Bool>? = nil) {
		self.release = release
		self.isExpanded = isExpanded
		localFormatter.dateStyle = .medium
		localFormatter.timeStyle = .medium
		localFormatter.timeZone = TimeZone.current
	}

	func getDownloadCount() -> Int {
		var downloadCount = 0
		for asset in release.assets {
			downloadCount += asset.downloadCount
		}
		return downloadCount
	}
	
	func nextBackgroundIndex(_ index: inout Int) -> Int {
		index = index + 1
		return index % 2
	}

    var body: some View {
		DisclosureGroup(
			isExpanded: isExpanded ?? $isExpanded2,
			content: {
				var index = 0
				VStack(alignment: .leading) {
					if let publishedAtDate = release.publishedAtDate {
						Text("Published: \(localFormatter.string(from: publishedAtDate))")
					}
					Text("Tag: \(release.tagName)")
						.padding(.bottom, 4.0)
					ForEach(release.assets) { asset in
						if asset.downloadCount > 0 {
							HStack {
								Text("\(asset.name)")
								Spacer()
								Text("\(asset.downloadCount)")
							}
							.padding(.leading, 8.0)
							.padding(.trailing, 8.0)
							.background(backgroundColors[nextBackgroundIndex(&index)])
						}
					}
					Spacer()
						.frame(maxWidth: .infinity, maxHeight: 2.0)
						.background(backgroundColors[release.assets.count % 2])
						.padding(.leading, 8.0)
				}
			},
			label: {
				HStack {
					Text(release.name)
						.bold()
                        .font(.title2)
					if release.prerelease {
						Text("(Prerelease)")
							.foregroundColor(.red)
					}
					Spacer()
					Text("\(getDownloadCount())")
						.bold()
						.font(.title2)
						.padding(.trailing, 4.0)
				}
			})
			.padding(.leading, 6.0)
			.background(Color.secondaryBackground)
			.cornerRadius(8.0)
	}
}

struct ReleaseView_Previews: PreviewProvider {
    static var previews: some View {
//		Alternating()
		ReleaseView(release: Release(
			id: 42,
			name: "Preview Release",
			publishedAt: "2021-06-05T17:18:04Z",
			assets: [
				Asset(id: 13, name: "Preview Asset 1", downloadCount: 13),
				Asset(id: 14, name: "Preview Asset 2", downloadCount: 22),
				Asset(id: 15, name: "Preview Asset 3", downloadCount: 7)],
				prerelease: true,
				tagName: "Preview tag"),
			isExpanded: .constant(true))
    }
}
