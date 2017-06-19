//
//  Log.swift
//  RocketBoot
//
//  Created by Lincoln Law on 2017/6/16.
//
//
import Foundation
import ColorizeSwift

struct RocketLog {
    private enum Mode { case info, warning, error, debug }
    static func info(_ messag: CustomStringConvertible) { _log(messag, mode: .info) }
    static func debug(_ messag: CustomStringConvertible) { _log(messag, mode: .debug) }
    static func warning(_ messag: CustomStringConvertible) { _log(messag, mode: .warning) }
    static func error(_ messag: CustomStringConvertible) { _log(messag, mode: .error) }
    private static func _log(_ messag: CustomStringConvertible, mode: Mode) {
        let item = messag.description
        switch mode {
        case .debug: print("[Debug]".lightMagenta(), " ", item.darkGray())
        case .info: print("[Info]".green(), "  ", item.lightGray())
        case .warning: print("[Waring]".lightYellow(), item.lightGray())
        case .error: print("[Error]".red(), " ", item.red())
        }
    }

    static func usage() {
        print("usage:\n\tcd [the folder where RocketBoot.yaml file located] && ".darkGray(), "rocketboot".white())
        let version = "\t\tDisplay the current version of RocketBoot"
        let help = "\t\t\tusage of RocketBoot"
        let initialize = "\t\t\tinit a RocketBoot.yaml in current folder"
        print("Available commands:".darkGray(), "\n\tversion".white(), version.darkGray(), "\n\thelp".white(), help.darkGray(), "\n\tinit".white(), initialize.darkGray())
    }
}
