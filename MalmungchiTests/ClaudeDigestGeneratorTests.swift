import Foundation
import Testing
@testable import Malmungchi

/// 네트워크 대신 미리 정한 응답을 돌려주고, 나간 요청을 기록한다.
final class StubURLProtocol: URLProtocol {
    struct Reply {
        var status = 200
        var body: Data = Data()
        var error: Error?
    }

    nonisolated(unsafe) static var replies: [Reply] = []
    nonisolated(unsafe) static var requests: [(request: URLRequest, body: Data)] = []

    static func reset(_ replies: [Reply]) {
        self.replies = replies
        requests = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.append((request, Self.readBody(of: request)))
        let reply = Self.replies.isEmpty ? Reply(status: 500) : Self.replies.removeFirst()

        if let error = reply.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readBody(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

@Suite("ClaudeDigestGenerator", .serialized)
struct ClaudeDigestGeneratorTests {
    private let recordingID = UUID()

    private var input: DigestInput {
        DigestInput(
            date: Fixtures.date(2026, 11, 4),
            entries: [
                DigestInput.Entry(
                    number: 1,
                    recordingID: recordingID,
                    startedAt: Fixtures.date(2026, 11, 4, 9, 12),
                    segments: [
                        TranscriptSegment(start: 5, end: 9, text: "금요일까지 견적서를 보내기로 했어요."),
                        TranscriptSegment(start: 70, end: 75, text: "디자인은 외주로 하기로 했습니다."),
                    ]
                ),
            ]
        )
    }

    private func makeGenerator(key: String? = "sk-ant-test", maxInputCharacters: Int = 60_000) -> ClaudeDigestGenerator {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return ClaudeDigestGenerator(
            apiKeys: InMemoryAPIKeyStore(key: key),
            session: URLSession(configuration: configuration),
            model: "test-model",
            maxInputCharacters: maxInputCharacters,
            timeZone: Fixtures.seoul
        )
    }

    private func toolUse(_ input: [String: Any], id: String = "toolu_1") -> StubURLProtocol.Reply {
        reply(content: [["type": "tool_use", "id": id, "name": "save_daily_digest", "input": input]])
    }

    private func reply(content: [[String: Any]]) -> StubURLProtocol.Reply {
        let body = try! JSONSerialization.data(withJSONObject: ["content": content, "stop_reason": "tool_use"])
        return StubURLProtocol.Reply(status: 200, body: body)
    }

    private var validInput: [String: Any] {
        [
            "diary": "오늘은 견적 이야기를 했다.",
            "todos": [["text": "견적서 보내기", "due": "금요일", "recording": 1, "at": 5]],
            "decisions": [["text": "디자인은 외주로 한다", "recording": 1, "at": 70]],
        ]
    }

    private func requestJSON(_ index: Int = 0) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: StubURLProtocol.requests[index].body) as? [String: Any])
    }

    @Test("성공하면 정리 내용을 돌려주고 출처를 녹음 id로 바꾼다")
    func success() async throws {
        StubURLProtocol.reset([toolUse(validInput)])

        let content = try await makeGenerator().generate(from: input)

        #expect(content.diary == "오늘은 견적 이야기를 했다.")
        #expect(content.todos.first?.due == "금요일")
        #expect(content.todos.first?.source == DigestSource(recordingID: recordingID, time: 5))
        #expect(content.decisions.first?.source == DigestSource(recordingID: recordingID, time: 70))
        #expect(StubURLProtocol.requests.count == 1)
    }

    @Test("요청에 주소, 헤더, 모델, 강제 도구 호출이 들어간다")
    func requestShape() async throws {
        StubURLProtocol.reset([toolUse(validInput)])
        _ = try await makeGenerator().generate(from: input)

        let sent = StubURLProtocol.requests[0].request
        #expect(sent.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(sent.httpMethod == "POST")
        #expect(sent.value(forHTTPHeaderField: "x-api-key") == "sk-ant-test")
        #expect(sent.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")

        let json = try requestJSON()
        #expect(json["model"] as? String == "test-model")
        let choice = try #require(json["tool_choice"] as? [String: String])
        #expect(choice == ["type": "tool", "name": "save_daily_digest"])
        let tools = try #require(json["tools"] as? [[String: Any]])
        #expect(tools.first?["name"] as? String == "save_daily_digest")
    }

    @Test("받아쓰기 텍스트와 시각만 보내고 id·파일·제목·기기 정보는 보내지 않는다")
    func requestContainsOnlyTranscriptText() async throws {
        StubURLProtocol.reset([toolUse(validInput)])
        _ = try await makeGenerator().generate(from: input)

        let body = String(decoding: StubURLProtocol.requests[0].body, as: UTF8.self)
        #expect(body.contains("금요일까지 견적서를 보내기로 했어요."))
        #expect(body.contains("[00:05]"))
        #expect(body.contains("[녹음 1] 09:12 시작"))

        #expect(!body.contains(recordingID.uuidString))
        #expect(!body.lowercased().contains(".m4a"))
        #expect(!body.contains("/Documents"))
        #expect(!body.contains("/var/"))
        #expect(!body.contains("iPhone"))

        let keys = Set(try requestJSON().keys)
        #expect(keys == ["model", "max_tokens", "system", "messages", "tools", "tool_choice"])
    }

    @Test("키가 없으면 요청 없이 안내한다")
    func missingKey() async {
        StubURLProtocol.reset([])
        await #expect(throws: DigestGenerationError.missingAPIKey) {
            try await makeGenerator(key: nil).generate(from: input)
        }
        #expect(StubURLProtocol.requests.isEmpty)
    }

    @Test("너무 긴 입력은 요청 없이 알린다")
    func inputTooLong() async {
        StubURLProtocol.reset([])
        await #expect(throws: DigestGenerationError.inputTooLong) {
            try await makeGenerator(maxInputCharacters: 50).generate(from: input)
        }
        #expect(StubURLProtocol.requests.isEmpty)
    }

    @Test("401은 키 오류, 429는 한도 초과로 구분한다")
    func statusMapping() async {
        StubURLProtocol.reset([.init(status: 401)])
        await #expect(throws: DigestGenerationError.unauthorized) {
            try await makeGenerator().generate(from: input)
        }

        StubURLProtocol.reset([.init(status: 429)])
        await #expect(throws: DigestGenerationError.rateLimited) {
            try await makeGenerator().generate(from: input)
        }
    }

    @Test("그 밖의 오류는 서버 메시지를 담아 알린다")
    func otherStatusCarriesMessage() async {
        let body = Data(#"{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#.utf8)
        StubURLProtocol.reset([.init(status: 529, body: body)])
        await #expect(throws: DigestGenerationError.requestFailed(status: 529, message: "Overloaded")) {
            try await makeGenerator().generate(from: input)
        }
    }

    @Test("연결이 끊기면 네트워크 오류로 알린다")
    func networkError() async {
        StubURLProtocol.reset([.init(error: URLError(.notConnectedToInternet))])
        do {
            _ = try await makeGenerator().generate(from: input)
            Issue.record("실패해야 해요")
        } catch let error as DigestGenerationError {
            if case .network = error {} else { Issue.record("다른 에러: \(error)") }
        } catch {
            Issue.record("다른 에러: \(error)")
        }
    }

    @Test("형식이 틀리면 무엇이 틀렸는지 알려 주며 한 번 다시 묻고, 고쳐지면 성공한다")
    func retriesOnceWithFeedback() async throws {
        StubURLProtocol.reset([
            toolUse(["todos": []], id: "toolu_bad"),
            toolUse(validInput, id: "toolu_good"),
        ])

        let content = try await makeGenerator().generate(from: input)

        #expect(content.diary == "오늘은 견적 이야기를 했다.")
        #expect(StubURLProtocol.requests.count == 2)

        let messages = try #require(try requestJSON(1)["messages"] as? [[String: Any]])
        #expect(messages.count == 3)
        #expect(messages[1]["role"] as? String == "assistant")
        let feedback = try #require((messages[2]["content"] as? [[String: Any]])?.first)
        #expect(feedback["type"] as? String == "tool_result")
        #expect(feedback["tool_use_id"] as? String == "toolu_bad")
        #expect(feedback["is_error"] as? Bool == true)
        #expect((feedback["content"] as? String)?.contains("diary") == true)
    }

    @Test("도구 호출 없이 글로만 답해도 한 번 다시 묻는다")
    func retriesOnTextOnlyReply() async throws {
        StubURLProtocol.reset([
            reply(content: [["type": "text", "text": "정리할 수 없어요"]]),
            toolUse(validInput),
        ])

        _ = try await makeGenerator().generate(from: input)

        #expect(StubURLProtocol.requests.count == 2)
    }

    @Test("두 번 다 읽지 못하면 원문과 함께 실패한다")
    func failsAfterSecondInvalidResponse() async {
        StubURLProtocol.reset([
            toolUse(["diary": "  "], id: "a"),
            toolUse(["todos": []], id: "b"),
        ])

        do {
            _ = try await makeGenerator().generate(from: input)
            Issue.record("실패해야 해요")
        } catch let error as DigestGenerationError {
            if case .invalidResponse(_, let raw) = error {
                #expect(raw.contains("save_daily_digest"))
            } else {
                Issue.record("다른 에러: \(error)")
            }
        } catch {
            Issue.record("다른 에러: \(error)")
        }
        #expect(StubURLProtocol.requests.count == 2)
    }
}
