FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    postgresql-client \
    libpq-dev \
    gcc && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip install --no-cache-dir \
    speedtest-cli==2.1.3 \
    psycopg2-binary==2.9.9 \
    schedule==1.2.0

# Create app directory
WORKDIR /app

# Copy application code
COPY speedtest_monitor.py .

# Run the application
CMD ["python", "-u", "speedtest_monitor.py"]
