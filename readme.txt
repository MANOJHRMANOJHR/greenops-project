🔴 STEP 2: Faulty Version (for testing rollback)

Just change /health:

@app.route("/health")
def health():
    return jsonify({"status": "failed"}), 500

🔹 Line 3
set -e

VERY IMPORTANT.

Means:

👉 “If any command fails, stop the script immediately.”

This prevents broken deployments.


🔹 Line 7
CURRENT=$(docker exec nginx cat /etc/nginx/conf.d/default.conf | grep -o "app_blue\|app_green" | head -1)

This is VERY IMPORTANT.

It detects which container is currently serving users.

🧠 Break It Into Parts
🔹 docker exec nginx

Run command INSIDE nginx container.

🔹 cat /etc/nginx/conf.d/default.conf

Read current Nginx routing config.

Example:

proxy_pass http://app_blue:3000;

or

proxy_pass http://app_green:3000;
🔹 grep -o "app_blue\|app_green"

Extract only:

app_blue

or

app_green
🔹 head -1

Take first result.