# Wind Forecast Monitor

A full-stack web application for monitoring wind energy generation forecasts against actual generation in Great Britain, using data from the BMRS (Balancing Mechanism Reporting Service) API.

## Overview

This tool fetches wind generation actuals (FUELHH dataset) and forecasts (WINDFOR dataset) from the Elexon BMRS API, stores them locally, and provides an interactive chart to compare forecast accuracy at configurable horizons (0–48 hours ahead).

## Tech Stack

- **Frontend**: React 18, Vite, Recharts, Tailwind CSS
- **Backend**: Node.js (ESM), Express, better-sqlite3, node-cron
- **Analysis**: Python 3.11+, Jupyter, pandas, scikit-learn

## Project Structure

```
wind-forecast-monitor/
├── frontend/           # React app (port 5173 dev)
│   └── src/
│       ├── components/ # UI components (chart, date picker, slider)
│       ├── hooks/      # Custom React hooks (useWindData, etc.)
│       ├── services/   # API client functions
│       └── utils/      # Date/formatting helpers
├── backend/            # Express API (port 3000)
│   └── src/
│       ├── routes/     # API route handlers
│       ├── services/   # BMRS data fetching, forecast horizon logic
│       ├── models/     # Database queries
│       └── utils/      # Date utils, validators
├── analysis/
│   └── notebooks/      # Jupyter notebooks for error analysis
└── README.md
```

## Setup

### Prerequisites

- Node.js 18+
- Python 3.11+ (for analysis notebooks)
- Git

### Installation

```bash
# Backend
cd backend
cp .env.example .env
npm install
npm run dev

# Frontend (new terminal)
cd frontend
cp .env.example .env
npm install
npm run dev
```

Frontend runs at `http://localhost:5173`, backend at `http://localhost:3000`.

### Analysis Notebooks

```bash
cd analysis
pip install -r requirements.txt
jupyter notebook
```

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Health check |
| `GET /api/actual-generation` | Wind actuals by date range |
| `GET /api/forecast-generation` | Wind forecasts by date range + horizon |
| `GET /api/combined-data` | Actuals + matched forecasts |
| `GET /api/data-availability` | What data exists for a date range |

## Features

- Interactive date range selection (Jan 2025 onwards)
- Configurable forecast horizon slider (0–48 hours)
- Actual vs forecast comparison chart
- Mobile-responsive layout
- Background data sync every 6 hours

## Known Limitations

- Data available from Jan 1, 2025 only (BMRS WINDFOR dataset)
- Free tier deployment may have cold starts
- Only a few months of historical data available for reliability analysis

## Deployment

- Frontend: Vercel
- Backend: Render (or Railway)

## Author

[Your name]
