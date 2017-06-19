import Foundation
import Boot
func main() {

    guard let currnetFolder = ProcessInfo.processInfo.environment["PWD"] else { return }
    let target = "RocketBoot.yaml"
    if CommandLine.argc < 2 {
        let contents = try? FileManager.default.contentsOfDirectory(atPath: currnetFolder)
        if contents?.contains(target) == true {
            let file = currnetFolder.appending("/\(target)")
            RocketBoot(configFile: file)?.generate()
        } else {
            RocketBoot.noFile()
            RocketBoot.showUsage()
        }
    } else {
        let path = CommandLine.arguments[1]
        let command = RocketBoot.Command(rawValue: path)
        command?.execute()
    }
}

main()
