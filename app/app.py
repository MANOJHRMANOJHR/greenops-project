from flask import Flask, jsonify, render_template
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST
import os

app = Flask(__name__)

REQUESTS = Counter('requests_total', 'Total Requests')


FAIL_FILE = "/tmp/force_unhealthy"

@app.route("/")
def home():
    REQUESTS.inc()
    return render_template("index.html")

@app.route("/health")
def health():
    if os.path.exists(FAIL_FILE):
        return jsonify({"status": "failed"}), 500
    return jsonify({"status": "healthy"}), 200

@app.route("/simulate-failure", methods=["POST"])
def simulate_failure():
    with open(FAIL_FILE, "w") as f:
        f.write("fail")
    return jsonify({"message": "Runtime failure simulated"}), 200

@app.route("/metrics")
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=3000)