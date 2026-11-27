import SwiftUI
import AppKit
import AVFoundation

private let defaultCategories = ["kick", "kick2", "snare", "perc", "misc", "tom", "hihat", "cymbal"]
private let notePitches = [60, 62, 64, 65, 67, 69, 71, 72]
private let kitNames = [
    "IRON VEIL", "NIGHT GRID", "DARK CIRCUIT", "VOID SIGNAL", "RUST ENGINE", "COLD FACTORY", "STATIC RITUAL", "NEON DECAY",
    "BLACK VOLT", "STEEL PULSE", "GHOST MACHINE", "DUST VECTOR", "PHASE DAMAGE", "NOIR SYSTEM", "DEAD CHANNEL", "ACID FURNACE",
    "CONCRETE", "ZERO HOUR", "CHROME ASH", "TUNNEL VISION", "DEEP PRESSURE", "MACHINE AGE", "GRIT SECTOR", "SUBLEVEL",
    "FRACTURE", "DREAD SIGNAL", "DARK MATTER", "NIGHT SHIFT", "CARBON COPY", "BROKEN PHASE", "CIRCUIT WRAITH", "LOW FREQUENCY",
    "RED SECTOR", "HEAT DEATH", "INDUSTRIAL", "DYSTOPIA", "ACID TOWER", "MUTED ALARM", "SHADOW WORK", "COLD METAL"
]

@MainActor
final class ForgeModel: ObservableObject {
    @Published var categories: [String] = defaultCategories { didSet { save() } }
    @Published var folders: [String] = Array(repeating: "", count: 8) { didSet { save() } }
    @Published var outputFolder = "" { didSet { save() } }
    @Published var kitCount = 10 { didSet { save() } }
    @Published var status = "Select one WAV folder for each slot. Your choices are saved automatically."
    @Published var progress = 0.0
    @Published var generating = false

    init() {
        let defaults = UserDefaults.standard
        categories = (defaults.stringArray(forKey: "categories")?.count == 8 ? defaults.stringArray(forKey: "categories")! : defaultCategories)
        folders = (defaults.stringArray(forKey: "folders")?.count == 8 ? defaults.stringArray(forKey: "folders")! : Array(repeating: "", count: 8))
        outputFolder = defaults.string(forKey: "outputFolder") ?? ""
        kitCount = max(1, min(500, defaults.integer(forKey: "kitCount") == 0 ? 10 : defaults.integer(forKey: "kitCount")))
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(categories, forKey: "categories")
        defaults.set(folders, forKey: "folders")
        defaults.set(outputFolder, forKey: "outputFolder")
        defaults.set(kitCount, forKey: "kitCount")
    }

    func chooseFolder(_ index: Int) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose WAV Folder"
        if panel.runModal() == .OK, let url = panel.url { folders[index] = url.path }
    }

    func chooseOutput() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Output Folder"
        if panel.runModal() == .OK, let url = panel.url { outputFolder = url.path }
    }

    func generate() {
        guard !outputFolder.isEmpty, FileManager.default.fileExists(atPath: outputFolder) else {
            status = "Choose a valid output folder first."; return
        }
        guard categories.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            status = "Each slot needs a category name."; return
        }
        let inputSlots = zip(categories, folders).enumerated().map { ($0.offset + 1, $0.element.0, $0.element.1) }
        for (number, category, folder) in inputSlots {
            if Self.wavs(in: folder).isEmpty {
                status = "Choose a folder containing WAV files for slot \(number) (\(category))."; return
            }
        }
        generating = true
        progress = 0
        status = "Generating kits…"
        let count = max(1, min(500, kitCount))
        let output = URL(fileURLWithPath: outputFolder, isDirectory: true)
        let inputs = inputSlots
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try KitBuilder.generate(slots: inputs, count: count, output: output) { done in
                    DispatchQueue.main.async {
                        self.progress = Double(done) / Double(count)
                        self.status = "Generated \(done) of \(count) kits…"
                    }
                }
                DispatchQueue.main.async {
                    self.generating = false
                    self.progress = 1
                    self.status = "Done. Created \(count) kit ZIP files."
                }
            } catch {
                DispatchQueue.main.async {
                    self.generating = false
                    self.status = "Generation stopped: \(error.localizedDescription)"
                }
            }
        }
    }

    nonisolated static func wavs(in folder: String) -> [URL] {
        guard !folder.isEmpty else { return [] }
        let url = URL(fileURLWithPath: folder, isDirectory: true)
        return ((try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension.lowercased() == "wav" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}

@main
struct TonverkKitForgeApp: App {
    var body: some Scene {
        WindowGroup { MainView().frame(minWidth: 760, minHeight: 650) }
        .windowStyle(.hiddenTitleBar)
    }
}

struct MainView: View {
    @StateObject private var model = ForgeModel()
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    private let slotColors: [Color] = [.blue, .indigo, .red, .purple, .gray, .purple, .green, .cyan]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "waveform.path").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 38, height: 38).background(.indigo, in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 2) {
                    Text("TONVERK KIT FORGE").font(.system(size: 12, weight: .bold, design: .rounded)).tracking(1.2)
                    Text("Random subtrack preset generator").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("48 kHz · 24 bit · MONO").font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary).padding(.horizontal, 11).padding(.vertical, 8).background(.quaternary, in: Capsule())
            }.padding(.horizontal, 25).padding(.vertical, 15).background(.regularMaterial)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Build a kit from your library").font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("Your folders and slot names are remembered when you reopen the app.").font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(0..<8, id: \.self) { index in
                            HStack(spacing: 12) {
                                Text(String(format: "%02d", index + 1)).font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(slotColors[index]).frame(width: 33, height: 33)
                                    .background(slotColors[index].opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
                                VStack(alignment: .leading, spacing: 7) {
                                    TextField("Category", text: $model.categories[index]).font(.system(size: 13, weight: .semibold)).textFieldStyle(.plain)
                                    Button { model.chooseFolder(index) } label: {
                                        Label(model.folders[index].isEmpty ? "Choose WAV folder" : URL(fileURLWithPath: model.folders[index]).lastPathComponent,
                                              systemImage: model.folders[index].isEmpty ? "folder.badge.plus" : "folder.fill")
                                            .font(.system(size: 11)).lineLimit(1).truncationMode(.middle)
                                    }.buttonStyle(.plain).foregroundStyle(model.folders[index].isEmpty ? .secondary : .primary)
                                    if !model.folders[index].isEmpty {
                                        Text("\(ForgeModel.wavs(in: model.folders[index]).count) WAV files")
                                            .font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                                    }
                                }
                                Spacer(minLength: 0)
                            }.padding(13).background(.background, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary, lineWidth: 1))
                        }
                    }
                    HStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("NUMBER OF KITS").font(.system(size: 10, weight: .bold)).tracking(0.7).foregroundStyle(.secondary)
                            Stepper(value: $model.kitCount, in: 1...500) { Text("\(model.kitCount) kits").font(.system(size: 13, weight: .semibold)).monospacedDigit() }.frame(width: 135)
                        }
                        Rectangle().fill(.quaternary).frame(width: 1, height: 38)
                        VStack(alignment: .leading, spacing: 7) {
                            Text("SAVE ZIP FILES TO").font(.system(size: 10, weight: .bold)).tracking(0.7).foregroundStyle(.secondary)
                            Button { model.chooseOutput() } label: {
                                Label(model.outputFolder.isEmpty ? "Choose output folder" : model.outputFolder,
                                      systemImage: "folder").font(.system(size: 11)).lineLimit(1).truncationMode(.middle)
                            }.buttonStyle(.plain)
                        }
                        Spacer(minLength: 0)
                    }.padding(15).background(.background, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary, lineWidth: 1))
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(model.status).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
                            if model.generating { ProgressView(value: model.progress).frame(width: 260) }
                        }
                        Spacer()
                        Button(action: model.generate) {
                            Label(model.generating ? "Generating…" : "Generate kits", systemImage: model.generating ? "hourglass" : "shuffle")
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 17).padding(.vertical, 11).background(.indigo, in: RoundedRectangle(cornerRadius: 11))
                        }.buttonStyle(.plain).disabled(model.generating)
                    }
                    Text("Each ZIP contains a named folder, eight converted WAVs, and a matching .eldrum file. Kit names are 16 characters or fewer.")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }.padding(25)
            }
        }.background(Color(nsColor: .windowBackgroundColor))
    }
}

enum KitBuilder {
    static func generate(slots: [(Int, String, String)], count: Int, output: URL, progress: (Int) -> Void) throws {
        let names = kitNames.shuffled()
        var used = Set<String>()
        for index in 0..<count {
            let base = names[index % names.count]
            var name = base
            if index >= names.count {
                let tail = " \(index / names.count + 1)"
                name = String(base.prefix(16 - tail.count)) + tail
            }
            var suffix = 2
            while used.contains(name.lowercased()) {
                let tail = " \(suffix)"
                name = String(base.prefix(16 - tail.count)) + tail
                suffix += 1
            }
            used.insert(name.lowercased())
            let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            let kitFolder = temp.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.createDirectory(at: kitFolder, withIntermediateDirectories: true)
            do {
                var filenames: [String] = []
                for (number, category, folder) in slots {
                    guard let sample = ForgeModel.wavs(in: folder).randomElement() else { throw ForgeError.emptySlot(number, category) }
                    let cleanCategory = String(category.lowercased().map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" ? $0 : "_" })
                        .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
                    let filename = "\(number)_\(cleanCategory.isEmpty ? "sound" : cleanCategory)_\(name).wav"
                    try AudioConverter.convert(source: sample, destination: kitFolder.appendingPathComponent(filename))
                    filenames.append(filename)
                }
                let text = makeMapping(name: name, filenames: filenames)
                try text.write(to: kitFolder.appendingPathComponent("\(name).eldrum"), atomically: true, encoding: .utf8)
                try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                let zip = output.appendingPathComponent("\(name).zip")
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                process.arguments = ["-c", "-k", "--keepParent", kitFolder.path, zip.path]
                try process.run(); process.waitUntilExit()
                guard process.terminationStatus == 0 else { throw ForgeError.zipFailed }
                try? FileManager.default.removeItem(at: temp)
            } catch {
                try? FileManager.default.removeItem(at: temp)
                throw error
            }
            progress(index + 1)
        }
    }

    static func makeMapping(name: String, filenames: [String]) -> String {
        var lines = ["# ELEKTRON DRUM SET MAPPING FORMAT", "version = 0", "name = \"\(name)\"", ""]
        for i in 0..<8 {
            lines += ["[[key-zones]]", "pitch = \(notePitches[i])", "key-center = \(notePitches[i]).0", "",
                      "[[key-zones.velocity-layers]]", "velocity = 0.24705882", "strategy = 'Forward'", "",
                      "[[key-zones.velocity-layers.sample-slots]]", "sample = \"\(filenames[i])\"", ""]
        }
        return lines.joined(separator: "\n")
    }
}

enum ForgeError: LocalizedError {
    case emptySlot(Int, String), zipFailed
    var errorDescription: String? {
        switch self {
        case .emptySlot(let index, let category): return "No WAV files found in slot \(index) (\(category))."
        case .zipFailed: return "macOS could not create a ZIP archive."
        }
    }
}

enum AudioConverter {
    static func convert(source: URL, destination: URL) throws {
        let file = try AVAudioFile(forReading: source)
        let sourceFormat = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0, let input = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount) else {
            throw NSError(domain: "TonverkKitForge", code: 1, userInfo: [NSLocalizedDescriptionKey: "Empty or unsupported WAV: \(source.lastPathComponent)"])
        }
        try file.read(into: input)
        guard let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: sourceFormat, to: outputFormat) else {
            throw NSError(domain: "TonverkKitForge", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not initialize 48 kHz mono conversion"])
        }
        let capacity = AVAudioFrameCount(ceil(Double(input.frameLength) * 48_000 / sourceFormat.sampleRate)) + 16
        guard let converted = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            throw NSError(domain: "TonverkKitForge", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not allocate audio buffer"])
        }
        var supplied = false
        var conversionError: NSError?
        let status = converter.convert(to: converted, error: &conversionError) { _, inputStatus in
            if supplied { inputStatus.pointee = .noDataNow; return nil }
            supplied = true
            inputStatus.pointee = .haveData
            return input
        }
        if let conversionError { throw conversionError }
        guard status != .error, let samples = converted.floatChannelData?[0], converted.frameLength > 0 else {
            throw NSError(domain: "TonverkKitForge", code: 4, userInfo: [NSLocalizedDescriptionKey: "Audio resampling failed"])
        }
        var peak: Float = 0
        for i in 0..<Int(converted.frameLength) { peak = max(peak, abs(samples[i])) }
        let gain: Float = peak == 0 ? 1 : min(Float(pow(10.0, -0.3 / 20.0)) / peak, 1_000_000)
        var pcm = Data(capacity: Int(converted.frameLength) * 3)
        for i in 0..<Int(converted.frameLength) {
            let normalized = max(-1.0, min(1.0, Double(samples[i] * gain)))
            var value = Int32((normalized * 8_388_607).rounded())
            if value < 0 { value += 1 << 24 }
            pcm.append(UInt8(value & 0xff)); pcm.append(UInt8((value >> 8) & 0xff)); pcm.append(UInt8((value >> 16) & 0xff))
        }
        var wav = wavHeader(dataBytes: UInt32(pcm.count))
        wav.append(pcm)
        try wav.write(to: destination, options: .atomic)
    }

    private static func wavHeader(dataBytes: UInt32) -> Data {
        var data = Data()
        func append<T: FixedWidthInteger>(_ number: T) {
            var value = number.littleEndian
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("RIFF".utf8)); append(dataBytes + 36)
        data.append(contentsOf: Array("WAVEfmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(48_000)); append(UInt32(144_000)); append(UInt16(3)); append(UInt16(24))
        data.append(contentsOf: Array("data".utf8)); append(dataBytes)
        return data
    }
}
