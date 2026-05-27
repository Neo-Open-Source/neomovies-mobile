import ExpoModulesCore
import UIKit

final class EpisodesListView: ExpoView, UITableViewDataSource, UITableViewDelegate {
  private struct EpisodeItem {
    let season: Int
    let episode: Int
    let title: String
    let description: String
    let progress: Int
    let tmdbRating: Double?
    let imdbRating: Double?
  }

  let onEpisodePress = EventDispatcher()

  private let tableView = UITableView(frame: .zero, style: .plain)
  private var items: [EpisodeItem] = []
  private var textColor: UIColor = .label
  private var secondaryTextColor: UIColor = .secondaryLabel
  private var rowBackgroundColor: UIColor = .clear

  required init(appContext: AppContext? = nil) {
    super.init(appContext: appContext)
    tableView.translatesAutoresizingMaskIntoConstraints = false
    tableView.dataSource = self
    tableView.delegate = self
    tableView.separatorStyle = .none
    tableView.showsVerticalScrollIndicator = false
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 86
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

    addSubview(tableView)
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: topAnchor),
      tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }

  func setEpisodes(_ value: [[String: Any]]) {
    items = value.compactMap { raw in
      guard let season = raw["season"] as? Int ?? (raw["season"] as? NSNumber)?.intValue,
            let episode = raw["episode"] as? Int ?? (raw["episode"] as? NSNumber)?.intValue else {
        return nil
      }
      let title = (raw["title"] as? String) ?? ""
      let description = (raw["description"] as? String) ?? ""
      let progress = min(max((raw["progress"] as? Int ?? (raw["progress"] as? NSNumber)?.intValue ?? 0), 0), 100)
      let tmdb = raw["tmdbRating"] as? Double ?? (raw["tmdbRating"] as? NSNumber)?.doubleValue
      let imdb = raw["imdbRating"] as? Double ?? (raw["imdbRating"] as? NSNumber)?.doubleValue
      return EpisodeItem(season: season, episode: episode, title: title, description: description, progress: progress, tmdbRating: tmdb, imdbRating: imdb)
    }
    tableView.reloadData()
  }

  func setTextColor(_ hex: String?) {
    textColor = Self.color(hex, fallback: .label)
    tableView.reloadData()
  }

  func setSecondaryTextColor(_ hex: String?) {
    secondaryTextColor = Self.color(hex, fallback: .secondaryLabel)
    tableView.reloadData()
  }

  func setBackgroundColorHex(_ hex: String?) {
    rowBackgroundColor = Self.color(hex, fallback: .clear)
    tableView.reloadData()
  }

  func setBorderColor(_ _: String?) {
    // Reserved for parity with Android.
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    items.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let item = items[indexPath.row]
    let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
    cell.selectionStyle = .none
    cell.backgroundColor = rowBackgroundColor

    var cfg = UIListContentConfiguration.subtitleCell()
    cfg.text = "\(item.episode). \(item.title)"
    let rating: String
    if let tmdb = item.tmdbRating {
      rating = String(format: " · TMDB %.1f", tmdb)
    } else if let imdb = item.imdbRating {
      rating = String(format: " · IMDb %.1f", imdb)
    } else {
      rating = ""
    }
    let progress: String
    if item.progress >= 95 {
      progress = "  ✓ watched"
    } else if item.progress > 0 {
      progress = "  \(item.progress)%"
    } else {
      progress = ""
    }
    cfg.secondaryText = "S\(item.season) · E\(item.episode)\(rating)\n\(item.description)\(progress)"
    cfg.secondaryTextProperties.numberOfLines = 3
    cfg.textProperties.color = textColor
    cfg.secondaryTextProperties.color = secondaryTextColor
    cell.contentConfiguration = cfg
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let item = items[indexPath.row]
    onEpisodePress([
      "season": item.season,
      "episode": item.episode
    ])
  }

  private static func color(_ hex: String?, fallback: UIColor) -> UIColor {
    guard let hex, !hex.isEmpty else { return fallback }
    var text = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    if text.hasPrefix("#") { text.removeFirst() }
    guard text.count == 6, let value = Int(text, radix: 16) else { return fallback }
    return UIColor(
      red: CGFloat((value >> 16) & 0xFF) / 255.0,
      green: CGFloat((value >> 8) & 0xFF) / 255.0,
      blue: CGFloat(value & 0xFF) / 255.0,
      alpha: 1
    )
  }
}
