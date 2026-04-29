# Environment Variables

| Name | Purpose |
| --- | --- |
| `APP_ENV` | Runtime environment label. |
| `APP_SECRET_KEY` | Secret used for signing application tokens. |
| `APP_USERNAME` | Single household login username. |
| `APP_PASSWORD` | Single household login password. |
| `JWT_EXPIRE_MINUTES` | Access token lifetime. |
| `DATABASE_URL` | SQLAlchemy Postgres URL. |
| `DATABASE_SCHEMA` | Dedicated Postgres schema for Plant Buddy tables. |
| `OPENAI_API_KEY` | OpenAI API key for plant analysis and chat. |
| `PLANTBUDDY_STORAGE_PATH` | Mounted filesystem path for plant photos. |
| `CORS_ALLOWED_ORIGINS` | Comma-separated trusted browser origins. |
| `PUBLIC_BASE_URL` | Public app URL, for generated links and calendar export. |
