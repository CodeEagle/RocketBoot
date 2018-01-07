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
    public enum Platform: String { case iOS, Mac }
    private static var _user: String = ""
    private static var _isXcode9 = true
    private static var _tool: ToolType = .punic
    private static var _platform: Platform = .iOS
    public enum ToolType: String {
        case carthage
        case punic

        func archPath(for repo: Repository) -> [Arch: [String]] {
            var result: [Arch: [String]] = [:]
            let modes: [ReleaseMode] = RocketBoot._platform == .iOS ? [.iPhoneos, .iPhonesimulator] : [.Mac]
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
                
                var base = "\(basePath)/DerivedData/\(repo.xcproject)"
                var usingNewBase = false
                if FileManager.default.fileExists(atPath: base) == false {
                    do {
                        let xcodeVersionBuild = try RocketBoot.xcodeVertionBuild()
                        base = "\(basePath)/DerivedData/\(xcodeVersionBuild)/\(repo.project)"
                        usingNewBase = true
                    } catch {
                        RocketLog.error("wtf:\(error)")
                    }
                    
                }
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
                        var tagPath = "\(base)/\(latest)/Build/\(intermediates)/\(repo.xcproject).build"
                        var optionTagPath = tagPath
                        let simulaterPath = tagPath
                        if usingNewBase {
                            tagPath = "\(base)/\(latest)/Build/\(intermediates)/ArchiveIntermediates/\(repo.xcproject)/IntermediateBuildFilesPath/\(repo.xcproject).build"
                            optionTagPath = "\(base)/\(latest)/Build/\(intermediates)/ArchiveIntermediates/\(repo.scheme)/IntermediateBuildFilesPath/\(repo.xcproject).build"
                        }
                        for mode in modes {
                            let archs = mode.availableArch
                            for arch in archs {
                                var old = result[arch] ?? []
                                var pathToAdd = "\(tagPath)/\(mode.rawValue)/\(repo.scheme).build/\(arch.path)"
                                if FileManager.default.fileExists(atPath: pathToAdd) == false, usingNewBase {
                                    pathToAdd = "\(optionTagPath)/\(mode.rawValue)/\(repo.scheme).build/\(arch.path)"
                                }
                                if mode == .iPhonesimulator, usingNewBase {
                                    let pathToAdd = "\(simulaterPath)/\(mode.rawValue)/\(repo.scheme).build/\(arch.path)"
                                    old.append(pathToAdd)
                                    result[arch] = old
                                } else {
                                    old.append(pathToAdd)
                                    result[arch] = old
                                }
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

    static let version = "0.0.2"

    public enum ReleaseMode: String {
        case Mac = "Release"
        case iPhoneos = "Release-iphoneos"
        case iPhonesimulator = "Release-iphonesimulator"
        var availableArch: [Arch] {
            switch self {
            case .Mac: return [.x86_64]
            case .iPhoneos: return [.arm64, .armv7]
            case .iPhonesimulator: return [.i386, .x86_64]
            }
        }
    }

    public enum Arch: String {
        case arm64, armv7, i386, x86_64
        func add(lines: [String], to map: inout [Arch: [String]]) {
            var pool = map[self] ?? []
            let filters = lines.filter({ pool.contains($0) == false })
            pool.append(contentsOf: filters)
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
            if let value = dict["platform"].string {
                if let platform = Platform(rawValue: value) {
                    RocketBoot._platform = platform
                } else {
                    RocketLog.error("Not Supported Platform:\(value), using iOS / Mac")
                    exit(0)
                }
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
                        RocketLog.error("folder:\(folder), \(error.localizedDescription)")
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
        var total = "FRAMEWORK_SEARCH_PATHS = $(inherited) $(PROJECT_DIR)/Carthage/Build/\(RocketBoot._platform.rawValue)\n"
        total += "LD_RUNPATH_SEARCH_PATHS = $(inherited) @loader_path/Frameworks\n"
        let output = _relativeOutput ?? "RocketBoot"
        for arch in archs {
            let count = _archLine[arch]?.count ?? 0
            guard count != 0 else { continue }
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
        platform: iOS # or Mac
        repos:
        # project name, last path component of your repo url, such as git@github.com:realm/realm-cocoa.git, realm-cocoa is project name; xcodeproj Name; Scheme Name; Optional Tag, if using carthage and not setting tag, will using the latest tag build;
        # - [ realm-cocoa, Realm, RealmSwift ] or - [ realm-cocoa, Realm, RealmSwift, v1.0.6 ]
        """
        let path = currnetFolder.appendingPathComponent("RocketBoot.yaml")
        let url = URL(fileURLWithPath: path)
        try? raw.data(using: .utf8)?.write(to: url)
        RocketLog.info("🍻 RocketBoot init done")
    }
    
    static func xcodeSelectPath() throws ->  String {
        let task:Process = Process()
        let pipe:Pipe = Pipe()
        
        task.launchPath = "/usr/bin/xcode-select"
        task.arguments = ["-p"]
        task.standardOutput = pipe
        task.environment = ProcessInfo.processInfo.environment
        task.launch()
        task.waitUntilExit()
        
        let handle = pipe.fileHandleForReading
        let data = handle.readDataToEndOfFile()
        guard let result_s = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "com.selfstudio.rocketboot", code: 1, userInfo: ["desc" : "no value from xcode-select -p"]) as Error
        }
        return result_s
    }
    
    static func xcodeVertionBuild() throws -> String {
        do {
            let path = (try xcodeSelectPath() as NSString).deletingLastPathComponent
            let versionPlist = "\(path)/version.plist"
            let url = URL(fileURLWithPath: versionPlist)
            let json = NSDictionary(contentsOf: url)
            guard let version = json?["CFBundleShortVersionString"] as? String,
                let build = json?["ProductBuildVersion"] as? String else {
                   throw NSError(domain: "com.selfstudio.rocketboot", code: 2, userInfo: ["desc" : "no version/build from \(versionPlist)"]) as Error
            }
            return "\(version)_\(build)"
        } catch {
            throw error
        }
        
    }
}

public struct Repository {
    public let project: String
    public let xcproject: String
    public let scheme: String
    public let tag: String?

    public init?(items: [Yaml]) {
        guard let project_ = items[safe: 0]?.string, let xcproject_ = items[safe: 1]?.string, let scheme_ = items[safe: 2]?.string else {
            print("bad format:\(items)")
            return nil
        }
        project = project_
        xcproject = xcproject_
        scheme = scheme_
        tag = items[safe: 3]?.string
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
