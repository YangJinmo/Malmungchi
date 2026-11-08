import Foundation

/// LLM API 키 보관소. 키는 코드·저장소·로그에 남기지 않고 이 프로토콜 뒤(Keychain)에만 둔다.
protocol APIKeyStoring: AnyObject {
    /// 저장된 키. 없으면 nil.
    func load() throws -> String?
    func save(_ key: String) throws
    func delete() throws
}
