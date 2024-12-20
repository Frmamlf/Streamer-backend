import Foundation
import Logging

public var logger = Logger(label: "com.Resolver")

public protocol Provider {
    var locale: Locale { get }
    var type: ProviderType { get }
    var title: String { get }
    var langauge: String { get }

    func latestMovies(page: Int) async throws -> [MediaContent]
    func latestTVShows(page: Int) async throws -> [MediaContent]
    func fetchMovieDetails(for url: URL) async throws -> Movie
    func fetchTVShowDetails(for url: URL) async throws -> TVshow
    func search(keyword: String, page: Int) async throws -> [MediaContent]
    func home() async throws -> [MediaContentSection]
}

extension Provider {
    public var locale: Locale {
        return Locale(identifier: "en_US_POSIX")
    }
}

public enum ProviderError: Error, Equatable {
    case noContent
    case wrongURL
    case captcha(URL)
}

public enum LocalProvider: String, Codable, Equatable, Hashable, CaseIterable {
    case flixtor
    case movie123
    case putlocker
    case akwam
    case empire
    case arabseed
    case cimaNow
    case kinokiste
    case flixHQ
    case kaido
    case viewAsian
    case filmPalast
    case faselHD
    case moviebox
    case gogoAnimeHD
}

public enum ProviderType: Codable, Equatable, Hashable {

    case local(id: LocalProvider)
    case remote(id: String)

    public init(_ localProvider: LocalProvider) {
#if canImport(FoundationNetworking)
        self = .remote(id: localProvider.rawValue)
        #else
        self = .local(id: localProvider)
        #endif
    }

    public init(rawValue: String) {
        let config = Self.activeProvidersConfig.first { $0.id == rawValue}!
        self.init(config: config)
    }

    public init(config: ProviderConfig) {
        switch config.type {
        case .local:
            self = .local(id: .init(rawValue: config.id)!)
        case .remote:
            self = .remote(id: config.id)
        }
    }

    public var rawValue: String {
        switch self {
        case .local(let id):
            return id.rawValue
        case .remote(let id):
            return id
        }
    }

    public var provider: Provider {
        switch self {
        case .local(let id):
            switch id {
            case .akwam:
                return AkwamProvider()
            case .flixtor:
                return FlixtorProvider()
            case .flixHQ:
                return FlixHQProvider()
            case .cimaNow:
                return CimaNowProvider()
            case .movie123:
                return Movie123Provider()
            case .putlocker:
                return PutlockerProvider()
            case .kinokiste:
                return KinokisteProvider()
            case .kaido:
                return KaidoAnimeProvider()
            case .arabseed:
                return ArabseedProvider()
            case .viewAsian:
                return ViewAsianProvider()
            case .filmPalast:
                return FilmPalastProvider()
            case .faselHD:
                return FaselHDProvider()
            case .moviebox:
                return MovieBoxProvider()
            case .empire:
                return EmpireStreamingProvider()
            case .gogoAnimeHD:
                return GogoAnimeHDProvider()

            }
        case .remote(let id):
            let config = Self.activeProvidersConfig.first { $0.id == id}!
            return RemoteProvider(providerConfig: config)
        }

    }

    public var iconURL: URL {
        let provider = Self.activeProvidersConfig.first { $0.id == self.rawValue}!
        return provider.iconURL
    }

    public static var activeProvidersConfig: [ProviderConfig] = []

    enum CodingKeys: CodingKey {
        case local
        case remote
    }
    enum LocalCodingKeys: CodingKey {
        case id
    }
    enum RemoteCodingKeys: CodingKey {
        case id
    }

    public init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<ProviderType.CodingKeys> = try decoder.container(keyedBy: ProviderType.CodingKeys.self)

        var allKeys: ArraySlice<ProviderType.CodingKeys> = ArraySlice<ProviderType.CodingKeys>(container.allKeys)

        guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
            throw DecodingError.typeMismatch(ProviderType.self, DecodingError.Context(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil))
        }
        switch onlyKey {
        case .local:

            let nestedContainer: KeyedDecodingContainer<ProviderType.LocalCodingKeys> = try container.nestedContainer(keyedBy: ProviderType.LocalCodingKeys.self, forKey: ProviderType.CodingKeys.local)

            self = ProviderType.local(id: try nestedContainer.decode(LocalProvider.self, forKey: ProviderType.LocalCodingKeys.id))
        case .remote:

            let nestedContainer: KeyedDecodingContainer<ProviderType.RemoteCodingKeys> = try container.nestedContainer(keyedBy: ProviderType.RemoteCodingKeys.self, forKey: ProviderType.CodingKeys.remote)

            self = ProviderType.remote(id: try nestedContainer.decode(String.self, forKey: ProviderType.RemoteCodingKeys.id))
        }

    }

    public func encode(to encoder: Encoder) throws {
        var container: KeyedEncodingContainer<ProviderType.CodingKeys> = encoder.container(keyedBy: ProviderType.CodingKeys.self)

        switch self {
        case .local(let id):
#if canImport(FoundationNetworking)
            var nestedContainer: KeyedEncodingContainer<ProviderType.RemoteCodingKeys> = container.nestedContainer(keyedBy: ProviderType.RemoteCodingKeys.self, forKey: ProviderType.CodingKeys.remote)
            try nestedContainer.encode(id, forKey: ProviderType.RemoteCodingKeys.id)
#else
            var nestedContainer: KeyedEncodingContainer<ProviderType.LocalCodingKeys> = container.nestedContainer(keyedBy: ProviderType.LocalCodingKeys.self, forKey: ProviderType.CodingKeys.local)
            try nestedContainer.encode(id, forKey: ProviderType.LocalCodingKeys.id)
#endif
        case .remote(let id):

            var nestedContainer: KeyedEncodingContainer<ProviderType.RemoteCodingKeys> = container.nestedContainer(keyedBy: ProviderType.RemoteCodingKeys.self, forKey: ProviderType.CodingKeys.remote)
            try nestedContainer.encode(id, forKey: ProviderType.RemoteCodingKeys.id)
        }
    }

}
