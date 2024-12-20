import Foundation
import SwiftSoup

public struct MovieBoxProvider: Provider {
    public var type: ProviderType = .init(.moviebox)
    public let title: String = "Moviebox"
    public let langauge: String = "🇺🇸"
    @EnviromentValue(key: "movieboxprovider_url", defaultValue: URL(staticString: "https://google.com/"))
    public var baseURL: URL
    public var moviesURL: URL {
        baseURL.appendingPathComponent("movies")
    }
    public var tvShowsURL: URL {
        baseURL.appendingPathComponent("tvshows")
    }
    private var homeURL: URL {
        baseURL.appendingPathComponent("home")
    }

    enum MovieBoxProviderError: Error {
        case episodeURLNotFound
    }

    public func parsePage(url: URL) async throws -> [MediaContent] {
        let data = try await Utilities.requestData(url: url)
        let response = try JSONDecoder().decode(ListingResponse.self, from: data)
        return response.data.map { row in
            let type: MediaContent.MediaContentType = row.boxType == 1 ? .movie :  .tvShow
            let url = baseURL.appendingPathComponent(type == .movie ? "movie" : "tvshow").appendingPathComponent(row.id)
            let posterURL = row.poster ?? .init(staticString: "https://eticketsolutions.com/demo/themes/e-ticket/img/movie.jpg")
            return MediaContent(title: row.title, webURL: url, posterURL: posterURL, type: type, provider: self.type)
        }
    }

    public func latestMovies(page: Int) async throws -> [MediaContent] {
        return try await parsePage(url: moviesURL.appendingPathComponent(page))
    }

    public func latestTVShows(page: Int) async throws -> [MediaContent] {
        return try await parsePage(url: tvShowsURL.appendingPathComponent(page))
    }

    public func fetchMovieDetails(for url: URL) async throws -> Movie {
        let data = try await Utilities.requestData(url: url)
        let media = try JSONCoder.decoder.decode(MovieResponse.self, from: data)
        let id = url.lastPathComponent
        let hostURL = baseURL.appendingPathComponent("movie").appendingPathComponent("play").appendingPathComponent(id)
        let posterURL = media.data.poster ?? .init(staticString: "https://eticketsolutions.com/demo/themes/e-ticket/img/movie.jpg")

        return Movie(title: media.data.title, webURL: url, posterURL: posterURL, sources: [.init(hostURL: hostURL )])

    }

    public func fetchTVShowDetails(for url: URL) async throws -> TVshow {
        let data = try await Utilities.requestData(url: url)
        let media = try JSONCoder.decoder.decode(TVShowResponse.self, from: data)
        let id = url.lastPathComponent

        let playURL = baseURL.appendingPathComponent("tvshow").appendingPathComponent("play")
        guard let maxSeason = media.data.max_season else {
            throw MovieBoxProviderError.episodeURLNotFound
        }

        let seasons = try await (1...maxSeason).concurrentMap { seasonNumber in
            let seasonURL = baseURL.appendingPathComponent("tvshow").appendingPathComponent(id).appendingPathComponent(seasonNumber)
            let data = try await Utilities.requestData(url: seasonURL)
            let season = try JSONCoder.decoder.decode(SeasonResponse.self, from: data)

            let ep = season.data.map { ep in
                let hostURLs = playURL.appendingPathComponent(id).appendingPathComponent(seasonNumber).appendingPathComponent(ep.episode)
                return Episode(number: ep.episode, sources: [.init(hostURL: hostURLs)])
            }
            if ep.count > 0 {
                return Season(seasonNumber: seasonNumber, webURL: url, episodes: ep)
            } else {
                return nil
            }
        }.compactMap { $0 }
        let posterURL = media.data.poster ?? .init(staticString: "https://eticketsolutions.com/demo/themes/e-ticket/img/movie.jpg")
        return TVshow(title: media.data.title, webURL: url, posterURL: posterURL, seasons: seasons)
    }

    public func search(keyword: String, page: Int) async throws -> [MediaContent] {
        let keyword = keyword.replacingOccurrences(of: " ", with: "-")
        let pageURL = baseURL.appendingPathComponent("search/\(keyword)")
        return try await parsePage(url: pageURL)
    }

    public func home() async throws -> [MediaContentSection] {
        let data = try await Utilities.requestData(url: homeURL)
        var response = try JSONDecoder().decode(HomeResponse.self, from: data).data
        response.removeFirst(2)
        return response.compactMap {
            guard $0.box_type != 6, $0.list.count > 0 else { return nil }
            let media =  $0.list.map { row in
                let type: MediaContent.MediaContentType = row.boxType == 1 ? .movie :  .tvShow
                let url = baseURL.appendingPathComponent(type == .movie ? "movie" : "tvshow").appendingPathComponent(row.id)
                let posterURL = row.poster ?? .init(staticString: "https://eticketsolutions.com/demo/themes/e-ticket/img/movie.jpg")
                return MediaContent(title: row.title, webURL: url, posterURL: posterURL, type: type, provider: self.type)
            }
            return MediaContentSection(title: $0.name, media: media)
        }
    }

    struct ListingResponse: Codable {
        let data: [Datum]
    }
    struct Datum: Codable {
        let id: Int
        let title: String
        let poster: URL?
        let boxType: Int
        let max_season: Int?
        enum CodingKeys: String, CodingKey {
            case id, title, poster
            case boxType = "box_type"
            case max_season = "max_season"

        }

        init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<MovieBoxProvider.Datum.CodingKeys> = try decoder.container(keyedBy: MovieBoxProvider.Datum.CodingKeys.self)

            self.id = try container.decode(Int.self, forKey: MovieBoxProvider.Datum.CodingKeys.id)
            self.title = try container.decode(String.self, forKey: MovieBoxProvider.Datum.CodingKeys.title)
            let posterPath = try container.decodeIfPresent(String.self, forKey: MovieBoxProvider.Datum.CodingKeys.poster)
            if let posterPath, let url = URL(string: posterPath) {
                self.poster = url
            } else {
                self.poster = nil
            }
            self.boxType = try container.decode(Int.self, forKey: MovieBoxProvider.Datum.CodingKeys.boxType)
            self.max_season = try container.decodeIfPresent(Int.self, forKey: MovieBoxProvider.Datum.CodingKeys.max_season)

        }

        func encode(to encoder: Encoder) throws {
            var container: KeyedEncodingContainer<MovieBoxProvider.Datum.CodingKeys> = encoder.container(keyedBy: MovieBoxProvider.Datum.CodingKeys.self)

            try container.encode(self.id, forKey: MovieBoxProvider.Datum.CodingKeys.id)
            try container.encode(self.title, forKey: MovieBoxProvider.Datum.CodingKeys.title)
            try container.encodeIfPresent(self.poster, forKey: MovieBoxProvider.Datum.CodingKeys.poster)
            try container.encode(self.boxType, forKey: MovieBoxProvider.Datum.CodingKeys.boxType)
            try container.encodeIfPresent(self.max_season, forKey: MovieBoxProvider.Datum.CodingKeys.max_season)
        }
    }

    // MARK: - HomeResponse
    struct HomeResponse: Decodable {
        let msg: String
        let data: [HomeSection]
    }

    // MARK: - Datum
    struct HomeSection: Decodable {
        let name: String
        let box_type: Int
        @FailableDecodableArray var list: [Datum]

        enum CodingKeys: String, CodingKey {
            case name
            case box_type = "box_type"
            case list
        }

        init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<MovieBoxProvider.HomeSection.CodingKeys> = try decoder.container(keyedBy: MovieBoxProvider.HomeSection.CodingKeys.self)

            self.name = try container.decode(String.self, forKey: MovieBoxProvider.HomeSection.CodingKeys.name)
            self.box_type = try container.decode(Int.self, forKey: MovieBoxProvider.HomeSection.CodingKeys.box_type)
            self._list = try container.decode(FailableDecodableArray<MovieBoxProvider.Datum>.self, forKey: MovieBoxProvider.HomeSection.CodingKeys.list)

        }
    }

    // MARK: - Datum
    struct MovieResponse: Decodable {
        let data: Datum
    }

    struct TVShowResponse: Decodable {
        let data: Datum
    }
    struct SeasonResponse: Decodable {
        let data: [MEpisode]
    }

    struct MEpisode: Codable {
        let season, episode: Int
    }
}
