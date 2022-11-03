//
//  ContentView.swift
//  GitHubReleaseStats
//
//  Created by Travis Cobbs on 6/5/21.
//

import SwiftUI

extension View {
	func alignedView(width: Binding<CGFloat>, isTrailing: Bool = true) -> some View {
		self.modifier(AlignedWidthView(width: width, isTrailing: isTrailing))
	}
}

struct ViewWidthKey: PreferenceKey {
	static var defaultValue: CGFloat = .zero

	static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
		value = nextValue()
	}
}

struct AlignedWidthView: ViewModifier {
	@Binding var width: CGFloat
	let isTrailing: Bool

	func body(content: Content) -> some View {
		content.background(GeometryReader {
			Color.clear.preference(key: ViewWidthKey.self, value: $0.frame(in: .local).size.width)
		})
		.onPreferenceChange(ViewWidthKey.self) {
			if $0 > self.width {
				self.width = $0
			}
		}
		.frame(minWidth: width, alignment: isTrailing ? .trailing : .leading)
	}
}

struct ContentView: View {
	static let defaults = UserDefaults.standard
	@State private var user = defaults.object(forKey: "user") as? String ?? ""
	@State private var project = defaults.object(forKey: "project") as? String ?? ""
	@State private var width = CGFloat.zero
	@State private var releases: [Release] = []
	@State private var fetched = false
	@State private var error: Error? = nil
    var body: some View {
		VStack(alignment: .trailing, spacing: 4.0) {
			Form {
				HStack {
					Text("User:")
						.alignedView(width: $width)
					TextField("", text: $user)
				}
				HStack {
					Text("Project:")
						.alignedView(width: $width)
					TextField("", text: $project)
				}
			}
			.frame(minWidth: 320, idealWidth: 400)
			.padding(.all)
			Button {
				fetch()
			} label: {
				Text("Fetch")
			}
			.padding([.bottom, .trailing])
			.frame(alignment: .trailing)
			if (fetched) {
				HStack {
					Text("\(releases.count) releases")
						.padding(.leading)
					Spacer()
				}
			}
			if let error = error {
				HStack {
					Text("Error: \(error.localizedDescription)")
						.foregroundColor(.red)
						.padding(.leading)
					Spacer()
				}				
			}
			ScrollView {
				VStack(alignment: .leading, spacing: 8.0) {
					ForEach(releases) { release in
						ReleaseView(release: release)
					}
				}
				.padding(/*@START_MENU_TOKEN@*/[.leading, .bottom, .trailing]/*@END_MENU_TOKEN@*/)
				.frame(maxWidth: .infinity, alignment: .topLeading)
			}
		}
    }
	
	func fetch() {
		if user.isEmpty || project.isEmpty {
			print("Cannot Fetch")
		} else {
			ContentView.defaults.set(user, forKey: "user")
			ContentView.defaults.set(project, forKey: "project")
			let gitHubAPI = GitHubAPI()
			Task {
				do {
					let releases = try await gitHubAPI.getReleases(user: user, project: project)
					self.releases = releases
					fetched = true
					processReleases()
				} catch {
					self.error = error
					fetched = false
					print("Error fetching release data: \(error)")
				}
			}
		}
	}
	
	func processReleases() {
		for i in releases.indices {
			releases[i].assets.sort { left, right in
				if left.downloadCount == right.downloadCount {
					return left.name < right.name
				} else {
					return left.downloadCount > right.downloadCount
				}
			}
		}
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
		ContentView()
    }
}
