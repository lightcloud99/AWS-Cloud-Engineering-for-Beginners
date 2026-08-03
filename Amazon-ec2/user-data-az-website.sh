#!/bin/bash
# ============================================================
#  AWS Hands-On Training with Uche Ugochukwu
#  EC2 User Data: self-building website that shows where
#  this instance lives (Availability Zone, Region, ID, Type)
# ============================================================

# Update the system and install Apache
yum update -y
yum install -y httpd

# Start Apache now, and on every future boot
systemctl start httpd
systemctl enable httpd

# ------------------------------------------------------------
# Fetch instance metadata using IMDSv2 (token-based, the
# secure way). The token is our temporary pass to ask the
# metadata service questions about this instance.
# ------------------------------------------------------------
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/region)

INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

INSTANCE_TYPE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-type)

# ------------------------------------------------------------
# Build the homepage. NOTE: the heredoc below is unquoted on
# purpose, so bash fills in $AZ, $REGION, $INSTANCE_ID and
# $INSTANCE_TYPE before writing the file.
# ------------------------------------------------------------
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Live from Availability Zone $AZ</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    min-height: 100vh;
    background: #161E2D;
    background-image:
      linear-gradient(rgba(31,42,61,.8) 1px, transparent 1px),
      linear-gradient(90deg, rgba(31,42,61,.8) 1px, transparent 1px);
    background-size: 56px 56px;
    color: #F3EFE7;
    font-family: Arial, Helvetica, sans-serif;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 40px 20px;
    text-align: center;
  }
  .badge {
    display: inline-block;
    border: 1px solid #FF9900;
    color: #FF9900;
    border-radius: 999px;
    padding: 8px 22px;
    font-size: 14px;
    letter-spacing: 2px;
    text-transform: uppercase;
    margin-bottom: 28px;
  }
  h1 {
    font-size: clamp(28px, 5vw, 52px);
    line-height: 1.15;
    margin-bottom: 14px;
  }
  h1 span { color: #FF9900; }
  .tagline {
    color: #9AA7BC;
    font-size: clamp(15px, 2vw, 19px);
    margin-bottom: 44px;
  }
  .az-card {
    background: #1F2A3D;
    border: 1px solid #FF9900;
    border-radius: 18px;
    padding: 34px 46px;
    margin-bottom: 34px;
    box-shadow: 0 0 60px rgba(255,153,0,.18);
  }
  .az-label {
    color: #9AA7BC;
    font-size: 15px;
    letter-spacing: 2px;
    text-transform: uppercase;
    margin-bottom: 10px;
  }
  .az-value {
    font-size: clamp(36px, 7vw, 68px);
    font-weight: bold;
    color: #FF9900;
    font-family: 'Courier New', monospace;
  }
  .meta-grid {
    display: flex;
    gap: 16px;
    flex-wrap: wrap;
    justify-content: center;
    margin-bottom: 48px;
  }
  .meta {
    background: #1F2A3D;
    border: 1px solid #37465F;
    border-radius: 12px;
    padding: 16px 24px;
    min-width: 180px;
  }
  .meta .k {
    color: #9AA7BC;
    font-size: 12px;
    letter-spacing: 1.5px;
    text-transform: uppercase;
    margin-bottom: 6px;
  }
  .meta .v {
    color: #3EDC97;
    font-family: 'Courier New', monospace;
    font-size: 17px;
    font-weight: bold;
  }
  .cta {
    background: #1F2A3D;
    border: 1px solid #37465F;
    border-radius: 18px;
    padding: 30px 34px;
    max-width: 640px;
  }
  .cta h2 {
    font-size: clamp(19px, 3vw, 26px);
    margin-bottom: 10px;
  }
  .cta p {
    color: #9AA7BC;
    font-size: 15px;
    line-height: 1.6;
    margin-bottom: 22px;
  }
  .buttons {
    display: flex;
    gap: 14px;
    flex-wrap: wrap;
    justify-content: center;
  }
  .btn {
    display: inline-block;
    padding: 13px 26px;
    border-radius: 10px;
    font-size: 15px;
    font-weight: bold;
    text-decoration: none;
    transition: transform .15s ease;
  }
  .btn:hover { transform: translateY(-2px); }
  .btn.like { background: #FF9900; color: #161E2D; }
  .btn.sub  { background: #FF6B6B; color: #FFFFFF; }
  .btn.share{ background: transparent; color: #F3EFE7; border: 1px solid #37465F; }
  .footer {
    margin-top: 40px;
    color: #9AA7BC;
    font-size: 13px;
  }
  .footer b { color: #FF9900; }
</style>
</head>
<body>

  <div class="badge">It works! Built by user data</div>

  <h1>AWS Hands-On Training<br>with <span>Uche Ugochukwu</span></h1>
  <p class="tagline">This webpage configured itself the moment the server booted &mdash; no human hands involved.</p>

  <div class="az-card">
    <div class="az-label">This instance is located in Availability Zone</div>
    <div class="az-value">$AZ</div>
  </div>

  <div class="meta-grid">
    <div class="meta"><div class="k">Region</div><div class="v">$REGION</div></div>
    <div class="meta"><div class="k">Instance ID</div><div class="v">$INSTANCE_ID</div></div>
    <div class="meta"><div class="k">Instance Type</div><div class="v">$INSTANCE_TYPE</div></div>
  </div>

  <div class="cta">
    <h2>Did you just build this too? &#127881;</h2>
    <p>If this page is on your screen, you launched a real server in the AWS cloud and it configured itself from your script. That is a genuine cloud engineering skill &mdash; and it's only lesson one. Support the channel so more hands-on lessons like this keep coming.</p>
    <div class="buttons">
      <a class="btn like" href="https://www.youtube.com/@lightcloud9?sub_confirmation=1&feature=subscribe" target="_blank">&#128077; Like the Video</a>
      <a class="btn sub" href="https://www.youtube.com/@lightcloud9?sub_confirmation=1&feature=subscribe" target="_blank">&#128276; Subscribe</a>
      <a class="btn share" href="https://www.youtube.com/@lightcloud9?sub_confirmation=1&feature=subscribe" target="_blank">&#128228; Share with a Friend</a>
    </div>
  </div>

  <p class="footer">Learn AWS Cloud through <b>hands-on learning</b> &mdash; one project at a time.</p>

</body>
</html>
EOF
