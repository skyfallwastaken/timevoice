# Timevoice

![image of timevoice](https://cdn.mahadk.com/s/v3/cc79691a60f764e6_image.png)

_A time tracking and invoicing application built with Ruby on Rails, Inertia, Tailwind 4 and Svelte 5._

## Requirements

- Ruby 3.4+
- Node.js 20+
- PostgreSQL (production) or SQLite (development)

## Setup

1. Clone the repository
2. Run `bundle install`
3. Run `npm install`
4. Run `bin/rails db:setup`
5. Run `bin/dev` to start the development server

## Configuration

### Credentials

This application uses Rails encrypted credentials. Edit with:

```bash
EDITOR="code --wait" bin/rails credentials:edit
```

Required credentials structure:

```yaml
site_host: timevoice.mahadk.com # your domain here!

google:
  client_id: your_oauth_client_id
  client_secret: your_oauth_client_secret

# only affects production!
database:
  name: postgres
  username: postgres
  password: pass_here
  host: hostdomain.com
  port: 5432

smtp:
  address: mail-eu.smtp2go.com
  user_name: timevoice
  password: pass_here
  default_from: timevoice@mahadk.com

cloudflare:
  turnstile_site_key: your_turnstile_site_key
  turnstile_secret_key: your_turnstile_secret_key

secret_key_base: base_here
```

### Cloudflare Turnstile

We use Turnstile to protect API endpoints (especially ones that send out emails/notifications!)

1. Create a Turnstile widget at <https://dash.cloudflare.com>
2. Choose "Invisible" widget mode
3. Add your domain to the allowed hostnames
4. Copy the Site Key and Secret Key to your credentials

## Deployment

The application is configured for deployment with Kamal. See the Dockerfile and `.kamal` directory for configuration. You can also use the Dockerfile directly.

Remember to set `RAILS_ENV` to `production` and to set `SOLID_QUEUE_IN_PUMA` to `true` in your environment variables for production deployments!

---

<sub>disclosure: AI was used for scaffolding.</sub>
