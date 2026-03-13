import Foundation

class ShellHelper {
    @discardableResult
    static func run(_ command: String, timeout: TimeInterval? = nil) -> ShellResult {
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        
        do {
            try task.run()
        } catch {
            return ShellResult(output: "", exitCode: 1, error: error.localizedDescription)
        }
        
        if let timeout = timeout {
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if task.isRunning {
                    task.terminate()
                }
            }
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        return ShellResult(
            output: output.trimmingCharacters(in: .whitespacesAndNewlines),
            exitCode: task.terminationStatus,
            error: nil
        )
    }
    
    @discardableResult
    static func runAsync(_ command: String, outputHandler: @escaping ([String]) -> Void, completion: @escaping (ShellResult) -> Void) -> Process {
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        
        DispatchQueue.global(qos: .utility).async {
            var lineBuffer = ""
            var accumulatedOutput = ""
            let outputLock = NSLock()
            
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
                
                outputLock.lock()
                accumulatedOutput += chunk
                outputLock.unlock()
                
                lineBuffer += chunk
                
                var lines: [String] = []
                while let newlineRange = lineBuffer.range(of: "\n") {
                    let line = String(lineBuffer[lineBuffer.startIndex..<newlineRange.lowerBound])
                    lineBuffer = String(lineBuffer[newlineRange.upperBound...])
                    if !line.isEmpty {
                        lines.append(line)
                    }
                }
                
                if !lines.isEmpty {
                    outputHandler(lines)
                }
            }
            
            do {
                try task.run()
                task.waitUntilExit()
                
                pipe.fileHandleForReading.readabilityHandler = nil
                
                outputLock.lock()
                let finalOutput = accumulatedOutput
                outputLock.unlock()
                
                let result = ShellResult(
                    output: finalOutput,
                    exitCode: task.terminationStatus,
                    error: nil
                )
                
                DispatchQueue.main.async {
                    completion(result)
                }
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                
                let result = ShellResult(
                    output: "",
                    exitCode: 1,
                    error: error.localizedDescription
                )
                DispatchQueue.main.async {
                    completion(result)
                }
            }
        }
        
        return task
    }
}

struct ShellResult {
    let output: String
    let exitCode: Int32
    let error: String?
    
    var isSuccess: Bool {
        exitCode == 0
    }
}
