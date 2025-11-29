import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import '../../utils/app_theme.dart';
import '../player/universal_player_screen.dart';
import '../../services/subtitle_service.dart';

class StreamResolverScreen extends StatefulWidget {
  final String title;
  final String embedUrl;
  final bool isTV;
  final int? movieId;
  final int? showId;
  final String? seasonEpisode;
  final String? posterPath; // For storing poster image path in history

  const StreamResolverScreen({
    super.key,
    required this.title,
    required this.embedUrl,
    this.isTV = false,
    this.movieId,
    this.showId,
    this.seasonEpisode,
    this.posterPath,
  });

  @override
  State<StreamResolverScreen> createState() => _StreamResolverScreenState();
}

class _RingPainter extends CustomPainter {
  final Color color;
  _RingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final gradient = SweepGradient(
      colors: [
        color.withOpacity(0.0),
        color.withOpacity(0.6),
        color,
        color.withOpacity(0.6),
        color.withOpacity(0.0),
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
    );

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(rect);

    canvas.drawArc(rect, 0, 2 * math.pi, false, ring);

    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white12;
    canvas.drawCircle(center, radius - 6, inner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StreamResolverScreenState extends State<StreamResolverScreen>
    with TickerProviderStateMixin {
  bool _resolving = true;
  bool _failed = false;
  final List<String> _candidates = [];
  Timer? _timeoutTimer;
  bool _navigated = false;
  bool _aggregating = false;
  InAppWebViewController? _wv;
  final CookieManager _cookieManager = CookieManager.instance();
  String? _lastHeaderOrigin;
  String? _lastHeaderReferer;
  DateTime? _aggStart;
  static const int _aggMinMs = 100; // wait at least this long
  late final AnimationController _loaderCtrl;
  late final Animation<double> _pulse;
  late final AnimationController _spinCtrl;
  late final AnimationController _orbitCtrl;
  String _loadingStatus = 'Searching for best streams...';

  static const _captureJS = r'''
    (function(){
      try {
        // Also capture proxy/redirect patterns and encoded u= URLs and subtitle links
        const mediaRe = /(\.m3u8($|\?)|\.mp4($|\?)|\.webm($|\?)|\.ts($|\?)|manifest\.mpd|embed-proxy|\/api\/embed-proxy|\/proxy|[?&]u=https?:%2F%2F|[?&]u=https?:\/\/|[?&]url=https?:%2F%2F|[?&]url=https?:\/\/)/i;
        const subRe = /(\.srt($|\?)|\.vtt($|\?))/i;
        function toAbs(u){ try { if (!u) return u; if (/^https?:/i.test(u)) return u; if (/^data:/i.test(u)) return u; return new URL(u, location.href).href; } catch(e){ return u; } }
        function post(u, meta){
          try {
            let url = u;
            if (url && !/^data:/i.test(url)) url = toAbs(url);
            window.flutter_inappwebview.callHandler('HZLink', Object.assign({url:url, type: subRe.test(url)?'subtitle':'media'}, meta||{}));
          } catch(e) {}
        }
        function readBlobText(b, cb){ try { if (b && b.text) { b.text().then(cb).catch(function(){}); } else { var fr=new FileReader(); fr.onload=function(){ cb(String(fr.result||'')); }; fr.onerror=function(){}; fr.readAsText(b); } } catch(e){} }
        function tryParseTextForSubs(u, res){
          try {
            res.clone().text().then(function(t){
              try {
                if (!t) return;
                if (/^(WEBVTT)/m.test(t) || /-->/.test(t)) { post(u, {type:'subtitle', body: t}); return; }
                // JSON or HTML bodies: extract absolute .vtt/.srt links
                const abs = t.match(/https?:[^"'\s>]+\.(vtt|srt)(\?[^"'\s>]*)?/ig);
                if (abs && abs.length){ for (const x of abs){ post(x, {type:'subtitle'}); } }
                const rel = t.match(/['\"\(\s]((?:\/|\.\/|\.\.\/)[^'\"\s>]+\.(?:vtt|srt)(?:\?[^'\"\s>]*)?)/ig);
                if (rel && rel.length){ for (const m of rel){ const p = m.replace(/^['\"\(\s]+/, ''); post(p, {type:'subtitle'}); } }
              } catch(e) {}
            }).catch(function(){});
          } catch(e) {}
        }
        function pad2(n){ return (n+"").padStart(2,'0'); }
        function secToVttTime(sec){ try { var h=Math.floor(sec/3600), m=Math.floor((sec%3600)/60), s=(sec%60).toFixed(3); if (h>0) return pad2(h)+":"+pad2(m)+":"+(""+s).padStart(6,'0'); else return pad2(m)+":"+(""+s).padStart(6,'0'); } catch(e){ return '00:00.000'; } }
        var hzDumped = window.__hz_sub_dumped || (window.__hz_sub_dumped = {});
        var hzNextParsed = window.__hz_next_parsed || (window.__hz_next_parsed = 0);
        function extractSubsFromJson(obj){
          try {
            if (obj == null) return;
            const t = typeof obj;
            if (t === 'string'){
              const s = obj;
              const m = s.match(/https?:[^"'\s>]+\.(?:vtt|srt)(?:\?[^"'\s>]*)?/ig);
              if (m && m.length){ for (const u of m){ post(u, {type:'subtitle'}); } }
              return;
            }
            if (Array.isArray(obj)){
              for (let i=0;i<obj.length;i++){ extractSubsFromJson(obj[i]); }
              return;
            }
            if (t === 'object'){
              // Common track shapes
              const cands = ['file','src','url','href'];
              let u = null; for (const k of cands){ if (obj && typeof obj[k] === 'string' && /(\.vtt|\.srt)(\?|$)/i.test(obj[k])) { u = obj[k]; break; } }
              if (u){
                const label = obj['label'] || obj['name'] || obj['title'] || '';
                const lang = obj['lang'] || obj['language'] || obj['srclang'] || '';
                post(u, {type:'subtitle', label: String(label||''), lang: String(lang||'')});
              }
              for (const k in obj){ if (Object.prototype.hasOwnProperty.call(obj,k)) extractSubsFromJson(obj[k]); }
            }
          } catch(e){}
        }
        function parseNextData(){
          try {
            if (hzNextParsed) return; // only once
            const el = document.getElementById('__NEXT_DATA__');
            if (!el) return;
            const txt = el.textContent || el.innerText || '';
            if (!txt) return;
            try { const json = JSON.parse(txt); hzNextParsed = 1; extractSubsFromJson(json); } catch(e){}
          } catch(e){}
        }
        // Hook blob URL creation to capture VTT/SRT blobs
        try {
          const _origCO = URL.createObjectURL;
          URL.createObjectURL = function(obj){
            try { if (obj && obj.type && /(text\/vtt|application\/x-subrip)/i.test(obj.type)) { readBlobText(obj, function(t){ if (t) post('inline:'+encodeURIComponent('blob'), {type:'subtitle', body: t}); }); } } catch(e){}
            return _origCO.call(URL, obj);
          };
        } catch(e){}
        // Hook fetch
        const ofetch = window.fetch;
        window.fetch = async function(input, init){
          const res = await ofetch(input, init);
          try {
            const u = (typeof input === 'string') ? input : (input && input.url) || (res && res.url) || '';
            const ct = res && res.headers && res.headers.get ? (res.headers.get('content-type')||'') : '';
            if (ct && /(text\/vtt|application\/x-subrip)/i.test(ct)) { try { const txt = await res.clone().text(); post(u, {type: 'subtitle', body: txt}); } catch(e) { post(u, {type: 'subtitle'}); } }
            else if ((ct && /application\/json|text\/plain|application\/octet-stream/i.test(ct)) || !ct) { tryParseTextForSubs(u, res); }
            if (u && (mediaRe.test(u) || subRe.test(u))) { post(u); }
          } catch(e) {}
          return res;
        };
        // Hook XHR
        const oopen = XMLHttpRequest.prototype.open;
        const osend = XMLHttpRequest.prototype.send;
        let xhrUrl = '';
        XMLHttpRequest.prototype.open = function(m,u,a,u1,u2){ xhrUrl = u; try { this.__hzUrl = u; } catch(e) {} return oopen.apply(this, arguments); }
        XMLHttpRequest.prototype.send = function(b){
          try {
            if (xhrUrl && (mediaRe.test(xhrUrl) || subRe.test(xhrUrl))) { post(xhrUrl); }
            this.addEventListener('readystatechange', function(){
              try {
                if (this.readyState === 2 || this.readyState === 4) {
                  const ct = this.getResponseHeader && (this.getResponseHeader('content-type')||'');
                  const u = this.responseURL || this.__hzUrl || xhrUrl || '';
                  if (ct && /(text\/vtt|application\/x-subrip)/i.test(ct)) { try { const t = (this.responseText||''); post(u, {type: 'subtitle', body: t}); } catch(e) { post(u, {type: 'subtitle'}); } }
                  else if ((ct && /application\/json|text\/plain|application\/octet-stream/i.test(ct)) || !ct) {
                    try {
                      const t = (this.responseText||'');
                      if (t && (/^(WEBVTT)/m.test(t) || /-->/.test(t))) { post(u, {type:'subtitle', body: t}); }
                      const abs = t.match(/https?:[^"'\s>]+\.(vtt|srt)(\?[^"'\s>]*)?/ig);
                      if (abs && abs.length){ for (const x of abs){ post(x, {type:'subtitle'}); } }
                      const rel = t.match(/['\"\(\s]((?:\/|\.\/|\.\.\/)[^'\"\s>]+\.(?:vtt|srt)(?:\?[^"'\s>]*)?)/ig);
                      if (rel && rel.length){ for (const m of rel){ const p = m.replace(/^['\"\(\s]+/, ''); post(p, {type:'subtitle'}); } }
                    } catch(e) {}
                  }
                }
              } catch(e) {}
            });
          } catch(e) {}
          return osend.apply(this, arguments);
        };
        // Scan <video> periodically
        function scan(){
          try {
            const vids = document.querySelectorAll('video');
            for (const v of vids){
              const src = v.currentSrc || v.src || '';
              if (src && (mediaRe.test(src) || subRe.test(src))) post(src);
              const sources = v.querySelectorAll('source');
              for (const s of sources){ const u=s.src||''; if (u && (mediaRe.test(u) || subRe.test(u))) post(u); }
              const tracks = v.querySelectorAll('track');
              for (const t of tracks){ const u=t.src||''; if (u && subRe.test(u)) post(u, {label: (t.label||t.getAttribute('label')||''), lang: (t.srclang||t.getAttribute('srclang')||''), def: (t.default||t.getAttribute('default'))?1:0}); }
              // Ensure textTracks load: set mode to 'hidden' to trigger fetch without showing
              const tts = (v.textTracks||[]);
              for (let i=0;i<tts.length;i++){
                const tt = tts[i];
                try { if (tt && tt.mode === 'disabled') { tt.mode = 'hidden'; } } catch(e){}
                const label = (tt.label||'');
                const lang = (tt.language||'');
                try {
                  const cues = tt.cues; if (!cues || cues.length===0) continue;
                  const key = (label||lang||'')+"|"+cues.length;
                  if (hzDumped[key]) continue;
                  let vtt = 'WEBVTT\n\n';
                  for (let j=0;j<cues.length;j++){
                    const c = cues[j];
                    const s = secToVttTime(c.startTime||0);
                    const e = secToVttTime(c.endTime||0);
                    const text = (c.text||c.payload||'');
                    vtt += s+" --> "+e+"\n"+text+"\n\n";
                  }
                  hzDumped[key] = 1;
                  post('inline:'+encodeURIComponent(label||lang||('track'+i)), {type:'subtitle', label: label, lang: lang, body: vtt});
                } catch(e){}
              }
            }
            // Scan inline <script> text for embedded subtitle URLs or inline WEBVTT
            try {
              const scripts = document.querySelectorAll('script');
              for (const sc of scripts){
                const t = sc.textContent || '';
                if (!t) continue;
                if (/^(WEBVTT)/m.test(t) || /-->/.test(t)) { post('inline:'+encodeURIComponent('script'), {type:'subtitle', body: t}); }
                const abs = t.match(/https?:[^"'\s>]+\.(vtt|srt)(\?[^"'\s>]*)?/ig);
                if (abs && abs.length){ for (const x of abs){ post(x, {type:'subtitle'}); } }
                const rel = t.match(/['\"\(\s]((?:\/|\.\/|\.\.\/)[^'\"\s>]+\.(?:vtt|srt)(?:\?[^'\"\s>]*)?)/ig);
                if (rel && rel.length){ for (const m of rel){ const p = m.replace(/^['\"\(\s]+/, ''); post(p, {type:'subtitle'}); } }
              }
            } catch(e){}
            // Provider-specific: Next.js __NEXT_DATA__ parser (vidplus)
            try { parseNextData(); } catch(e){}
          } catch(e) {}
        }
        setInterval(scan, 1200);
        try {
          const mo = new MutationObserver(function(){ try { scan(); } catch(e){} });
          mo.observe(document.documentElement || document.body, { childList: true, subtree: true });
        } catch(e){}
        scan();
      } catch(e) {}
    })();
  ''';

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && _resolving) {
        setState(() {
          _failed = true;
          _resolving = false;
        });
      }
    });
    _loaderCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _loaderCtrl, curve: Curves.easeInOut));
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  void _injectCapture() async {
    try {
      await _wv?.evaluateJavascript(source: _captureJS);
    } catch (_) {}
  }

  Future<bool> _probeUrl(String url, Map<String, String> headers) async {
    // Quick HEAD, fallback to tiny ranged GET. Accept both video/* and HLS content-types.
    try {
      final resp = await http
          .head(Uri.parse(url), headers: headers)
          .timeout(const Duration(milliseconds: 1500));
      final code = resp.statusCode;
      final ct = (resp.headers['content-type'] ?? '').toLowerCase();
      if (code >= 200 && code < 300) {
        if (ct.startsWith('video/') ||
            ct.contains('mpegurl') ||
            ct.contains('dash') ||
            ct.contains('mp2t') ||
            ct.contains('octet-stream')) {
          return true;
        }
        // If content-type is missing, rely on extension hint
        final u = url.toLowerCase();
        if (u.contains('.m3u8') ||
            u.contains('.mp4') ||
            u.contains('.webm') ||
            u.contains('.ts') ||
            u.contains('manifest.mpd')) {
          return true;
        }
      }
    } catch (_) {}
    try {
      final h = Map<String, String>.from(headers);
      h['Range'] = 'bytes=0-1';
      h.putIfAbsent(
        'Accept',
        () => 'application/x-mpegURL,video/*;q=0.9,*/*;q=0.8',
      );
      final resp = await http
          .get(Uri.parse(url), headers: h)
          .timeout(const Duration(milliseconds: 1500));
      final code = resp.statusCode;
      final ct = (resp.headers['content-type'] ?? '').toLowerCase();
      if (code == 206 || (code >= 200 && code < 300)) {
        if (ct.startsWith('video/') ||
            ct.contains('mpegurl') ||
            ct.contains('dash') ||
            ct.contains('mp2t') ||
            ct.contains('octet-stream')) {
          return true;
        }
        final u = url.toLowerCase();
        if (u.contains('.m3u8') ||
            u.contains('.mp4') ||
            u.contains('.webm') ||
            u.contains('.ts') ||
            u.contains('manifest.mpd')) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<PlaybackSource?> _pickFirstPlayable(List<PlaybackSource> list) async {
    if (list.isEmpty) return null;
    // Prefer HLS first
    final sorted = List<PlaybackSource>.from(list);
    sorted.sort((a, b) {
      final ah = a.url.toLowerCase().contains('.m3u8') ? 0 : 1;
      final bh = b.url.toLowerCase().contains('.m3u8') ? 0 : 1;
      return ah.compareTo(bh);
    });
    // Probe top few in parallel and take the first success
    final probe = sorted.take(6).toList();
    final completer = Completer<PlaybackSource?>();
    for (final s in probe) {
      // Fire and forget; first success completes
      _probeUrl(s.url, s.headers).then((ok) {
        if (ok && !completer.isCompleted) completer.complete(s);
      });
    }
    // Global timeout guard - reduced from 4s to 2s for faster fallback
    Future.delayed(const Duration(seconds: 2), () {
      if (!completer.isCompleted) completer.complete(null);
    });
    return completer.future;
  }

  Future<void> _handleCandidate(
    String captured, {
    Map<String, String>? extraHeaders,
  }) async {
    try {
      if (captured.isEmpty) return;

      Uri? capturedUri;
      try {
        capturedUri = Uri.parse(captured);
      } catch (_) {}

      String realUrl = captured;
      String? headerOrigin;
      String? headerReferer;
      if (capturedUri != null) {
        final qp = capturedUri.queryParameters;
        final uParam = qp['u'] ?? qp['url'];
        if (uParam != null && uParam.isNotEmpty) {
          realUrl = Uri.decodeComponent(uParam);
        }
        headerOrigin =
            qp['o'] ?? extraHeaders?['Origin'] ?? extraHeaders?['origin'];
        headerReferer =
            qp['r'] ?? extraHeaders?['Referer'] ?? extraHeaders?['referer'];
      }

      // Resolve relative URLs (like /api/embed-proxy?url=...) against embed origin
      try {
        final parsedReal = Uri.parse(realUrl);
        if (!parsedReal.hasScheme) {
          final base = Uri.parse(widget.embedUrl);
          realUrl = base.resolveUri(parsedReal).toString();
        }
      } catch (_) {}

      // Remember last seen r/o to use during navigation
      if ((headerOrigin != null && headerOrigin.isNotEmpty) ||
          (headerReferer != null && headerReferer.isNotEmpty)) {
        _lastHeaderOrigin = headerOrigin ?? _lastHeaderOrigin;
        _lastHeaderReferer = headerReferer ?? _lastHeaderReferer;
      }

      final playableRe = RegExp(
        r'(\.m3u8($|\?)|\.mp4($|\?)|\.webm($|\?)|\.ts($|\?)|manifest\.mpd|embed-proxy|/api/embed-proxy|/proxy)',
        caseSensitive: false,
      );
      final isProxyCandidate =
          ((capturedUri?.host.contains('proxy') ?? false) ||
          RegExp(
            r'(embed-proxy|/api/embed-proxy|/proxy)',
            caseSensitive: false,
          ).hasMatch(captured));
      if (!playableRe.hasMatch(realUrl) && !isProxyCandidate) return;

      // Track proxy wrapper candidate too, as some providers only honor proxy referer
      if (capturedUri != null &&
          (isProxyCandidate || playableRe.hasMatch(captured))) {
        if (!_candidates.contains(captured)) {
          _candidates.add(captured);
        }
      }
      if (!_candidates.contains(realUrl)) {
        _candidates.add(realUrl);
      }

      if (_navigated || _aggregating) return;
      _aggregating = true;
      _timeoutTimer?.cancel();
      _aggStart ??= DateTime.now();
      setState(() => _loadingStatus = 'Searching for best streams...');
      // Minimum wait to let HLS/subtitles surface
      await Future.delayed(const Duration(milliseconds: _aggMinMs));

      // Don't wait for subtitles - fetch them in background via SubtitleService
      // This keeps player launch fast

      if (_navigated) {
        _aggregating = false;
        return;
      }

      // Choose stream priority: proxy+HLS > proxy > HLS > first
      bool isProxyUrl(String u) {
        final host = Uri.tryParse(u)?.host ?? '';
        if (host.contains('proxy')) return true;
        return RegExp(
          r'(embed-proxy|/api/embed-proxy|/proxy)',
          caseSensitive: false,
        ).hasMatch(u);
      }

      String chosen = _candidates.first;
      final proxyHls = _candidates.firstWhere(
        (u) => isProxyUrl(u) && u.toLowerCase().contains('.m3u8'),
        orElse: () => '',
      );
      final proxyAny = _candidates.firstWhere(
        (u) => isProxyUrl(u),
        orElse: () => '',
      );
      final anyHls = _candidates.firstWhere(
        (u) => u.toLowerCase().contains('.m3u8'),
        orElse: () => '',
      );
      if (proxyHls.isNotEmpty) {
        chosen = proxyHls;
      } else if (proxyAny.isNotEmpty)
        chosen = proxyAny;
      else if (anyHls.isNotEmpty)
        chosen = anyHls;

      final embedUri = Uri.parse(widget.embedUrl);
      final embedOrigin = embedUri.origin;
      final embedHost = embedUri.host;
      Future<Map<String, String>> buildHeaders(
        String url, {
        String? referer,
        String? origin,
        bool includeOrigin = true,
        bool includeUA = true,
        String? ua,
      }) async {
        final isHls = url.toLowerCase().contains('.m3u8');
        final host = Uri.tryParse(url)?.host ?? '';
        final isEmbedHost = host == embedHost;
        final defaultReferer = (referer != null && referer.isNotEmpty)
            ? referer
            : (_lastHeaderReferer?.isNotEmpty == true
                  ? _lastHeaderReferer!
                  : widget.embedUrl);
        final defaultOrigin = (origin != null && origin.isNotEmpty)
            ? origin
            : (_lastHeaderOrigin?.isNotEmpty == true
                  ? _lastHeaderOrigin!
                  : embedOrigin);
        final nonce = DateTime.now().millisecondsSinceEpoch.toString();
        final map = <String, String>{
          if (includeUA)
            'User-Agent':
                ua ??
                'Mozilla/5.0 (Linux; Android 12; HZFlix) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36',
          'Referer': defaultReferer,
          if (includeOrigin) 'Origin': defaultOrigin,
          'Accept': isHls
              ? 'application/x-mpegURL,video/*;q=0.9,*/*;q=0.8'
              : 'video/mp4,video/*;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Sec-Fetch-Site': isEmbedHost ? 'same-origin' : 'cross-site',
          'Sec-Fetch-Mode': 'cors',
          'Sec-Fetch-Dest': 'video',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
          'X-Playback-Nonce': nonce,
        };
        try {
          final cookies = await _cookieManager.getCookies(url: WebUri(url));
          if (cookies.isNotEmpty) {
            final cookieHeader = cookies
                .map((c) => '${c.name}=${c.value}')
                .join('; ');
            if (cookieHeader.isNotEmpty) map['Cookie'] = cookieHeader;
          }
        } catch (_) {}
        return map;
      }

      // De-duplicate while building prioritized list: chosen first, then proxy, then direct
      final seen = <String>{};
      final sources = <PlaybackSource>[];
      Future<void> addCombos(
        String url, {
        String? referer,
        String? origin,
      }) async {
        if (seen.contains(url)) return;
        seen.add(url);
        final host = Uri.tryParse(url)?.host ?? '';
        final isEmbedHost = host == embedHost;
        // Order attempts to minimize 403s:
        // - For embed host (proxy endpoints): include Origin first, then desktop UA, then no-Origin as last fallback.
        // - For cross-host direct links: no-Origin first, then desktop UA, then with-Origin last.
        if (isEmbedHost) {
          final hA = await buildHeaders(
            url,
            referer: referer,
            origin: origin,
            includeOrigin: true,
            includeUA: true,
          );
          sources.add(PlaybackSource(url: url, headers: hA));
          final hB = await buildHeaders(
            url,
            referer: referer,
            origin: origin,
            includeOrigin: true,
            includeUA: true,
            ua: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36',
          );
          sources.add(PlaybackSource(url: url, headers: hB));
          final hC = await buildHeaders(
            url,
            referer: referer,
            origin: origin,
            includeOrigin: false,
            includeUA: true,
          );
          sources.add(PlaybackSource(url: url, headers: hC));
        } else {
          final hA = await buildHeaders(
            url,
            referer: referer,
            origin: origin,
            includeOrigin: false,
            includeUA: true,
            ua: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36',
          );
          sources.add(PlaybackSource(url: url, headers: hA));
          final hB = await buildHeaders(
            url,
            referer: referer,
            origin: origin,
            includeOrigin: false,
            includeUA: true,
          );
          sources.add(PlaybackSource(url: url, headers: hB));
          final hC = await buildHeaders(
            url,
            referer: referer,
            origin: origin,
            includeOrigin: true,
            includeUA: true,
          );
          sources.add(PlaybackSource(url: url, headers: hC));
        }
      }

      // 1) chosen
      await addCombos(
        chosen,
        referer: _lastHeaderReferer,
        origin: _lastHeaderOrigin,
      );
      // 2) any proxy among candidates
      for (final u in _candidates) {
        bool isProxyUrl(String u) {
          final host = Uri.tryParse(u)?.host ?? '';
          if (host.contains('proxy')) return true;
          return RegExp(
            r'(embed-proxy|/api/embed-proxy|/proxy)',
            caseSensitive: false,
          ).hasMatch(u);
        }

        if (isProxyUrl(u)) {
          await addCombos(
            u,
            referer: _lastHeaderReferer,
            origin: _lastHeaderOrigin,
          );
        }
      }
      // 3) direct real urls: if proxy exists, only add at most 1 direct fallback to avoid many 403 retries
      final hasProxy = _candidates.any((u) => isProxyUrl(u));
      int addedDirect = 0;
      for (final u in _candidates) {
        if (hasProxy && addedDirect >= 1) break;
        if (isProxyUrl(u)) continue;
        await addCombos(
          u,
          referer: _lastHeaderReferer,
          origin: _lastHeaderOrigin,
        );
        addedDirect++;
      }

      // Build subtitle sources from SubtitleService
      // Fetch subtitles synchronously before player launch
      final subSources = <SubtitleSource>[];

      // Fetch subtitles synchronously before player launch
      if (widget.movieId != null || widget.showId != null) {
        try {
          final searchId = (widget.movieId ?? widget.showId).toString();

          // Parse season and episode from seasonEpisode (format: "S3:E6")
          int? season;
          int? episode;
          if (widget.isTV && widget.seasonEpisode != null) {
            final parts = widget.seasonEpisode!.split(':');
            if (parts.length == 2) {
              season = int.tryParse(parts[0].replaceFirst('S', ''));
              episode = int.tryParse(parts[1].replaceFirst('E', ''));
            }
          }

          final items = await SubtitleService.searchById(
            searchId,
            season: season,
            episode: episode,
          );

          if (items.isNotEmpty) {
            final selected = SubtitleService.selectForPlayer(items);
            for (final sub in selected) {
              try {
                // Basic headers for subtitle fetching
                final headers = <String, String>{
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                  'Accept': 'text/vtt,application/x-subrip,text/plain',
                };
                subSources.add(
                  SubtitleSource(
                    url: sub.url,
                    headers: headers,
                    label: sub.label,
                    lang: sub.lang,
                  ),
                );
              } catch (_) {}
            }
          }
        } catch (e) {
          print('[StreamResolver] Subtitle fetch error: $e');
        }
      }

      // Prefer HLS first and pick a playable source by quick preflight
      sources.sort((a, b) {
        final ah = a.url.toLowerCase().contains('.m3u8') ? 0 : 1;
        final bh = b.url.toLowerCase().contains('.m3u8') ? 0 : 1;
        return ah.compareTo(bh);
      });
      final picked = await _pickFirstPlayable(sources) ?? sources.first;
      // Build a trimmed alternates list - reduced from 6 to 3 for faster startup
      final finalSources = <PlaybackSource>[];
      finalSources.add(picked);
      for (final s in sources) {
        if (identical(s, picked)) continue;
        if (finalSources.length >= 3) break;
        finalSources.add(s);
      }

      _navigated = true;
      _aggregating = false;
      _resolving = false;
      setState(() => _loadingStatus = 'Ready to play!');
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;

      // For TV shows, use showId as movieId to track watch history
      final effectiveMovieId = widget.movieId ?? widget.showId;
      print('');
      print('═══════════════════════════════════════════════════════════════');
      print('[StreamResolver] Launching UniversalPlayerScreen');
      print('[StreamResolver] movieId: $effectiveMovieId');
      print('[StreamResolver] seasonEpisode: ${widget.seasonEpisode}');
      print('[StreamResolver] isTV: ${widget.isTV}');
      print('[StreamResolver] title: ${widget.title}');
      print('═══════════════════════════════════════════════════════════════');
      print('');

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => UniversalPlayerScreen(
            title: widget.title,
            streamUrl: finalSources.first.url,
            headers: finalSources.first.headers,
            alternateSources: finalSources.skip(1).toList(),
            subtitles: subSources,
            movieId: effectiveMovieId,
            seasonEpisode: widget.seasonEpisode,
            posterPath: widget.posterPath,
          ),
        ),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _loaderCtrl.dispose();
    _spinCtrl.dispose();
    _orbitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.embedUrl)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              allowsInlineMediaPlayback: true,
              mediaPlaybackRequiresUserGesture: false,
              useShouldInterceptRequest: true,
              userAgent:
                  'Mozilla/5.0 (Linux; Android 12; HZFlix) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36',
              thirdPartyCookiesEnabled: true,
            ),
            onWebViewCreated: (controller) {
              _wv = controller;
              try {
                _wv?.clearCache();
              } catch (_) {}
              _wv?.addJavaScriptHandler(
                handlerName: 'HZLink',
                callback: (args) async {
                  try {
                    if (args.isNotEmpty) {
                      final data = args[0];
                      if (data is Map) {
                        final url = (data['url']?.toString() ?? '').trim();
                        final type = (data['type']?.toString() ?? 'media')
                            .trim()
                            .toLowerCase();
                        if (url.isNotEmpty && type == 'media') {
                          await _handleCandidate(url);
                        }
                        // Subtitle scraping removed - using SubtitleService instead
                      }
                    }
                  } catch (_) {}
                  return null;
                },
              );
            },
            onLoadStart: (controller, url) {
              _injectCapture();
            },
            onLoadStop: (controller, url) {
              _injectCapture(); // backup scan if needed
            },
            onConsoleMessage: (controller, consoleMessage) {
              // debug prints if needed
            },
            onLoadResource: (controller, resource) async {
              final url = resource.url.toString();
              // Capture any resource
              await _handleCandidate(url);
            },
            shouldInterceptRequest: (controller, request) async {
              final url = request.url.toString();
              final headers = <String, String>{};
              request.headers?.forEach((k, v) => headers[k] = v.toString());
              await _handleCandidate(url, extraHeaders: headers);
              return null; // don't block
            },
          ),
          if (_resolving) Positioned.fill(child: _buildFindingOverlay()),
          if (_failed)
            Positioned.fill(
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Could not auto-detect stream',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _failed = false;
                          _resolving = true;
                        });
                        _wv?.reload();
                        _timeoutTimer?.cancel();
                        _timeoutTimer = Timer(const Duration(seconds: 60), () {
                          if (mounted && _resolving) {
                            setState(() {
                              _failed = true;
                              _resolving = false;
                            });
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.redAccent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFindingOverlay() {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _spinCtrl,
                  builder: (_, __) {
                    return Transform.rotate(
                      angle: _spinCtrl.value * 2 * math.pi,
                      child: CustomPaint(
                        painter: _RingPainter(color: AppTheme.redAccent),
                        size: const Size(140, 140),
                      ),
                    );
                  },
                ),
                AnimatedBuilder(
                  animation: _orbitCtrl,
                  builder: (_, __) {
                    final t = _orbitCtrl.value * 2 * math.pi;
                    final r = 70.0;
                    return Stack(
                      children: [
                        Transform.translate(
                          offset: Offset(r * math.cos(t), r * math.sin(t)),
                          child: _orbitDot(10.0, Colors.white.withOpacity(0.9)),
                        ),
                        Transform.translate(
                          offset: Offset(
                            r * math.cos(t + math.pi),
                            r * math.sin(t + math.pi),
                          ),
                          child: _orbitDot(8.0, Colors.white30),
                        ),
                      ],
                    );
                  },
                ),
                ScaleTransition(
                  scale: _pulse,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppTheme.redAccent, Colors.redAccent],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.redAccent.withOpacity(0.4),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _shimmerText(_loadingStatus),
        ],
      ),
    );
  }

  Widget _orbitDot(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.6),
            blurRadius: 8,
            spreadRadius: 0.5,
          ),
        ],
      ),
    );
  }

  Widget _shimmerText(String text) {
    return AnimatedBuilder(
      animation: _spinCtrl,
      builder: (_, __) {
        final shift = (_spinCtrl.value * 2) - 1; // -1..1
        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment(-1.5 + shift, 0),
              end: Alignment(1.5 + shift, 0),
              colors: const [Colors.white24, Colors.white, Colors.white24],
              stops: const [0.25, 0.5, 0.75],
            ).createShader(rect);
          },
          blendMode: BlendMode.srcATop,
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}
