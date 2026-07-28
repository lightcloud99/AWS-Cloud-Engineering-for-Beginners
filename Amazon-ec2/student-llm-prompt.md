# Student Prompt — Build Your Own Self-Configuring EC2 Website

Copy the prompt below into any AI assistant of your choice (Claude, ChatGPT, Gemini, etc.).
Fill in the two blanks marked with [BRACKETS] before sending it.

---

## The Prompt

I am learning AWS through hands-on projects. Write me a complete EC2 user data
script (bash) for Amazon Linux that does the following:

1. Updates the system and installs the Apache web server (httpd).
2. Starts Apache and enables it to start automatically on every boot.
3. Uses IMDSv2 (the token-based instance metadata service — NOT the old IMDSv1
   style) to fetch this instance's:
   - Availability Zone
   - Region
   - Instance ID
   - Instance type
4. Writes a single self-contained index.html to /var/www/html/ that:
   - Has a dark, modern design with ONE accent color of my choice: [YOUR COLOR]
   - Shows a large heading with my name: [YOUR NAME]
   - Displays the Availability Zone as the biggest element on the page
   - Shows the region, instance ID, and instance type in smaller info cards
   - Includes a short message encouraging visitors to like, subscribe, and
     share the YouTube channel where I learned this
   - Uses only inline CSS (no external files, fonts, or JavaScript) so the
     page works with no internet dependencies

Important constraints:
- The whole thing must be ONE bash script I can paste into the EC2 launch
  wizard's user data box.
- Use a heredoc (cat > file <<EOF) to write the HTML, and make sure the shell
  variables for the metadata values are interpolated into the page.
- Do not use any dollar signs inside the CSS or HTML except for the metadata
  variables, since an unquoted heredoc would try to expand them.
- Start the script with #!/bin/bash on the very first line.
- Add short comments explaining what each section does, in beginner-friendly
  language.

After the script, briefly explain:
- What IMDSv2 is and why the token step exists.
- Which security group rule I need for the page to be reachable (port and source).
- Why I must visit the site with http:// and not https://.

---

## After the AI responds — verify before you launch

A good engineer checks AI output. Confirm all of these before pasting into AWS:

- [ ] The first line is exactly `#!/bin/bash`
- [ ] It installs and enables `httpd`
- [ ] The metadata calls include the token header (`X-aws-ec2-metadata-token`)
- [ ] The HTML is written to `/var/www/html/index.html`
- [ ] Your name and color made it into the page

Then launch a t3.micro with the script in Advanced details → User data, open
port 80 (HTTP, Anywhere) in the security group, and visit http://YOUR-PUBLIC-IP.

**Challenge:** ask the AI to add the instance's public IP to the page, or to
change the design completely — that's how you learn what each part does.
