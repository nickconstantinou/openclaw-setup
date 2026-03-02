---
name: outscraper
description: Scrape Google Maps for business data (tutors, restaurants, etc). Use for lead generation and data collection.
metadata:
  {
    "openclaw":
      {
        "emoji": "🗺️",
      },
  }
---

# Outscraper - Google Maps Data Collection

Scrape business data from Google Maps using Outscraper API.

## API Details

**Base URL:** `https://api.outscraper.cloud`

**Auth:** Header `X-API-KEY: YOUR_API_KEY`

## Quick Start

```bash
# Search for tutors in a city
curl -s "https://api.outscraper.cloud/google-maps-search?query=tutors, London, UK&limit=50" \
  -H "X-API-KEY: YOUR_API_KEY"
```

## Example Calls

```bash
# Basic search - up to 500 results
curl -s "https://api.outscraper.cloud/google-maps-search?query=tutors, London, UK&limit=500&region=GB" \
  -H "X-API-KEY: YOUR_API_KEY"

# With coordinates (more precise)
curl -s "https://api.outscraper.cloud/google-maps-search?query=tutors&coordinates=51.5074,-0.1278&limit=500&region=GB" \
  -H "X-API-KEY: YOUR_API_KEY"

# With email enrichment (async recommended)
curl -s "https://api.outscraper.cloud/google-maps-search?query=tutors, London, UK&limit=100&enrichment=contacts_n_leads&async=true" \
  -H "X-API-KEY: YOUR_API_KEY"

# Pagination - skip first 20
curl -s "https://api.outscraper.cloud/google-maps-search?query=tutors, London, UK&limit=500&skipPlaces=20" \
  -H "X-API-KEY: YOUR_API_KEY"
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `query` | string | required | Search query (e.g., "tutors, London, UK") |
| `limit` | int | 500 | Max results per query (max 500) |
| `skipPlaces` | int | 0 | Skip first N places (multiple of 20) - for pagination |
| `language` | string | en | Language code (en, de, es, fr...) |
| `region` | string | - | Country code for search (e.g., GB) |
| `dropDuplicates` | bool | false | Remove duplicates from multiple queries |
| `totalLimit` | int | - | Total limit when using dropDuplicates |
| `coordinates` | string | - | Location bias: "lat,lng" (e.g., "51.5074,-0.1278") |
| `enrichment` | array | - | Add extra data: contacts_n_leads, emails_validator_service, etc. |
| `fields` | string | - | Specific fields to return (comma-separated) |
| `async` | bool | true | Use async for large requests |
| `format` | string | - | Output: csv, json, xlsx, parquet |
| `webhook` | string | - | URL to POST results when complete |

**Coordinates format:** `latitude,longitude` (e.g., "51.5074,-0.1278" for London)

## Example Queries for UK Tutors

```bash
# By city (always include region=GB for UK)
tutors, London, UK&region=GB
tutors, Manchester, UK&region=GB
tutors, Birmingham, UK&region=GB

# By area (better for dense cities)
Maths tutors, Chelsea, London, UK&region=GB
Maths tutors, Kensington, London, UK&region=GB
GCSE tutors, Manchester city centre, UK&region=GB

# Split by London areas to get more than 500
Maths tutors, South London, UK&region=GB
Maths tutors, North London, UK&region=GB
Maths tutors, East London, UK&region=GB
Maths tutors, West London, UK&region=GB
```

## Response Format

Returns JSON with:
- `name` - Business name
- `phone` - Phone number
- `address` - Full address
- `website` - Website URL
- `rating` - Google rating
- `reviews` - Number of reviews
- `latitude`, `longitude` - Coordinates
- `place_id` - Google Maps ID

## Enrichments (Extra Data)

Add enrichments to get more data:

| Enrichment | What it adds |
|------------|--------------|
| `contacts_n_leads` | Emails, social links from website |
| `emails_validator_service` | Validate email deliverability |
| `company_websites_finder` | Find company website from name |
| `phones_enricher_service` | Phone carrier/validation data |
| `trustpilot_service` | Trustpilot reviews data |

**Note:** Enrichments cost extra and take longer. Use `async=true` for requests with enrichments.

## Workflow

1. API key stored in: `/home/openclaw/.openclaw/credentials/outscraper.json`
2. Run searches for target cities
3. Parse results → import to Supabase

## Example: Import to Supabase

After scraping, transform data:

```json
{
  "name": "Sarah's Maths Tutoring",
  "phone": "+44 7700 900123",
  "location": "London, SW1A",
  "subjects": ["Maths"],
  "levels": ["GCSE", "A-Level"],
  "price": 45,
  "rating": 4.8,
  "reviews": 47,
  "verified": false
}
```

## Pricing

- **Free tier:** First 500 businesses
- **Pay-as-you-go:** $3 per 1,000 records after free tier

## API Response Codes

| Code | Meaning | Action |
|------|---------|--------|
| 200 | Success | Results in response body |
| 202 | Async submitted | Use request ID to poll for results |
| 204 | No results | Check query parameters |
| 401 | Invalid API key | Check your API key |
| 402 | Payment issue | Check billing |
| 422 | Bad parameters | Validate query |

**Async Flow:**
1. Send request (returns 202 with request ID)
2. Poll `https://api.outscraper.com/requests/YOUR_REQUEST_ID` 
3. Results available for 4 hours

## Notes

- Always include location in query (e.g., "tutors, London, UK")
- Use region=GB for UK searches
- Use batching for multiple queries (up to 250 in one request)
- Check rate limits for your plan
- **API endpoint:** `https://api.outscraper.cloud` (not .com!)
- **Auth:** Use header `X-API-KEY: YOUR_KEY`
