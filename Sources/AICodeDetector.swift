import Foundation
import Vision
import CoreML
import NaturalLanguage
import AppKit

@MainActor
class AICodeDetector: ObservableObject {
    static let shared = AICodeDetector()
    
    // 是否启用AI识别
    @Published var isEnabled = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "aiDetectionEnabled")
        }
    }
    
    // 使用NLP分析器识别验证码模式
    private let tagger = NLTagger(tagSchemes: [.tokenType])
    
    init() {
        // 从UserDefaults加载设置
        isEnabled = UserDefaults.standard.bool(forKey: "aiDetectionEnabled")
    }
    
    // 识别验证码
    func detectVerificationCode(in text: String) -> String? {
        guard isEnabled else { return nil }
        
        // 使用NLP分析文本
        tagger.string = text
        
        // 查找数字序列
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .omitOther]
        var potentialCodes: [String] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .tokenType, options: options) { tag, tokenRange in
            if tag == .number {
                let token = String(text[tokenRange])
                if token.count >= 4 && token.count <= 8 {
                    potentialCodes.append(token)
                }
            }
            return true
        }
        
        // 使用上下文分析找到最可能的验证码
        return findMostLikelyCode(potentialCodes, originalText: text)
    }
    
    // 分析上下文找出最可能的验证码
    private func findMostLikelyCode(_ candidates: [String], originalText: String) -> String? {
        guard !candidates.isEmpty else { return nil }
        
        // 验证码关键词（多语言支持）
        let codeKeywords = ["验证码", "code", "verification", "認証", "인증", "コード"]
        
        // 为每个候选项评分
        let scoredCandidates = candidates.map { code -> (String, Double) in
            var score = 0.0
            
            // 长度评分（6位验证码最常见）
            let lengthScore = code.count == 6 ? 1.0 : (code.count == 4 ? 0.8 : 0.5)
            
            // 上下文评分
            let contextScore = codeKeywords.reduce(0.0) { score, keyword in
                if originalText.lowercased().contains(keyword.lowercased()) {
                    return score + 1.0
                }
                return score
            }
            
            // 纯数字评分
            let digitScore = code.allSatisfy { $0.isNumber } ? 1.0 : 0.2
            
            // 距离最近关键词的距离评分
            var minDistance = Double.infinity
            for keyword in codeKeywords {
                if let range = originalText.lowercased().range(of: keyword.lowercased()),
                   let codeRange = originalText.range(of: code) {
                    let distance = originalText.distance(from: range.upperBound, to: codeRange.lowerBound)
                    if distance >= 0 && Double(distance) < minDistance {
                        minDistance = Double(distance)
                    }
                }
            }
            let distanceScore = minDistance == Double.infinity ? 0.0 : (1.0 / (1.0 + minDistance / 10.0))
            
            score = lengthScore + contextScore + digitScore + distanceScore
            return (code, score)
        }
        
        // 返回得分最高的候选项
        return scoredCandidates.sorted { $0.1 > $1.1 }.first?.0
    }
    
    // 使用Vision框架进行高级文本识别（适用于图像通知）
    func recognizeTextInImage(_ image: NSImage) -> String? {
        guard isEnabled else { return nil }
        
        var imageRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        guard let cgImage = image.cgImage(forProposedRect: &imageRect, context: nil, hints: nil) else {
            return nil
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        
        do {
            try requestHandler.perform([request])
            if let results = request.results {
                let recognizedStrings = results.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                // 合并所有识别的文本
                let fullText = recognizedStrings.joined(separator: " ")
                return detectVerificationCode(in: fullText)
            }
        } catch {
            print("文本识别失败: \(error.localizedDescription)")
        }
        
        return nil
    }
} 