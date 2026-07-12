// src/services/youtubePlayer.ts
//
// Brain Phase 2: official YouTube controls. This wrapper:
//   - loads only https://www.youtube.com/iframe_api
//   - sets origin to the exact Plink HTTPS origin
//   - uses controls:1, playsinline:1, rel:0 (OFFICIAL controls visible)
//   - keeps YouTube branding and UI visible
//   - exposes only play/pause/seek/snapshot bridge methods
//   - uses a strict CSP
//   - never proxies/rewrites YouTube embed HTML
//
// Plink owns room close/sync/participants/chat/reactions/replace-video only.
// YouTube owns play/pause/timeline/captions/quality.

const PLINK_ORIGIN = process.env.PLINK_ORIGIN || 'https://plink-backend-production-ef31.up.railway.app';

export function youtubePlayerHTML(videoId: string): string {
  // Validate video ID (11 chars, [A-Za-z0-9_-]) — prevents XSS via interpolation.
  if (!/^[A-Za-z0-9_-]{11}$/.test(videoId)) {
    return `<!DOCTYPE html><html><body><h1>Invalid video ID</h1></body></html>`;
  }

  return `<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <meta http-equiv="Content-Security-Policy" content="
    default-src 'self';
    script-src 'self' https://www.youtube.com https://s.ytimg.com 'unsafe-inline';
    style-src 'self' https://www.youtube.com 'unsafe-inline';
    img-src 'self' https://i.ytimg.com https://yt3.ggpht.com data: blob:;
    media-src 'self' https://*.googlevideo.com;
    connect-src 'self' https://www.youtube.com;
    frame-src https://www.youtube.com;
    child-src https://www.youtube.com;
    font-src 'self';
    object-src 'none';
    base-uri 'self';
    form-action 'self';
  ">
  <style>
    html, body { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background: #000; }
    #player { width: 100%; height: 100%; }
    iframe { width: 100% !important; height: 100% !important; border: 0; }
  </style>
</head>
<body>
  <div id="player"></div>
  <script src="https://www.youtube.com/iframe_api"></script>
  <script>
    (function() {
      var player;
      var origin = ${JSON.stringify(PLINK_ORIGIN)};

      function post(event, payload) {
        window.webkit.messageHandlers.plinkPlayer.postMessage(
          Object.assign({ event: event }, payload || {})
        );
      }

      window.onYouTubeIframeAPIReady = function() {
        player = new YT.Player('player', {
          videoId: ${JSON.stringify(videoId)},
          playerVars: {
            'playsinline': 1,
            'controls': 1,
            'rel': 0,
            'origin': origin
          },
          events: {
            'onReady': function() { post('ready'); },
            'onStateChange': function(e) { post('state', { state: e.data }); },
            'onError': function(e) { post('error', { code: e.data }); }
          }
        });
      };

      // Plink bridge — only transport commands. No UI overrides.
      window.plinkPlay = function() {
        if (player && player.playVideo) { player.playVideo(); return true; }
        return false;
      };
      window.plinkPause = function() {
        if (player && player.pauseVideo) { player.pauseVideo(); return true; }
        return false;
      };
      window.plinkSeek = function(t) {
        if (player && player.seekTo) { player.seekTo(t, true); return true; }
        return false;
      };
      window.plinkSnapshot = function() {
        if (!player || !player.getCurrentTime) return null;
        return {
          time: player.getCurrentTime() || 0,
          duration: player.getDuration() || 0,
          state: player.getPlayerState ? player.getPlayerState() : -1
        };
      };
    })();
  </script>
</body>
</html>`;
}
