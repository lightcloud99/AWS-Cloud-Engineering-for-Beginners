#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  Light Cloud · Zero to Job-Ready on AWS
#  Episode: Security Groups & Network ACLs
#  Serves an animated page that proves BOTH firewalls said yes.
# ─────────────────────────────────────────────────────────────
set -x

dnf install -y httpd
systemctl enable --now httpd

# ── IMDSv2: get a token, then read the metadata ──────────────
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

md() {
  curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    "http://169.254.169.254/latest/meta-data/$1"
}

AZ=$(md placement/availability-zone)
AZID=$(md placement/availability-zone-id)
REGION=$(md placement/region)
IID=$(md instance-id)
ITYPE=$(md instance-type)
PRIV=$(md local-ipv4)

# fall back gracefully if IMDS is ever unreachable
AZ=${AZ:-unknown}
AZID=${AZID:-unknown}
REGION=${REGION:-unknown}
IID=${IID:-unknown}
ITYPE=${ITYPE:-unknown}
PRIV=${PRIV:-unknown}

# ── the page. quoted heredoc, so the shell touches nothing ───
cat > /var/www/html/index.html <<'PAGE'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Cache-Control" content="no-store">
<title>It's alive — Light Cloud AWS</title>
<style>
  :root{
    --ink:#161E2D; --panel:#1F2A3D; --line:#37465F;
    --paper:#F3EFE7; --dim:#9AA7BC;
    --amber:#FF9900; --mint:#3EDC97; --coral:#FF6B6B;
    --sky:#61B3FF; --violet:#8A4FFF;
  }
  *{margin:0;padding:0;box-sizing:border-box}
  html,body{min-height:100%}
  body{
    background:var(--ink); color:var(--paper);
    font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
    display:flex; align-items:center; justify-content:center;
    padding:48px 20px; position:relative; overflow-x:hidden;
  }
  /* drifting grid + glow */
  body::before{
    content:""; position:fixed; inset:0; z-index:0; pointer-events:none;
    background-image:
      linear-gradient(var(--panel) 1px,transparent 1px),
      linear-gradient(90deg,var(--panel) 1px,transparent 1px);
    background-size:56px 56px; opacity:.33;
  }
  body::after{
    content:""; position:fixed; z-index:0; pointer-events:none;
    width:70vw; height:70vw; right:-18vw; top:-24vw; border-radius:50%;
    background:radial-gradient(circle,rgba(255,153,0,.16),transparent 62%);
    animation:drift 16s ease-in-out infinite alternate;
  }
  @keyframes drift{from{transform:translate(0,0) scale(1)}
                   to{transform:translate(-6vw,8vw) scale(1.15)}}

  .wrap{position:relative; z-index:1; width:100%; max-width:860px; text-align:center}

  .rise{opacity:0; transform:translateY(22px); animation:rise .7s cubic-bezier(.2,.7,.3,1) forwards}
  @keyframes rise{to{opacity:1;transform:none}}
  .d1{animation-delay:.15s} .d2{animation-delay:.35s} .d3{animation-delay:.6s}
  .d4{animation-delay:.9s}  .d5{animation-delay:1.2s} .d6{animation-delay:1.5s}
  .d7{animation-delay:1.85s}

  /* live badge */
  .live{
    display:inline-flex; align-items:center; gap:10px;
    font:600 13px/1 ui-monospace,SFMono-Regular,Menlo,monospace;
    letter-spacing:.22em; color:var(--mint);
    border:1px solid rgba(62,220,151,.4); background:rgba(62,220,151,.08);
    padding:9px 16px; border-radius:999px;
  }
  .dot{width:9px;height:9px;border-radius:50%;background:var(--mint);
       animation:beat 1.6s ease-in-out infinite}
  @keyframes beat{0%,100%{box-shadow:0 0 0 0 rgba(62,220,151,.55)}
                  70%{box-shadow:0 0 0 11px rgba(62,220,151,0)}}

  h1{font-size:clamp(2.6rem,9vw,5rem); line-height:1.02; letter-spacing:-.03em;
     font-weight:800; margin:26px 0 14px}
  h1 em{font-style:normal; color:var(--amber);
        animation:flare 3.2s ease-in-out infinite}
  @keyframes flare{0%,100%{text-shadow:0 0 28px rgba(255,153,0,.35)}
                   50%{text-shadow:0 0 54px rgba(255,153,0,.75)}}

  .ep{font:600 14px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace;
      letter-spacing:.16em; color:var(--violet); text-transform:uppercase}
  .tag{color:var(--dim); font-size:clamp(1rem,2.6vw,1.18rem); line-height:1.6;
       max-width:52ch; margin:16px auto 0}
  .tag b{color:var(--paper); font-weight:600}

  /* ── the packet journey ── */
  .journey{position:relative; margin:42px auto 8px; max-width:720px;
           padding:26px 16px 18px;
           border:1px solid var(--line); border-radius:18px;
           background:rgba(31,42,61,.55)}
  .rail{position:absolute; left:11%; right:11%; top:56px; height:2px;
        background:var(--line)}
  .packet{position:absolute; top:51px; width:12px; height:12px; border-radius:50%;
          background:var(--mint); box-shadow:0 0 16px rgba(62,220,151,.9);
          animation:travel 3.4s cubic-bezier(.5,0,.5,1) infinite}
  @keyframes travel{
    0%{left:8%;opacity:0} 8%{opacity:1}
    92%{opacity:1} 100%{left:88%;opacity:0}}
  .stops{display:flex; justify-content:space-between; position:relative}
  .stop{flex:1; display:flex; flex-direction:column; align-items:center; gap:9px}
  .node{width:46px;height:46px;border-radius:13px;display:grid;place-items:center;
        border:2px solid var(--line); background:var(--ink); font-size:19px}
  .node.nacl{border-color:var(--violet); color:#C4A8FF}
  .node.sg{border-color:var(--amber); color:var(--amber)}
  .node.me{border-color:var(--mint); color:var(--mint);
           box-shadow:0 0 26px rgba(62,220,151,.3)}
  .nlabel{font:600 11px/1.3 ui-monospace,SFMono-Regular,Menlo,monospace;
          letter-spacing:.1em; color:var(--dim); text-align:center}
  .ok{position:absolute; top:-7px; right:-7px; width:19px; height:19px;
      border-radius:50%; background:var(--mint); color:#10231A;
      font:800 12px/19px system-ui; transform:scale(0);
      animation:pop .45s cubic-bezier(.34,1.56,.64,1) forwards}
  .nw{position:relative}
  .ok.a{animation-delay:1.9s} .ok.b{animation-delay:2.25s}
  @keyframes pop{to{transform:scale(1)}}
  .verdict{margin-top:16px; font:600 13px/1.5 ui-monospace,monospace;
           color:var(--mint); letter-spacing:.04em}

  /* ── metadata chips ── */
  .meta{display:flex; flex-wrap:wrap; gap:10px; justify-content:center; margin-top:30px}
  .chip{border:1px solid var(--line); background:rgba(31,42,61,.7);
        border-radius:11px; padding:10px 15px; text-align:left}
  .chip span{display:block; font:600 10px/1.4 ui-monospace,monospace;
             letter-spacing:.14em; color:var(--dim); text-transform:uppercase}
  .chip b{font:700 14px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace;
          color:var(--sky)}
  .chip.hot b{color:var(--amber)}

  /* ── call to action ── */
  .cta{margin-top:40px; border:1px solid var(--line); border-radius:20px;
       background:rgba(31,42,61,.68); padding:30px 24px}
  .cta h2{font-size:clamp(1.3rem,4vw,1.7rem); letter-spacing:-.02em; margin-bottom:10px}
  .cta p{color:var(--dim); font-size:1rem; line-height:1.65; max-width:48ch; margin:0 auto}
  .btns{display:flex; gap:14px; justify-content:center; flex-wrap:wrap; margin-top:24px}
  .btn{display:inline-flex; align-items:center; gap:10px; text-decoration:none;
       font-weight:700; font-size:1rem; padding:15px 28px; border-radius:13px;
       border:2px solid transparent; transition:transform .18s ease, box-shadow .18s ease}
  .btn:hover{transform:translateY(-2px)}
  .btn.sub{background:var(--amber); color:#141A24;
           animation:breathe 2.6s ease-in-out infinite}
  .btn.sub:hover{box-shadow:0 10px 34px rgba(255,153,0,.38)}
  @keyframes breathe{0%,100%{box-shadow:0 0 0 0 rgba(255,153,0,.42)}
                     70%{box-shadow:0 0 0 17px rgba(255,153,0,0)}}
  .btn.ghost{border-color:var(--line); color:var(--paper)}
  .btn.ghost:hover{border-color:var(--mint); color:var(--mint)}
  .hint{margin-top:18px; font-size:.88rem; color:var(--dim)}
  .hint b{color:var(--amber)}

  footer{margin-top:34px; font:500 13px/1.6 ui-monospace,monospace; color:#5D6B83}
  footer b{color:var(--dim)}

  @media (prefers-reduced-motion:reduce){
    *{animation:none!important; transition:none!important}
    .rise{opacity:1; transform:none}
    .ok{transform:scale(1)}
  }
  @media (max-width:560px){
    .rail{top:52px} .packet{top:47px}
    .node{width:40px;height:40px;font-size:16px}
    .nlabel{font-size:9.5px}
  }
</style>
</head>
<body>
<div class="wrap">

  <div class="rise d1"><span class="live"><span class="dot"></span>SERVING</span></div>

  <h1 class="rise d2">It's <em>alive</em></h1>

  <div class="rise d3">
    <div class="ep">Zero to Job-Ready on AWS &middot; Security Groups &amp; Network ACLs</div>
    <p class="tag">This page only reached you because <b>two separate firewalls</b>
       agreed to let it through — the Network ACL at the subnet edge, and the
       Security Group around this instance.</p>
  </div>

  <!-- packet journey -->
  <div class="journey rise d4">
    <div class="rail"></div>
    <div class="packet"></div>
    <div class="stops">
      <div class="stop"><div class="node">&#127758;</div><div class="nlabel">INTERNET</div></div>
      <div class="stop">
        <div class="nw"><div class="node nacl">&#9776;</div><div class="ok a">&#10003;</div></div>
        <div class="nlabel">NETWORK ACL<br>subnet</div>
      </div>
      <div class="stop">
        <div class="nw"><div class="node sg">&#128737;</div><div class="ok b">&#10003;</div></div>
        <div class="nlabel">SECURITY GROUP<br>instance</div>
      </div>
      <div class="stop"><div class="node me">&#9881;</div><div class="nlabel">THIS SERVER</div></div>
    </div>
    <div class="verdict">both checkpoints said yes</div>
  </div>

  <!-- live metadata -->
  <div class="meta rise d5">
    <div class="chip"><span>availability zone</span><b>__AZ__</b></div>
    <div class="chip hot"><span>az id &middot; the real building</span><b>__AZID__</b></div>
    <div class="chip"><span>region</span><b>__REGION__</b></div>
    <div class="chip"><span>instance</span><b>__IID__</b></div>
    <div class="chip"><span>type</span><b>__ITYPE__</b></div>
    <div class="chip"><span>private ip</span><b>__PRIV__</b></div>
    <div class="chip"><span>uptime</span><b id="up">&mdash;</b></div>
  </div>

  <!-- CTA -->
  <div class="cta rise d6">
    <h2>You just built this yourself.</h2>
    <p>The whole course is free — VPCs, EC2, IAM, Auto Scaling, Load Balancers,
       and the firewalls that got this page to your screen. Built hands-on,
       from the console, start to finish.</p>
    <div class="btns">
      <a class="btn sub" href="https://www.youtube.com/@lightcloud9?sub_confirmation=1"
         target="_blank" rel="noopener">&#9654;&nbsp; Subscribe to Light Cloud</a>
      <a class="btn ghost" href="https://www.youtube.com/playlist?list=PLV6bFfc-yYjE"
         target="_blank" rel="noopener">&#128218;&nbsp; Open the free course</a>
    </div>
    <p class="hint">If the course helped, <b>like the video</b> and leave a comment
       telling me what you want covered next. It genuinely decides what I build.</p>
  </div>

  <footer class="rise d7">
    Light Cloud &middot; <b>Uche Ugochukwu</b><br>
    learn AWS by building it, not by watching it
  </footer>

</div>

<script>
  // uptime counter, no dependencies
  var t0 = Date.now();
  function pad(n){ return (n < 10 ? "0" : "") + n; }
  function tick(){
    var s = Math.floor((Date.now() - t0) / 1000);
    var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
    document.getElementById("up").textContent = pad(h) + ":" + pad(m) + ":" + pad(s % 60);
  }
  tick(); setInterval(tick, 1000);
</script>
</body>
</html>
PAGE

# ── drop the live values in ──────────────────────────────────
sed -i \
  -e "s|__AZ__|$AZ|g" \
  -e "s|__AZID__|$AZID|g" \
  -e "s|__REGION__|$REGION|g" \
  -e "s|__IID__|$IID|g" \
  -e "s|__ITYPE__|$ITYPE|g" \
  -e "s|__PRIV__|$PRIV|g" \
  /var/www/html/index.html

# ── stop the browser caching it between firewall tests ───────
cat > /etc/httpd/conf.d/nocache.conf <<'CONF'
<IfModule mod_headers.c>
  <FilesMatch "\.(html)$">
    Header set Cache-Control "no-store, no-cache, must-revalidate, max-age=0"
    Header set Pragma "no-cache"
  </FilesMatch>
</IfModule>
CONF

systemctl restart httpd
