import SwiftUI

struct EditorView: View {
    @ObservedObject private var mgr = laramgr.shared
    @State private var mg: NSMutableDictionary
    @State private var status: String?
    @State private var alert: String?
    @State private var valid: Bool = true
    @AppStorage("ogSubType") private var ogSubType: Int = -1
    @State private var selectedSubType: Int = -1

    enum SubType: Int, CaseIterable, Identifiable {
        case iPhone14Pro = 2556
        case iPhone14ProMax = 2796
        case iPhone16Pro = 2622
        case iPhone16ProMax = 2868

        var id: Int { self.rawValue }
        var displayName: String {
            switch self {
            case .iPhone14Pro: return "14 Pro (2556)"
            case .iPhone14ProMax: return "14 Pro Max (2796)"
            case .iPhone16Pro: return "iOS 18+:\n16 Pro (2622)"
            case .iPhone16ProMax: return "iOS 18+:\n16 Pro Max (2868)"
            }
        }
    }
    
    private let path = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
    private let ogmgurl: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        ogmgurl = docs.appendingPathComponent("ogmobilegestalt.plist")
        let sysurl = URL(fileURLWithPath: path)
        do {
            if !FileManager.default.fileExists(atPath: ogmgurl.path) {
                try FileManager.default.copyItem(at: sysurl, to: ogmgurl)
            }
            chmod(ogmgurl.path, 0o644)
            _mg = State(initialValue: (try? NSMutableDictionary(contentsOf: URL(fileURLWithPath: path), error: ())) ?? [:])
        } catch {
            _mg = State(initialValue: [:])
            _status = State(initialValue: "Failed to copy MobileGestalt: \(error)")
        }
        
        if let cacheExtra = mg["CacheExtra"] as? NSMutableDictionary, 
           let oPeik = cacheExtra["oPeik/9e8lQWMszEjbPzng"] as? NSMutableDictionary,
           let subType = oPeik["ArtworkDeviceSubType"] as? Int {
            _selectedSubType = State(initialValue: subType)
            if ogSubType == -1 { ogSubType = subType }
        } else {
            _selectedSubType = State(initialValue: -1)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Dynamic Island")
                        Spacer()
                        Picker("", selection: $selectedSubType) {
                            Text("Original (\(String(ogSubType)))").tag(ogSubType)
                            ForEach(SubType.allCases.filter { $0.rawValue != ogSubType }) { subtype in
                                Text(subtype.displayName).tag(subtype.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    Toggle("Action Button (17+)", isOn: mgkeybinding(["cT44WE1EohiwRzhsZ8xEsw"]))
                    Toggle("Always on Display (18.0+)", isOn: mgkeybinding(["j8/Omm6s1lsmTDFsXjsBfA", "2OOJf1VhaM7NxfRok3HbWQ"]))
                    Toggle("Stage Manager", isOn: mgkeybinding(["qeaj75wk3HF4DwQ8qbIi7g"]))
                } header: {
                    Text("MobileGestalt")
                }

                Section {
                    Toggle("iPad Mode (Ломает часы!)", isOn: bindingForTrollPad())
                    Toggle("iPad Features (Безопасно)", isOn: bindingForiPadFeatures())
                } header: {
                    Text("iPadOS Features")
                } footer: {
                    Text("Используйте 'Безопасно', чтобы включить жесты iPad, не ломая статус-бар и часы на iPhone.")
                }

                Section {
                    Button("Reload from plist") { load() }
                    Button("Apply Modified MobileGestalt") { apply() }
                        .disabled(!valid)
                } header: {
                    Text("Apply Changes")
                }
            }
            .navigationTitle("MobileGestalt")
            .alert("Status", isPresented: .constant(status != nil)) {
                Button("OK") { status = nil }
            } message: { Text(status ?? "") }
            .alert("Done", isPresented: .constant(alert != nil)) {
                Button("Cancel") { alert = nil }
                Button("Respring") { mgr.respring() }
            } message: { Text(alert ?? "") }
        }
    }

    private func validate(_ dict: NSMutableDictionary) -> Bool {
        guard let cacheExtra = dict["CacheExtra"] as? NSMutableDictionary else { return false }
        return !cacheExtra.allKeys.isEmpty
    }

    private func load() {
        if let newMg = NSMutableDictionary(contentsOf: URL(fileURLWithPath: path)) {
            mg = newMg
        } else {
            status = "Failed to load"
        }
    }

    private func apply() {
        guard let cacheExtra = mg["CacheExtra"] as? NSMutableDictionary,
              let oPeik = cacheExtra["oPeik/9e8lQWMszEjbPzng"] as? NSMutableDictionary else {
            status = "Error in dictionary structure"
            return
        }
        
        oPeik["ArtworkDeviceSubType"] = selectedSubType
        
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: mg, format: .binary, options: 0)
            let result = laramgr.shared.lara_overwritefile(target: path, data: data)
            if result.ok {
                alert = "Applied! Respring to see changes."
            } else {
                status = "Error: \(result.message)"
            }
        } catch {
            status = "Serialization failed"
        }
    }

    // --- Функции привязки (Bindings) ---

    private func bindingForTrollPad() -> Binding<Bool> {
        guard let cacheData = mg["CacheData"] as? NSMutableData,
              let cacheExtra = mg["CacheExtra"] as? NSMutableDictionary else {
            return .constant(false)
        }
        let valueOffset = FindCacheDataOffset("mtrAoWJ3gsq+I90ZnQ0vQw")
        let keys = ["uKc7FPnEO++lVhHWHFlGbQ", "mG0AnH/Vy1veoqoLRAIgTA", "UCG5MkVahJxG1YULbbd5Bg", "ZYqko/XM5zD3XBfN5RmaXA", "nVh/gwNpy7Jv1NOk00CMrw", "qeaj75wk3HF4DwQ8qbIi7g"]

        return Binding(
            get: { (cacheExtra[keys[0]] as? Int) == 1 },
            set: { enabled in
                if enabled { status = "ВНИМАНИЕ: Это изменит DeviceClass и сломает верстку часов!" }
                cacheData.mutableBytes.storeBytes(of: enabled ? 3 : 1, toByteOffset: valueOffset, as: Int.self)
                for key in keys {
                    if enabled { cacheExtra[key] = 1 } else { cacheExtra.removeObject(forKey: key) }
                }
                valid = validate(mg)
            }
        )
    }

    private func bindingForiPadFeatures() -> Binding<Bool> {
        guard let cacheExtra = mg["CacheExtra"] as? NSMutableDictionary else { return .constant(false) }
        let keys = ["mG0AnH/Vy1veoqoLRAIgTA", "UCG5MkVahJxG1YULbbd5Bg", "ZYqko/XM5zD3XBfN5RmaXA", "nVh/gwNpy7Jv1NOk00CMrw", "qeaj75wk3HF4DwQ8qbIi7g"]

        return Binding(
            get: { (cacheExtra[keys[0]] as? Int) == 1 },
            set: { enabled in
                for key in keys {
                    if enabled { cacheExtra[key] = 1 } else { cacheExtra.removeObject(forKey: key) }
                }
                valid = validate(mg)
            }
        )
    }

    private func mgkeybinding<T: Equatable>(_ keys: [String], type: T.Type = Int.self, enable: T = 1 as! T) -> Binding<Bool> {
        guard let cachextra = mg["CacheExtra"] as? NSMutableDictionary else { return .constant(false) }
        return Binding(
            get: { (cachextra[keys.first!] as? T) == enable },
            set: { enabled in
                for key in keys {
                    if enabled { cachextra[key] = enable } else { cachextra.removeObject(forKey: key) }
                }
                valid = validate(mg)
            }
        )
    }
}
