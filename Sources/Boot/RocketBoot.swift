//
//  Log.swift
//  RocketBoot
//
//  Created by Lincoln Law on 2017/6/16.
//
//

import Yaml
import Foundation

public final class RocketBoot {

    private static var _user: String = ""
    private static var _isXcode9 = true
    private static var _tool: ToolType = .punic

    public enum ToolType: String {
        case carthage
        case punic

        func archPath(for repo: Repository) -> [Arch: [String]] {
            var result: [Arch: [String]] = [:]
            let modes: [ReleaseMode] = [.iPhoneos, .iPhonesimulator]
            if self == .punic {
                let intermediates = "\(basePath)/Intermediates\(RocketBoot._isXcode9 ? ".noindex" : "")"
                for mode in modes {
                    let archs = mode.availableArch
                    for arch in archs {
                        var old = result[arch] ?? []
                        old.append("\(intermediates)/\(repo.xcproject).build/\(mode.rawValue)/\(repo.scheme).build/\(arch.path)")
                        result[arch] = old
                    }
                }
            } else if self == .carthage {
                let base = "\(basePath)/DerivedData/\(repo.xcproject)"
                let intermediates = "Intermediates\(RocketBoot._isXcode9 ? ".noindex" : "")"
                do {
                    var tags = try FileManager.default.contentsOfDirectory(atPath: base)
                    if tags.count < 0 {
                        RocketLog.info("no tag for:\(repo.scheme) builded in carthage")
                    } else {
                        var latest: String = ""
                        if let tag = repo.tag {
                            latest = tag
                        } else {
                            if tags.count > 1 {
                                tags.sort(by: { $0 < $1 })
                                latest = tags.last!
                            } else if tags.count == 1 {
                                latest = tags.first!
                            }
                        }
                        RocketLog.info("using tag <\(latest)> for [\(repo.scheme)] within \(tags)")
                        let tagPath = "\(base)/\(latest)/Build/\(intermediates)/\(repo.xcproject).build/"
                        for mode in modes {
                            let archs = mode.availableArch
                            for arch in archs {
                                var old = result[arch] ?? []
                                old.append("\(tagPath)/\(mode.rawValue)/\(repo.scheme).build/\(arch.path)")
                                result[arch] = old
                            }
                        }
                    }
                } catch {
                    RocketLog.info("error for getting sub folder for:\(base), error:\(error.localizedDescription)")
                    exit(0)
                }
            }
            return result
        }

        var basePath: String {
            if self == .punic {
                return "/Users/\(RocketBoot._user)/Library/Application Support/io.schwa.Punic/DerivedData/Build"
            } else if self == .carthage {
                return "/Users/\(RocketBoot._user)/Library/Caches/org.carthage.CarthageKit"
            }
            return ""
        }
    }

    public enum Command: String {
        case version
        case help
        case initialize = "init"

        public func execute() {
            switch self {
            case .version: RocketBoot.showVersion()
            case .help: RocketBoot.showUsage()
            case .initialize: RocketBoot.initFile()
            }
        }
    }

    static let version = "0.0.1"

    public enum ReleaseMode: String {
        case iPhoneos = "Release-iphoneos"
        case iPhonesimulator = "Release-iphonesimulator"
        var availableArch: [Arch] {
            switch self {
            case .iPhoneos: return [.arm64, .armv7]
            case .iPhonesimulator: return [.i386, .x86_64]
            }
        }
    }

    public enum Arch: String {
        case arm64, armv7, i386, x86_64
        func add(lines: [String], to map: inout [Arch: [String]]) {
            var pool = map[self] ?? []
            pool.append(contentsOf: lines)
            map[self] = pool
        }

        var path: String { return "Objects-normal".appendingPathComponent(rawValue) }

        func save(lines: [String]?, to folder: String) {
            guard let final = lines?.filter({ $0.isEmpty == false }).joined(separator: "\n").data(using: .utf8) else {
                RocketLog.info("no lines for:\(rawValue), skip")
                return
            }
            do {
                let raw = filePath(relateto: folder)
                let url = URL(fileURLWithPath: raw)
                try final.write(to: url)
                RocketLog.info("saved \(lines?.count ?? 0) lines for:\(rawValue)")
            } catch {
                RocketLog.error(error.localizedDescription)
                exit(0)
            }
        }

        func filePath(relateto folder: String) -> String {
            return folder.appendingPathComponent(rawValue) + ".filelist"
        }
    }

    private var _rootPath: String
    private var _outputFolder: String
    private var _configItems: [Repository] = []
    private var _archLine: [Arch: [String]] = [:]
    private var _relativeOutput: String?
    public init?(configFile path: String) {
        do {
            _rootPath = (path as NSString).deletingLastPathComponent
            _outputFolder = _rootPath.appendingPathComponent("RocketBoot")
            RocketLog.info("working in:\(_rootPath)")
            RocketLog.info("output folder:\(_outputFolder)")
            let content = try String(contentsOfFile: path)
            let dict = try Yaml.load(content)
            RocketBoot._user = ProcessInfo.processInfo.environment["USER"]!
            if let xcode9 = dict["xcode9"].bool {
                RocketBoot._isXcode9 = xcode9
            }
            guard let toolraw = dict["tool"].string?.lowercased() else {
                RocketLog.error("Not config tool")
                exit(0)
            }
            guard let tool = ToolType(rawValue: toolraw) else {
                RocketLog.error("wrong tool value, should be carthage or punic")
                exit(0)
            }
            RocketBoot._tool = tool
            if let output = dict["OutputFolder"].string {
                _relativeOutput = output
                _outputFolder = _rootPath.appendingPathComponent(output)
            }
            guard let raw = dict["repos"].array else {
                RocketLog.error("Not config repos")
                exit(0)
            }
            let list = raw.flatMap({ $0.array }).flatMap({ Repository(items: $0) })
            guard list.count > 0 else {
                RocketLog.warning("repos is empty")
                exit(0)
            }
            let fm = FileManager.default
            if fm.fileExists(atPath: _outputFolder) == false {
                try fm.createDirectory(atPath: _outputFolder, withIntermediateDirectories: false, attributes: nil)
            }
            _configItems = list
        } catch {
            RocketLog.error(error.localizedDescription)
            exit(0)
        }
    }

    public func generate() {
        generateFilelist()
        generateXcconfig()
    }

    private func generateFilelist() {
        RocketLog.info("start to generate filelist")
        let fm = FileManager.default
        for item in _configItems {
            let folder = RocketBoot._tool.archPath(for: item)
            for (arch, folders) in folder {
                for folder in folders {
                    do {
                        let oFiles = try fm.contentsOfDirectory(atPath: folder).flatMap({ (file) -> String? in
                            if file.hasSuffix(".o") { return folder.appendingPathComponent(file) }
                            return nil
                        })
                        arch.add(lines: oFiles, to: &_archLine)
                    } catch {
//                        RocketLog.error("folder:\(folder), \(error.localizedDescription)")
                        continue
                    }
                }
            }
        }
        for (arch, value) in _archLine {
            arch.save(lines: value, to: _outputFolder)
        }
        RocketLog.info("generate filelist done")
    }

    private func generateXcconfig() {
        let archs: [Arch] = [.arm64, .armv7, .i386, .x86_64]
        var total = "FRAMEWORK_SEARCH_PATHS = $(inherited) $(PROJECT_DIR)/Carthage/Build/iOS\n"
        total += "LD_RUNPATH_SEARCH_PATHS = $(inherited) @loader_path/Frameworks\n"
        let output = _relativeOutput ?? "RocketBoot"
        for arch in archs {
            if _archLine[arch]?.count == 0 { continue }
            let archRaw = arch.rawValue
            total += "OTHER_LDFLAGS[arch=\(archRaw)] = $(inherited) -filelist $(SRCROOT)/\(output)/\(archRaw).filelist\n"
        }
        let xcconfig = _outputFolder.appendingPathComponent("RocketBoot.xcconfig")
        let url = URL(fileURLWithPath: xcconfig)
        do {
            try total.data(using: .utf8)?.write(to: url)
        } catch {
            RocketLog.error(error.localizedDescription)
        }
    }

    public static func showVersion() { print("RocketBoot version: \(version)".white()) }
    public static func showUsage() { RocketLog.usage() }
    public static func noFile() { RocketLog.warning("No RocketBoot.yaml found in current folder") }
    public static func initFile() {
        guard let currnetFolder = ProcessInfo.processInfo.environment["PWD"] else {
            RocketLog.error("no PWD in environment")
            return
        }
        let raw = """
        tool: punic # carthage or punic, default is punic
        xcode9: true # true or false, default is true
        repos:
        #  xcodeproj Name; Scheme Name; Optional Tag, if using carthage and not setting tag, will using the latest tag build;
        # - [ Alamofire, Alamofire iOS ] or - [ Alamofire, Alamofire iOS, 4.0.0 ]
        """
        let path = currnetFolder.appendingPathComponent("RocketBoot.yaml")
        let url = URL(fileURLWithPath: path)
        try? raw.data(using: .utf8)?.write(to: url)
        RocketLog.info("🍻 RocketBoot init done")
    }
}

public struct Repository {
    public let xcproject: String
    public let scheme: String
    public let tag: String?

    public init?(items: [Yaml]) {
        guard let xcproject_ = items[safe: 0]?.string, let scheme_ = items[safe: 1]?.string else {
            print("bad format:\(items)")
            return nil
        }
        xcproject = xcproject_
        scheme = scheme_
        tag = items[safe: 2]?.string
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices ~= index ? self[index] : nil
    }
}

extension String {
    func appendingPathComponent(_ component: String) -> String {
        return (self as NSString).appendingPathComponent(component)
    }
}
