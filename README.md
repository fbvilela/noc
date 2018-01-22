[![Build Status](https://travis-ci.org/fbvilela/noc.svg?branch=master)](https://travis-ci.org/fbvilela/noc)

# Newport Organic Collective

Sends an email with CSV files attached listing orders and a summary for a week. Designed to be used with Sendgrid and Heroku scheduler.

## Development setup

1. `bundle install`
1. `cp .env.example .env`
1. Create a new application in https://dev.tidyhq.com/oauth_applications, with Redirect uri being http://DOMAIN:PORT/callback.
1. Copy Client ID and Client Secret into [.env](https://github.com/fbvilela/noc/blob/master/.env.example).
1. Generate a [random string](https://stackoverflow.com/questions/88311/how-to-generate-a-random-string-in-ruby) and paste into `TOKEN` in [.env](https://github.com/fbvilela/noc/blob/master/.env.example).
1. `bundle exec rackup`
1. Go to http://DOMAIN:PORT/?token=TOKEN (token will be saved on your session, you can go to http://DOMAIN:PORT/logout to clear the session)
1. Click on "Auth" and authorize the application with TidyHQ.
1. Copy the access token shown next to the success message and paste into `TIDYHQ_ACCESS_CODE` in [.env](https://github.com/fbvilela/noc/blob/master/.env.example), then restart the application.
1. Verify you can now access orders at http://DOMAIN:PORT/orders.json.

## Usage

```
bundle exec rake email_orders[to_email,from_email,category_id,day_to_run]
```

- `to_email`: email to send orders to
- `from_email`: email that order sheets will be sent from
- `category_id`: category used to select orders
- `day_to_run`: rake task is skipped unless the day of the week matches this (used because heroku does not support a weekly schedulers)

```
bundle exec rake delete_expired[group_id]
```

- `group_id`: id of the group to remove expired members from
