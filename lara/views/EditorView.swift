import SwiftUI

struct EditorView: View {
    @ObservedObject private var mgr = laramgr.shared
    @State private var mg: NSMutableDictionary = [:] 
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
            case .iPhone16ProMax: return "16 Pro Max (2868)"
            }
        }
    }
    
    private let path = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
    private let ogmgurl: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        ogmgurl = docs.appendingPathComponent("ogmobilegestalt.plist")
        let sysurl = URL(fileURLWithPath: path)
        var initialDict: NSMutableDictionary = [:]
        if let data = NSMutableDictionary(contentsOf: sysurl) { initialDict = data }
        _mg = State(initialValue: initialDict)

        if let cacheExtra = initialDict["CacheExtra"] as? NSMutableDictionary,
           let oPeik = cacheExtra["oPeik/9e8lQWMszEjbPzng"] as? NSMutableDictionary,
           let subType = oPeik["ArtworkDeviceSubType"] as? Int {
            _selectedSubType = State(initialValue: subType)
            DispatchQueue.main.async {
                if UserDefaults.standard.integer(forKey: "ogSubType") == -1 {
                    UserDefaults.standard.set(subType, forKey: "ogSubType")
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Artwork SubType")
                        Spacer()
                        Picker("", selection: $selectedSubType) {
                            Text("Original (\(ogSubType == -1 ? "" : String(ogSubType)))").tag(ogSubType)
                            ForEach(SubType.allCases.filter { $0.rawValue != ogSubType }) { subtype in
                                Text(subtype.displayName).tag(subtype.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    Toggle("Action Button", isOn: mgkeybinding(["cT44WE1EohiwRzhsZ8xEsw"]))
                    Toggle("Stage Manager", isOn: mgkeybinding(["qeaj75wk3HF4DwQ8qbIi7g"]))
                } header: { Text("MobileGestalt") }

                Section {
                    Toggle("iPad Mode (Stage Manager)", isOn: bindingForTrollPad())
                } header: {
                    Text("Режим Планшета")
                } footer: {
                    Text("Если часы съехали, попробуйте выбрать SubType '14 Pro (2556)' выше и применить еще раз.")
                }

                Section {
                    Button("Reload from plist") { load() }
                    Button("Apply Changes") { apply() }
                        .disabled(!valid)
                }
            }
            .navigationTitle("MobileGestalt")
            .alert("Status", isPresented: Binding(get: { status != nil }, set: { _ in status = nil })) {
                Button("OK", role: .cancel) { }
            } message: { Text(status ?? "") }
            .alert("Done", isPresented: Binding(get: { alert != nil }, set: { _ in alert = nil })) {
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
            valid = validate(mg)
        }
    }

    private func apply() {
        guard let cacheExtra = mg["CacheExtra"] as? NSMutableDictionary,
              let oPeik = cacheExtra["oPeik/9e8lQWMszEjbPzng"] as? NSMutableDictionary else { return }
        
        oPeik["ArtworkDeviceSubType"] = selectedSubType
        
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: mg, format: .binary, options: 0)
            let result = laramgr.shared.lara_overwritefile(target: path, data: data)
            if result.ok { alert = "Applied! Respring now." }
        } catch { status = "Error" }
    }

    private func bindingForTrollPad() -> Binding<Bool> {
        guard let cacheData = mg["CacheData"] as? NSMutableData,
              let cacheExtra = mg["CacheExtra"] as? NSMutableDictionary,
              let oPeik = cacheExtra["oPeik/9e8lQWMszEjbPzng"] as? NSMutableDictionary else {
            return .constant(false)
        }
        let valueOffset = FindCacheDataOffset("mtrAoWJ3gsq+I90ZnQ0vQw")
        let keys = ["uKc7FPnEO++lVhHWHFlGbQ", "mG0AnH/Vy1veoqoLRAIgTA", "UCG5MkVahJxG1YULbbd5Bg", "ZYqko/XM5zD3XBfN5RmaXA", "nVh/gwNpy7Jv1NOk00CMrw", "qeaj75wk3HF4DwQ8qbIi7g"]

        return Binding(
            get: { (cacheExtra[keys[0]] as? Int) == 1 },
            set: { enabled in
                cacheData.mutableBytes.storeBytes(of: enabled ? 3 : 1, toByteOffset: valueOffset, as: Int.self)
                for key in keys {
                    if enabled { cacheExtra[key] = 1 } else { cacheExtra.removeObject(forKey: key) }
                }
                
                // ХИТРОСТЬ: Если включаем iPad Mode, ставим SubType от iPhone 14 Pro,
                // чтобы попытаться спасти часы.
                if enabled {
                    oPeik["ArtworkDeviceSubType"] = 2556
                    selectedSubType = 2556
                } else {
                    oPeik["ArtworkDeviceSubType"] = ogSubType
                    selectedSubType = ogSubType
                }
                
                valid = validate(mg)
            }
        )
    }

    private func mgkeybinding(_ keys: [String]) -> Binding<Bool> {
        guard let cachextra = mg["CacheExtra"] as? NSMutableDictionary else { return .constant(false) }
        return Binding(
            get: { (cachextra[keys.first ?? ""] as? Int) == 1 },
            set: { enabled in
                for key in keys {
                    if enabled { cachextra[key] = 1 } else { cachextra.removeObject(forKey: key) }
                }
                valid = validate(mg)
            }
        )
    }
}
