import Foundation
import Vision
import AppKit

@MainActor
class VisionCodeDetector: ObservableObject {
    static let shared = VisionCodeDetector()
    
    @Published var isProcessing = false
    
    private init() {}
    
    /// 从图像中提取验证码
    func extractCode(from image: NSImage) async -> String? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("无法转换图像为 CGImage")
            return nil
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // 创建文本识别请求
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-CN", "en-US"]
        request.usesLanguageCorrection = false
        
        // 执行请求
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            
            // 获取识别结果
            guard let observations = request.results else { return nil }
            
            // 收集所有识别到的文本
            var fullText = ""
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                fullText += topCandidate.string + " "
            }
            
            // 使用 CodeManager 的提取逻辑来识别验证码
            if let code = CodeManager.shared.extractCode(from: fullText) {
                return code
            }
            
            // 如果常规提取失败，尝试查找独立的数字序列
            let pattern = "\\b[0-9０-９]{4,8}\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: fullText, options: [], range: NSRange(fullText.startIndex..., in: fullText)) {
                let matchedRange = Range(match.range, in: fullText)!
                let code = String(fullText[matchedRange])
                
                // 转换全角数字为半角
                let normalizedCode = code.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? code
                return normalizedCode.replacingOccurrences(of: "[\\s-]", with: "", options: .regularExpression)
            }
            
        } catch {
            print("图像文本识别失败: \(error)")
        }
        
        return nil
    }
}

// 扩展来支持从剪贴板获取图像
extension VisionCodeDetector {
    /// 从剪贴板中检查图像并提取验证码
    func checkClipboardForImage() async -> String? {
        let pasteboard = NSPasteboard.general
        
        // 检查剪贴板是否包含图像
        guard pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) else {
            return nil
        }
        
        // 获取图像
        guard let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
              let image = images.first else {
            return nil
        }
        
        // 提取验证码
        return await extractCode(from: image)
    }
} 