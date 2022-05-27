import SwiftUI


extension Set: RawRepresentable where Element: Codable {

    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8) else { return nil }
        guard let result = try? JSONDecoder().decode(Set<Element>.self, from: data) else { return nil}
        
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self) else { return "[]" }
        guard let result = String(data: data, encoding: .utf8) else { return "[]" }
        
        return result
    }
    
}


struct ContentView: View {
    
    @AppStorage("apps") private var apps: Set<String> = []
    @State private var appsSelection: Set<String> = []
    
    var body: some View {
        
        Form {
            List(Array(apps), id: \.self, selection: $appsSelection) { app in
                Text(app)
            }
            .contextMenu {
                Button("Delete") {
                    for selection in appsSelection {
                        apps.remove(selection)
                    }
                }
                .disabled(appsSelection.isEmpty)
            }
            .onDeleteCommand {
                for selection in appsSelection {
                    apps.remove(selection)
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .onDrop(of: [.fileURL], delegate: AppsDropDelegate(apps: $apps))
        }

    }
        
}


private struct AppsDropDelegate: DropDelegate {

    @Binding var apps: Set<String>


    func validateDrop(info: DropInfo) -> Bool {
        guard info.hasItemsConforming(to: [.fileURL]) else { return false }

        let providers = info.itemProviders(for: [.fileURL])
        var result = false

        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                let group = DispatchGroup()
                group.enter()

                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    let itemIsAnApplicationBundle = try? url?.resourceValues(forKeys: [.contentTypeKey]).contentType == .applicationBundle
                    result = result || (itemIsAnApplicationBundle ?? false)
                    group.leave()
                }
                                
                _ = group.wait(timeout: .now() + 0.5)
            }
        }

        return result
    }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.fileURL])
        var result = false

        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                let group = DispatchGroup()
                group.enter()

                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    let itemIsAnApplicationBundle = (try? url?.resourceValues(forKeys: [.contentTypeKey]).contentType == .applicationBundle) ?? false

                    if itemIsAnApplicationBundle, let url = url, let app = Bundle(url: url), let bundleIdentifier = app.bundleIdentifier {
                        DispatchQueue.main.async {
                            apps.insert(bundleIdentifier)
                        }
                        
                        result = result || true
                    }
                                        
                    group.leave()
                }

                _ = group.wait(timeout: .now() + 0.5)
            }
        }
        
        return result
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
