ARG FLUTTER_IMAGE=ghcr.io/cirruslabs/flutter:stable
FROM ${FLUTTER_IMAGE} AS frontend-build
WORKDIR /src/frontend
COPY frontend/pubspec.yaml frontend/analysis_options.yaml ./
RUN flutter pub get
COPY frontend/ ./
RUN flutter build web --release

FROM python:3.12-slim AS runtime
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends libpq5 \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt /app/backend/requirements.txt
RUN pip install --no-cache-dir -r /app/backend/requirements.txt

COPY backend/ /app/backend/
COPY --from=frontend-build /src/frontend/build/web /app/frontend/build/web
COPY docker/entrypoint.sh /app/docker/entrypoint.sh

RUN chmod +x /app/docker/entrypoint.sh

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/api/health', timeout=3).read()"
CMD ["/app/docker/entrypoint.sh"]
