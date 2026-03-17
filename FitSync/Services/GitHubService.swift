import Foundation

enum GitHubError: LocalizedError {
    case notConfigured
    case invalidToken
    case repoNotFound
    case noWritePermission
    case conflict
    case networkError(String)
    case serverError(Int, String)
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured: "GitHub 未配置"
        case .invalidToken: "Token 无效或已过期"
        case .repoNotFound: "仓库不存在"
        case .noWritePermission: "Token 无写入权限，需要 Contents read/write"
        case .conflict: "文件冲突，请重试"
        case .networkError(let msg): "网络错误：\(msg)"
        case .serverError(let code, let msg): "服务器错误 \(code)：\(msg)"
        case .encodingFailed: "数据编码失败"
        }
    }
}

final class GitHubService {
    private let session = URLSession.shared
    private let baseURL = "https://api.github.com"
    private let timeoutInterval: TimeInterval = 30

    // MARK: - Connection Test

    func testConnection(owner: String, repo: String, token: String) async throws {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)")!
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await performRequest(request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        switch statusCode {
        case 200:
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let permissions = json["permissions"] as? [String: Any],
               let push = permissions["push"] as? Bool, push {
                return
            }
            throw GitHubError.noWritePermission
        case 401, 403:
            throw GitHubError.invalidToken
        case 404:
            throw GitHubError.repoNotFound
        default:
            throw GitHubError.serverError(statusCode, HTTPURLResponse.localizedString(forStatusCode: statusCode))
        }
    }

    // MARK: - List Directory

    func listFiles(owner: String, repo: String, token: String, path: String) async throws -> [GitHubFile] {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)")!
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await performRequest(request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == 200 else { return [] }

        return (try? JSONDecoder().decode([GitHubFile].self, from: data)) ?? []
    }

    // MARK: - Fetch File Content

    func fetchFileContent(owner: String, repo: String, token: String, path: String) async throws -> Data? {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)")!
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await performRequest(request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == 200 else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let base64Content = json["content"] as? String else { return nil }

        let cleaned = base64Content.replacingOccurrences(of: "\n", with: "")
        return Data(base64Encoded: cleaned)
    }

    // MARK: - Push File

    func pushFile(owner: String, repo: String, token: String, path: String, content: Data, commitMessage: String) async throws {
        let base64Content = content.base64EncodedString()
        let sha = try await getExistingFileSHA(owner: owner, repo: repo, token: token, path: path)

        var body: [String: Any] = [
            "message": commitMessage,
            "content": base64Content,
        ]
        if let sha { body["sha"] = sha }

        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)")!
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await performRequest(request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        switch statusCode {
        case 200, 201: return
        case 401: throw GitHubError.invalidToken
        case 404: throw GitHubError.repoNotFound
        case 409, 422: throw GitHubError.conflict
        default: throw GitHubError.serverError(statusCode, HTTPURLResponse.localizedString(forStatusCode: statusCode))
        }
    }

    // MARK: - Push with Auto Dedup

    func pushFileWithDedup(owner: String, repo: String, token: String, directory: String, baseName: String, content: Data, commitMessage: String) async throws -> String {
        var filename = "\(baseName).json"
        var path = "\(directory)/\(filename)"

        let existingSHA = try await getExistingFileSHA(owner: owner, repo: repo, token: token, path: path)
        if existingSHA != nil {
            for seq in 2...10 {
                filename = "\(baseName)-\(seq).json"
                path = "\(directory)/\(filename)"
                let sha = try await getExistingFileSHA(owner: owner, repo: repo, token: token, path: path)
                if sha == nil { break }
            }
        }

        try await pushFile(owner: owner, repo: repo, token: token, path: path, content: content, commitMessage: commitMessage)
        return path
    }

    // MARK: - Private

    private func getExistingFileSHA(owner: String, repo: String, token: String, path: String) async throws -> String? {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)")!
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await performRequest(request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        if statusCode == 404 { return nil }
        guard statusCode == 200 else { return nil }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let sha = json["sha"] as? String {
            return sha
        }
        return nil
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw GitHubError.networkError("连接超时")
            case .notConnectedToInternet, .networkConnectionLost:
                throw GitHubError.networkError("无网络连接")
            default:
                throw GitHubError.networkError(error.localizedDescription)
            }
        }
    }
}

struct GitHubFile: Codable {
    let name: String
    let path: String
    let sha: String
}
