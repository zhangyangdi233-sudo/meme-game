@abstract
class_name SocialFeedSource
extends RefCounted
## What the social panel reads to paint posts, comments, the profile and the composer.
## The host binds one under ServiceKeys.SOCIAL_FEED_SOURCE; the panel resolves it when mounted.

@abstract func channels() -> Array

@abstract func load_texture(path: String) -> Texture2D

@abstract func poster_texture(poster_cell: int) -> Texture2D

@abstract func poster_sheet_path() -> String

@abstract func poster_sheet_count() -> int

@abstract func no_signal_icon_path() -> String

@abstract func player_character_path() -> String

@abstract func composer_soft_unit_limit() -> int

@abstract func visible_post_indices(followed_handles: Array, channel: String) -> Array[int]

@abstract func post_for_index(post_index: int) -> Dictionary

@abstract func like_text(post: Dictionary, post_index: int, liked_post_ids: Array) -> String

@abstract func caption_text(post: Dictionary, post_index: int) -> String

@abstract func author_id(post: Dictionary) -> String

## Localizes the text and lets the current pollution corrupt it.
@abstract func corrupt_text(text: String) -> String

@abstract func translate(text: String) -> String

@abstract func floor_label() -> String

@abstract func player_echo_quote() -> String

@abstract func echo_comment_handle() -> String

@abstract func game_day() -> int

@abstract func pollution() -> int

@abstract func current_locale() -> String

## Supplies pickup lines and comments for a post; null when no material is wired.
@abstract func language_material() -> LanguageMaterial
