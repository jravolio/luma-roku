import { GatewayError, identifier, ticks } from './errors.mjs';

export const qualityOptions = [
  { id: 'auto', label: 'Auto · up to 20 Mbps', maxBitrate: 20_000_000 },
  { id: 'original', label: 'Original resolution · may transcode' },
  { id: '1080p', label: 'Up to 1080p · 10 Mbps', maxHeight: 1080, maxBitrate: 10_000_000 },
  { id: '720p', label: 'Up to 720p · 4 Mbps', maxHeight: 720, maxBitrate: 4_000_000 },
  { id: '480p', label: 'Up to 480p · 1.5 Mbps', maxHeight: 480, maxBitrate: 1_500_000 },
  { id: '360p', label: 'Up to 360p · 0.8 Mbps', maxHeight: 360, maxBitrate: 800_000 },
];
const widths = { '1080p': 1920, '720p': 1280, '480p': 854, '360p': 640 };
const languages = new Intl.DisplayNames(['en'], { type: 'language' });
const positive = n => Number.isFinite(n) && n > 0 ? n : undefined;
const streamIndex = n => Number.isInteger(n) && n >= 0 && n <= 2_147_483_647;
export const tracks = (source, type) => (source.MediaStreams ?? []).filter(s => s.Type === type && streamIndex(s.Index));
const video = source => (source.MediaStreams ?? []).find(s => s.Type === 'Video');
const invalid = message => new GatewayError('invalid_request', message, 400);

export function playbackChoices({ startTimeTicks = 0, mediaSourceId, audioStreamIndex, subtitleStreamIndex, quality = 'auto' } = {}) {
  ticks(startTimeTicks);
  if (mediaSourceId !== undefined) identifier(mediaSourceId, 'mediaSourceId');
  if (audioStreamIndex !== undefined && !streamIndex(audioStreamIndex)) throw invalid('audioStreamIndex must be a nonnegative Jellyfin stream index.');
  if (subtitleStreamIndex !== undefined && subtitleStreamIndex !== -1 && !streamIndex(subtitleStreamIndex)) throw invalid('subtitleStreamIndex must be a Jellyfin stream index or -1 for Off.');
  if (!qualityOptions.some(q => q.id === quality)) throw invalid('Quality must be auto, original, 1080p, 720p, 480p, or 360p.');
  return { startTimeTicks, mediaSourceId, audioStreamIndex, subtitleStreamIndex, quality };
}

function trackLabel(track, type) {
  if (track.DisplayTitle?.trim()) return track.DisplayTitle;
  let language = track.Language;
  try { if (language) language = languages.of(language); } catch { /* Unknown language codes stay readable. */ }
  return [track.Title, language || 'Unknown language', track.Codec?.toUpperCase(),
    type === 'Audio' && (track.ChannelLayout || (track.Channels === 1 ? 'Mono' : track.Channels === 2 ? 'Stereo' : track.Channels ? `${track.Channels} channels` : undefined)),
    track.IsDefault && 'Default', track.IsForced && 'Forced', track.IsHearingImpaired && 'SDH', track.IsExternal && 'External',
  ].filter(Boolean).join(' · ');
}

export function publicTracks(source, type) {
  return tracks(source, type).map(t => ({ index: t.Index, label: trackLabel(t, type),
    ...(t.Language ? { language: t.Language } : {}), ...(t.Codec ? { codec: t.Codec } : {}),
    ...(type === 'Audio' && positive(t.Channels) ? { channels: t.Channels } : {}),
    ...(typeof t.IsDefault === 'boolean' ? { isDefault: t.IsDefault } : {}),
    ...(type === 'Subtitle' && typeof t.IsForced === 'boolean' ? { isForced: t.IsForced } : {}),
  }));
}

export function publicSource(source) {
  const v = video(source), width = positive(v?.Width), height = positive(v?.Height);
  return { id: source.Id, label: [source.Name || 'Version', width && height ? `${width} × ${height}` : height ? `${height}p` : undefined,
    v?.Codec?.toUpperCase(), source.Container?.toUpperCase()].filter(Boolean).join(' · '),
    ...(width ? { width } : {}), ...(height ? { height } : {}) };
}

// Native browser audio track selection is not portable. Multiple audio tracks
// therefore require a single selected audio track in the HLS output.
export function browserCompatible(source) {
  const v = video(source), audio = tracks(source, 'Audio');
  return !source.RequiresOpening && /^(mp4|m4v)$/i.test(source.Container) &&
    v?.Codec?.toLowerCase() === 'h264' && (!v.BitDepth || v.BitDepth <= 8) && (!v.VideoRangeType || v.VideoRangeType === 'SDR') &&
    audio.length <= 1 && audio.every(a => ['aac', 'mp3'].includes(a.Codec?.toLowerCase()) && (!a.Channels || a.Channels <= 2));
}

export function selectPlayback(source, choices) {
  const audio = tracks(source, 'Audio'), subtitles = tracks(source, 'Subtitle');
  const audioStreamIndex = choices.audioStreamIndex ?? audio.find(t => t.Index === source.DefaultAudioStreamIndex)?.Index ?? audio.find(t => t.IsDefault)?.Index ?? audio[0]?.Index ?? null;
  const subtitleStreamIndex = choices.subtitleStreamIndex ?? subtitles.find(t => t.Index === source.DefaultSubtitleStreamIndex)?.Index ?? -1;
  if (audioStreamIndex !== null && !audio.some(t => t.Index === audioStreamIndex)) throw invalid('The selected audio track is not available in this version.');
  if (subtitleStreamIndex !== -1 && !subtitles.some(t => t.Index === subtitleStreamIndex)) throw invalid('The selected subtitle track is not available in this version.');
  const selectedAudio = audio.find(t => t.Index === audioStreamIndex), v = video(source);
  const quality = qualityOptions.find(q => q.id === choices.quality);
  const maxBitrate = quality.maxBitrate ?? 2_147_483_647;
  const maxWidth = Math.min(positive(v?.Width) ?? Infinity, widths[quality.id] ?? Infinity);
  const maxHeight = Math.min(positive(v?.Height) ?? Infinity, quality.maxHeight ?? Infinity);
  const audioBitrate = selectedAudio ? Math.min(positive(selectedAudio.BitRate) ?? 192_000, 192_000) : 0;
  const sourceVideoBitrate = positive(v?.BitRate) ?? positive(source.Bitrate - audioBitrate);
  const encodeSubtitles = subtitleStreamIndex !== -1;
  const exceedsBitrate = quality.maxBitrate !== undefined && (!positive(source.Bitrate) || source.Bitrate > maxBitrate);
  // Profiles are ceilings, not instructions to re-encode files already below
  // them. Require known dimensions before skipping a requested resize.
  const fitsDimensions = !quality.maxHeight || (positive(v?.Width) !== undefined && positive(v?.Height) !== undefined &&
    v.Width <= widths[quality.id] && v.Height <= quality.maxHeight);
  const allowVideoStreamCopy = !encodeSubtitles && fitsDimensions && !exceedsBitrate &&
    v?.Codec?.toLowerCase() === 'h264' && (!v.BitDepth || v.BitDepth <= 8) && (!v.VideoRangeType || v.VideoRangeType === 'SDR');
  const codecConversion = v?.Codec?.toLowerCase() !== 'h264' || (positive(v?.BitDepth) ?? 8) > 8;
  // Jellyfin adjusts its H264 encode target for codecs such as HEVC and AV1.
  // Replacing that target with the source bitrate defeats the adjustment.
  const sourceCappedBitrate = sourceVideoBitrate || quality.maxBitrate
    ? Math.min(sourceVideoBitrate ?? maxBitrate - audioBitrate, maxBitrate - audioBitrate) : undefined;
  const videoBitrate = (quality.id === 'original' && !allowVideoStreamCopy) || codecConversion ? undefined : sourceCappedBitrate;
  return { selection: { mediaSourceId: source.Id, audioStreamIndex, subtitleStreamIndex, quality: quality.id },
    maxBitrate, maxWidth: Number.isFinite(maxWidth) ? maxWidth : undefined, maxHeight: Number.isFinite(maxHeight) ? maxHeight : undefined,
    audioBitrate, videoBitrate, codecConversion, allowVideoStreamCopy, encodeSubtitles,
    allowDirectPlay: !encodeSubtitles && fitsDimensions && !exceedsBitrate && browserCompatible(source),
  };
}

export function playbackProfile(base, plan, source) {
  const profile = structuredClone(base);
  profile.MaxStreamingBitrate = plan.maxBitrate; profile.MaxStaticBitrate = plan.maxBitrate;
  if (plan.encodeSubtitles) profile.SubtitleProfiles = [...new Set(tracks(source, 'Subtitle').map(t => t.Codec?.toLowerCase()).filter(Boolean))].map(Format => ({ Format, Method: 'Encode' }));
  for (const [Property, value] of [['Width', plan.maxWidth], ['Height', plan.maxHeight]]) {
    if (value) profile.CodecProfiles.push({ Type: 'Video', Conditions: [{ Condition: 'LessThanEqual', Property, Value: String(value), IsRequired: true }] });
  }
  return profile;
}

// Jellyfin query keys are case-insensitive. Remove all spellings before setting
// a control so an existing AllowVideoStreamCopy or SubtitleMethod cannot win.
export function setMediaQuery(url, values) {
  const keys = new Set(Object.keys(values).map(k => k.toLowerCase()));
  for (const key of [...url.searchParams.keys()]) if (keys.has(key.toLowerCase())) url.searchParams.delete(key);
  for (const [key, value] of Object.entries(values)) if (value !== undefined && value !== null) url.searchParams.set(key, String(value));
  return url;
}

export function streamSummary(source, plan, direct) {
  const v = video(source), a = tracks(source, 'Audio').find(t => t.Index === plan.selection.audioStreamIndex);
  let width = positive(v?.Width), height = positive(v?.Height);
  if (!direct && width && height) {
    const scale = Math.min(1, (plan.maxWidth ?? width) / width, (plan.maxHeight ?? height) / height);
    width = Math.max(2, Math.floor(width * scale / 2) * 2); height = Math.max(2, Math.floor(height * scale / 2) * 2);
  }
  const bitrate = direct ? positive(source.Bitrate) : plan.videoBitrate ? Math.min(plan.maxBitrate, plan.videoBitrate + plan.audioBitrate) : undefined;
  return { ...(width ? { width } : {}), ...(height ? { height } : {}), ...(bitrate ? { bitrate } : {}),
    ...(v ? { videoCodec: direct ? v.Codec : 'h264' } : {}), ...(a ? { audioCodec: direct ? a.Codec : 'aac' } : {}) };
}
