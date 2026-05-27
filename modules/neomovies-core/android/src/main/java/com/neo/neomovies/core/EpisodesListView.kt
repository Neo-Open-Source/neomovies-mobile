package com.neo.neomovies.core

import android.content.Context
import android.graphics.Color
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import expo.modules.kotlin.AppContext
import expo.modules.kotlin.views.ExpoView
import expo.modules.kotlin.viewevent.EventDispatcher

class EpisodesListView(context: Context, appContext: AppContext) : ExpoView(context, appContext) {
  private val onEpisodePress by EventDispatcher<Map<String, Any>>()
  private val recyclerView = RecyclerView(context)
  private val adapter = EpisodesAdapter { episode ->
    val payload = mapOf<String, Any>("season" to episode.season, "episode" to episode.episode)
    onEpisodePress(payload)
  }

  init {
    recyclerView.layoutManager = LinearLayoutManager(context, LinearLayoutManager.VERTICAL, false)
    recyclerView.adapter = adapter
    recyclerView.overScrollMode = View.OVER_SCROLL_NEVER
    recyclerView.setHasFixedSize(true)
    addView(
      recyclerView,
      LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
    )
  }

  fun setEpisodes(value: List<Map<String, Any?>>) {
    val items = value.mapNotNull { raw ->
      val season = (raw["season"] as? Number)?.toInt() ?: return@mapNotNull null
      val episode = (raw["episode"] as? Number)?.toInt() ?: return@mapNotNull null
      val title = (raw["title"] as? String).orEmpty()
      val description = (raw["description"] as? String).orEmpty()
      val progress = ((raw["progress"] as? Number)?.toInt() ?: 0).coerceIn(0, 100)
      val tmdbRating = (raw["tmdbRating"] as? Number)?.toDouble()
      val imdbRating = (raw["imdbRating"] as? Number)?.toDouble()
      EpisodeUi(season, episode, title, description, progress, tmdbRating, imdbRating)
    }
    adapter.submit(items)
  }

  fun setTextColor(hex: String?) { adapter.textColor = parseColor(hex, Color.WHITE) }
  fun setSecondaryTextColor(hex: String?) { adapter.secondaryTextColor = parseColor(hex, Color.LTGRAY) }
  fun setBorderColor(hex: String?) { adapter.borderColor = parseColor(hex, Color.TRANSPARENT) }
  fun setBackgroundColorHex(hex: String?) { adapter.backgroundColor = parseColor(hex, Color.TRANSPARENT) }

  private fun parseColor(raw: String?, fallback: Int): Int {
    if (raw.isNullOrBlank()) return fallback
    return runCatching { Color.parseColor(raw) }.getOrDefault(fallback)
  }
}

private data class EpisodeUi(
  val season: Int,
  val episode: Int,
  val title: String,
  val description: String,
  val progress: Int,
  val tmdbRating: Double?,
  val imdbRating: Double?,
)

private class EpisodesAdapter(
  private val onPress: (EpisodeUi) -> Unit,
) : RecyclerView.Adapter<EpisodesAdapter.VH>() {
  private val items = mutableListOf<EpisodeUi>()

  var textColor: Int = Color.WHITE
  var secondaryTextColor: Int = Color.LTGRAY
  var borderColor: Int = Color.TRANSPARENT
  var backgroundColor: Int = Color.TRANSPARENT

  fun submit(next: List<EpisodeUi>) {
    items.clear()
    items.addAll(next)
    notifyDataSetChanged()
  }

  override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
    val density = parent.resources.displayMetrics.density
    val root = LinearLayout(parent.context).apply {
      orientation = LinearLayout.VERTICAL
      setPadding((12 * density).toInt(), (10 * density).toInt(), (12 * density).toInt(), (10 * density).toInt())
      layoutParams = RecyclerView.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
    }

    val title = TextView(parent.context).apply {
      setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
      setTypeface(typeface, android.graphics.Typeface.BOLD)
      maxLines = 1
    }

    val meta = TextView(parent.context).apply {
      setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
      maxLines = 1
    }

    val description = TextView(parent.context).apply {
      setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
      maxLines = 2
    }

    val progress = TextView(parent.context).apply {
      setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
      gravity = Gravity.END
      maxLines = 1
    }

    root.addView(title)
    root.addView(meta)
    root.addView(description)
    root.addView(progress)

    return VH(root, title, meta, description, progress)
  }

  override fun onBindViewHolder(holder: VH, position: Int) {
    val item = items[position]
    holder.root.setBackgroundColor(backgroundColor)
    holder.root.setOnClickListener { onPress(item) }
    holder.title.setTextColor(textColor)
    holder.meta.setTextColor(secondaryTextColor)
    holder.description.setTextColor(secondaryTextColor)
    holder.progress.setTextColor(secondaryTextColor)

    val rating = when {
      item.tmdbRating != null -> " · TMDB ${"%.1f".format(item.tmdbRating)}"
      item.imdbRating != null -> " · IMDb ${"%.1f".format(item.imdbRating)}"
      else -> ""
    }

    holder.title.text = "${item.episode}. ${item.title}"
    holder.meta.text = "S${item.season} · E${item.episode}$rating"
    holder.description.text = item.description
    holder.progress.text = if (item.progress >= 95) "✓ watched" else if (item.progress > 0) "${item.progress}%" else ""
  }

  override fun getItemCount(): Int = items.size

  class VH(
    val root: LinearLayout,
    val title: TextView,
    val meta: TextView,
    val description: TextView,
    val progress: TextView,
  ) : RecyclerView.ViewHolder(root)
}
