import Foundation

// Parses nettop CSV: `name.pid,bytes_in,bytes_out,`
// The header line (`,bytes_in,bytes_out,`) has no process, so it's skipped.
// pid is split on the LAST dot, since process names can contain dots.
enum NettopParser {
    static func parse(_ output: String) -> [ProcessSample] {
        var samples: [ProcessSample] = []
        for line in output.split(separator: "\n") {
            let f = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 3 else { continue }

            let proc = f[0]
            guard let dot = proc.lastIndex(of: "."),
                  let pid = Int(proc[proc.index(after: dot)...]) else { continue }
            let name = String(proc[..<dot])
            guard !name.isEmpty,
                  let bytesIn = Int(f[1].trimmingCharacters(in: .whitespaces)),
                  let bytesOut = Int(f[2].trimmingCharacters(in: .whitespaces)) else { continue }

            samples.append(ProcessSample(name: name, pid: pid, bytesIn: bytesIn, bytesOut: bytesOut))
        }
        return samples
    }
}
