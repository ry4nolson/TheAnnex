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
        
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        return ShellResult(
            output: output.trimmingCharacters(in: .whitespacesAndNewlines),
            exitCode: task.terminationStatus,
            error: nil
        )
    }
    
    @discardableResult
    static func runAsync(_ command: String, outputHandler: @escaping (String) -> Void, completion: @escaping (ShellResult) -> Void) -> Process {
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        
        DispatchQueue.global(qos: .utility).async {
            
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        outputHandler(output)
                    }
                }
            }
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let result = ShellResult(
                    output: "",
                    exitCode: task.terminationStatus,
                    error: nil
                )
                
                DispatchQueue.main.async {
                    completion(result)
                }
            } catch {
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
