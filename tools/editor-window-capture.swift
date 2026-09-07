import Foundation
import ScreenCaptureKit
import CoreMedia
import CoreVideo
import CoreImage
import ImageIO
import CryptoKit
import Darwin
import AppKit

func diagnostic(_ value: String) {
    FileHandle.standardError.write(Data((value + "\n").utf8))
}

final class Recorder: NSObject, SCStreamOutput {
    let directory: URL
    let log: FileHandle
    let context = CIContext()
    var sequence = 0
    init(_ directory: URL) throws {
        self.directory = directory
        FileManager.default.createFile(atPath: directory.appendingPathComponent("frames.jsonl").path, contents: nil)
        log = try FileHandle(forWritingTo: directory.appendingPathComponent("frames.jsonl"))
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sample: CMSampleBuffer, of type: SCStreamOutputType) {
        let observed = mach_absolute_time()
        guard type == .screen, sample.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let info = attachments.first,
              let status = info[.status] as? Int, status == SCFrameStatus.complete.rawValue,
              let displayed = info[.displayTime] as? NSNumber,
              let buffer = sample.imageBuffer else { return }
        let ci = CIImage(cvPixelBuffer: buffer)
        guard let image = context.createCGImage(ci, from: ci.extent),
              let pixels = image.dataProvider?.data else { return }
        let hash = SHA256.hash(data: pixels as Data).map { String(format: "%02x", $0) }.joined()
        let name = String(format: "frame-%05d.png", sequence)
        let path = directory.appendingPathComponent(name)
        guard let destination = CGImageDestinationCreateWithURL(path as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return }
        let record: [String: Any] = ["sequence": sequence, "displayTicks": displayed.uint64Value,
            "callbackTicks": observed, "persistedTicks": mach_absolute_time(), "sha256": hash,
            "png": name, "width": image.width, "height": image.height]
        if var data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]) {
            data.append(10); try? log.write(contentsOf: data)
        }
        sequence += 1
    }
}

@main struct Capture {
    @MainActor
    static func main() async throws {
        // A command-line process must establish its WindowServer connection
        // before ScreenCaptureKit/CoreImage work, including async callbacks.
        _ = NSApplication.shared
        NSApplication.shared.setActivationPolicy(.prohibited)
        diagnostic("AppKit initialized on main actor")
        let args = CommandLine.arguments
        guard args.count == 3, let id = UInt32(args[1]) else { fatalError("usage: capture WINDOW_ID OUTPUT_DIRECTORY") }
        let directory = URL(fileURLWithPath: args[2], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard CGPreflightScreenCaptureAccess() else { fatalError("Screen capture is not already granted; no permission request made") }
        diagnostic("Existing screen capture grant confirmed; enumerating windows")
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        guard let window = content.windows.first(where: { $0.windowID == id }) else { fatalError("Dedicated Terminal window is not on screen") }
        diagnostic("Found target window \(id), \(window.frame)")
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.width = Int(window.frame.width * 2)
        configuration.height = Int(window.frame.height * 2)
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.queueDepth = 8
        configuration.showsCursor = false // Mouse pointer only; terminal's drawn cursor remains.
        let recorder = try Recorder(directory)
        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try stream.addStreamOutput(recorder, type: .screen, sampleHandlerQueue: DispatchQueue(label: "editor.capture"))
        try await stream.startCapture()
        diagnostic("ScreenCaptureKit stream started")
        print("CAPTURE_READY"); fflush(stdout)
        while true { try await Task.sleep(nanoseconds: 1_000_000_000) }
    }
}
