# Fifth basement CRT video

Source supplied by the user on 2026-10-14: `D:/aphasia/b5ff65f406555ac661be3f3ea2a68bbc.mp4`.
The original file is preserved. `basement_crt_loop.ogv` contains the full same video,
converted to Ogg Theora at 384 × 288, 24 fps, with letterboxing to preserve the
original 568 × 320 image. Its original audio is omitted intentionally.

Conversion: FFmpeg 7.1, `-an -vf "scale=384:288:force_original_aspect_ratio=decrease,pad=384:288:(ow-iw)/2:(oh-ih)/2,setsar=1" -r 24 -c:v libtheora -q:v 6`.

The twelve added CRTs and the existing teaching CRT use this single file with individual playback offsets spaced by
1.73 seconds, wrapping by actual video duration, and loop at the end. The path
can be overridden by the room contract's `basement_crt_video_path` field.
No external videos or reference-game media have been incorporated.

This note records the supplied asset and conversion; it does not assert a public
license for the user-provided video. The separately downloaded snow sound has its
own CC0 provenance record in `assets/audio/sfx/tv_static_SOURCE.md`.
