# WEB-APP for Claude Code Activity Monitor

NextJS application for monitoring users installed the plugin

## Getting Started

### Install dependencies

```bash
yarn install
```

### Run app locally

```bash
yarn dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

### Supabase DB init

```bash
supabase login                                  # opens browser
supabase link --project-ref <YOUR_PROJECT_REF>  # ref from supabase.co/dashboard URL
supabase db push                                # applies pending migrations remotely
```
